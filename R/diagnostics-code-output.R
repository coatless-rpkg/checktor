# Code check for console output that cannot be suppressed.

#' Diagnose Print/Cat Usage in Functions
#'
#' Flags `print()` / `cat()` calls not guarded by an enclosing `if()`,
#' `for()`, or `while()`. The check uses the ancestor axis, so guard
#' detection is robust regardless of formatting. Calls inside S3 `print.*`
#' and `format.*` methods are exempt, since `cat()` is the required idiom
#' there (base R's own `print.default()` / `print.lm()` use it).
#'
#' @inheritParams lab_tf_usage
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Using print()/cat()](https://contributor.r-project.org/cran-cookbook/code_issues.html#using-printcat).
#' Diagnostic output belongs in `message()` or `warning()`, which a user can
#' suppress, rather than in `cat()` or `print()`, which they cannot. Neither the
#' Repository Policy nor Writing R Extensions states this, but reviewers ask for it
#' consistently. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/print_cat_bad.R",
#'                                  show_content = FALSE)
#' lab_print_cat_usage(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_print_cat_usage <- function(path = ".", verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("print_cat_usage")))
  }

  # An S3 print method may delegate its output to a helper. The helper is not
  # itself a method, so the XPath cannot see that its output is only ever
  # reachable through one. Drop hits inside a function whose only callers are S3
  # output methods -- behaviourally identical to inlining the helper into them.
  # Exempt by NAME: an S3 print/format/summary method, an S4 method registered by
  # name (`setMethod("show", "Foo", show_foo)`, which DBI does throughout), and any
  # helper whose output is only ever reachable through one of those.
  exempt_fns <- c(output_method_names(parsed), s3_output_delegates(parsed))
  issues <- xpath_filter(parsed, print_cat_xpath(), function(n) {
    if (enclosing_function_name(n) %in% exempt_fns) {
      return(FALSE)
    }
    # `print(doc, output_file)` writes a file; it is not console output.
    if (identical(xml2::xml_text(n), "print") && is_file_writing_print(n)) {
      return(FALSE)
    }
    # A function whose purpose is to print a report is exempt (WRE's own
    # carve-out). Printing only becomes a leak when the caller wanted a value
    # and got noise as well, or when a lone cat() is a leftover notice.
    !is_console_reporter(n)
  })

  report_check(
    issues,
    verbose,
    check_label("print_cat_usage"),
    "No unsuppressable {.code print()}/{.code cat()} usage found",
    "Potential unsuppressable {.code print()}/{.code cat()} usage",
    paste("Treatment:", treatments$print_cat_usage$treatment)
  )
}

# Names packages actually use for an output-control flag. `show` and `echo` are
# here because checktor's own example_diagnose_scenario() gates its cat() behind
# `if (show_content)`, and any package with show_*/echo/trace flags would
# otherwise be flagged for correctly guarding its output.
#
# This list is a closed whitelist, which is not a sound test for "is this an
# output-control flag", and it showed: geoR gates every one of its messages on
# `messages.screen`, and the list had no "message" stem, so all 117 of its
# correctly-guarded cat() calls were reported. "message" is the single most
# common output-flag name in base-R-era code, and omitting it was indefensible.
#
# The remaining exposure is a package whose flag is named something we have not
# thought of. That direction fails toward a false POSITIVE, which is the failure
# we are trying to eliminate, so err wide.
OUTPUT_FLAG_WORDS <- c(
  "verbose",
  "quiet",
  "silent",
  "debug",
  "trace",
  "message",
  "msg",
  "print",
  "report",
  "note",
  "info",
  "show",
  "echo",
  "progress",
  "log",
  "warn",
  "output"
)

# The print()/cat() calls lab_print_cat_usage() reports before its name-based
# exemptions: every one that no guard below excuses.
print_cat_xpath <- function() {
  # Only a VERBOSITY gate is a guard. The previous rule was
  # `not(ancestor::expr[IF or FOR or WHILE])`, which exempted a call under *any*
  # enclosing control flow, so `if (x > 0) print("debug")` and
  # `for (i in xs) print(i)` were silently let through. Those are exactly the
  # unsuppressable output we are looking for.
  lower <- "translate(text(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')"
  verbosity <- paste(
    sprintf("contains(%s, '%s')", lower, OUTPUT_FLAG_WORDS),
    collapse = " or "
  )
  # The condition of an `if` is its first child <expr>; the body follows it.
  guarded <- sprintf("ancestor::expr[IF][expr[1][.//SYMBOL[%s]]]", verbosity)

  # `if (interactive())` is a guard too, and a citable one: CRAN's rule ends with
  # the literal parenthetical "(except for print, summary, interactive
  # functions)". Output only an interactive user ever sees is not unsuppressable
  # output in a batch run, because it never happens in one.
  interactive_guard <- paste0(
    "ancestor::expr[IF][expr[1]",
    "[.//SYMBOL_FUNCTION_CALL[text() = 'interactive']]]"
  )

  # cat()/print() are the required idiom inside S3 output methods. base R's own
  # print.default/print.lm/format.* use cat(), and the CRAN policy sentence that
  # states the rule ends with the literal parenthetical
  # "(except for print, summary, interactive functions)" -- so summary.* counts too.
  # R's classic idiom defines a method with a QUOTED name:
  #
  #     "print.summary.xvalid" <- function(x, ...) { ... }
  #
  # The left-hand side then parses as STR_CONST, not SYMBOL, so a SYMBOL-only
  # match never fires. geoR writes 201 of its 208 top-level functions this way,
  # which left every one of its print/summary methods without S3 protection.
  s3_prefixes <- paste0(OUTPUT_METHOD_PREFIXES, ".")
  s3_method <- sprintf(
    "ancestor::expr[FUNCTION][parent::*/expr[1][SYMBOL[%s] or STR_CONST[%s]]]",
    paste(sprintf("starts-with(text(), '%s')", s3_prefixes), collapse = " or "),
    xp_str_starts(s3_prefixes)
  )

  # S4's `show` IS S3's `print`: it is the method R invokes to display an object
  # at the prompt, and cat() is the required idiom inside one exactly as it is
  # inside print.default(). The S3 rule above keys off a NAME PREFIX on a
  # top-level assignment, so it is completely blind to
  # `setMethod("show", "Foo", function(object) cat(...))`, where the method is an
  # anonymous function handed to a call. distrMod alone was reported 118 times for
  # its show methods, and geoR and DBI likewise.
  s4_method <- s4_output_method_xpath(axis = "ancestor::")

  # A function that PROMPTS the user is an interactive function by definition, so
  # the text it prints to set up the prompt is part of the prompt. A setup routine
  # that cat()s a file tree and then asks "Overwrite all existing files?" is
  # prompting, and flagging that is flagging the question.
  prompts_user <- sprintf(
    "ancestor::expr[FUNCTION][1]//SYMBOL_FUNCTION_CALL[%s]",
    xp_text_in(c(PROMPT_CALLS, "locator", "identify"))
  )

  # `app$cat(...)` is not base::cat.
  xp_call(
    c("print", "cat"),
    sprintf(
      "not(%s)",
      c(guarded, interactive_guard, s3_method, s4_method, prompts_user)
    )
  )
}

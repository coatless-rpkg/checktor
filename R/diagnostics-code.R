#' Diagnose Code Health Issues
#'
#' Runs comprehensive diagnostics on R source code to identify common CRAN
#' submission issues and coding best-practice violations.
#'
#' @param path Character. Path to the R package directory. Default: `"."`.
#' @param verbose Logical. Whether to print detailed diagnostic output.
#'   Default: `TRUE`.
#'
#' @return
#' List of named [checktor_check_result()] objects (e.g., `tf_usage`,
#' `seed_setting`) plus a `passed` named logical vector summarizing pass/fail
#' for each sub-check.
#'
#' @details
#' Each source file is parsed once with `parse(keep.source = TRUE)`; checks
#' run XPath queries against the parsed XML representation, so identifiers
#' that appear only inside string literals or comments do not false-positive.
#' Multi-line constructs (`set.seed(\n123\n)`), formula `~` versus path `~`,
#' and scope-aware patterns (an `options()` call guarded by a sibling
#' `on.exit()` in the same function body) are all handled correctly.
#'
#' @seealso [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' code_results <- diagnose_code_issues(pkg, verbose = FALSE)
#' summary(code_results)   # per-category overview
#' issues(code_results)    # the issues found
diagnose_code_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("Code Health Check")
  }

  if (!dir.exists(file.path(path, "R"))) {
    if (verbose) {
      cli::cli_alert_info("No R/ directory found")
    }
    out <- list(passed = TRUE, message = "No R directory found")
    class(out) <- "checktor_category_result"
    return(out)
  }

  # Parse all R files once and pass the cache to each public diagnostic via
  # its hidden `parsed` argument. The closures below reference the public
  # function names symbolically, so resolution happens at call time and
  # `with_mocked_bindings` can replace any of them in tests.
  parsed <- read_r_xml(path)

  run_checks(
    c(
      list(
        tf_usage = function(p, v) diagnose_tf_usage(p, v, parsed = parsed),
        seed_setting = function(p, v) {
          diagnose_seed_setting(p, v, parsed = parsed)
        },
        print_cat_usage = function(p, v) {
          diagnose_print_cat_usage(p, v, parsed = parsed)
        },
        option_changes = function(p, v) {
          diagnose_option_changes(p, v, parsed = parsed)
        },
        home_writing = function(p, v) {
          diagnose_home_writing(p, v, parsed = parsed)
        },
        temp_cleanup = function(p, v) {
          diagnose_temp_cleanup(p, v, parsed = parsed)
        },
        globalenv_mod = function(p, v) {
          diagnose_globalenv_modification(p, v, parsed = parsed)
        },
        installed_packages = function(p, v) {
          diagnose_installed_packages_usage(p, v, parsed = parsed)
        },
        warn_option = function(p, v) {
          diagnose_warn_option(p, v, parsed = parsed)
        },
        software_install = function(p, v) {
          diagnose_software_installation(p, v, parsed = parsed)
        },
        core_usage = function(p, v) diagnose_core_usage(p, v, parsed = parsed),
        library_in_pkg = function(p, v) {
          diagnose_library_in_pkg_code(p, v, parsed = parsed)
        },
        detect_cores_robustness = function(p, v) {
          diagnose_detect_cores_robustness(p, v, parsed = parsed)
        },
        sys_setenv = function(p, v) {
          diagnose_sys_setenv_no_reset(p, v, parsed = parsed)
        },
        hardcoded_credentials = function(p, v) {
          diagnose_hardcoded_credentials(p, v, parsed = parsed)
        }
      ),
      registered_checks_for("code", parsed = parsed)
    ),
    path,
    verbose
  )
}

# Verbose output helper shared across diagnostic functions.
emit_issue_summary <- function(
  issues,
  verbose,
  success_msg,
  failure_msg,
  treatment = NULL,
  max_show = 5L,
  level = c("danger", "warning")
) {
  if (!verbose) {
    return(invisible())
  }
  level <- match.arg(level)
  if (length(issues) == 0L) {
    cli::cli_alert_success(success_msg)
    return(invisible())
  }
  if (level == "danger") {
    cli::cli_alert_danger(failure_msg)
  } else {
    cli::cli_alert_warning(failure_msg)
  }
  cli::cli_ul(utils::head(issues, max_show))
  if (length(issues) > max_show) {
    cli::cli_text("{.emph ... and {length(issues) - max_show} more}")
  }
  if (!is.null(treatment)) cli::cli_text("{.emph {treatment}}")
}

# In the xmlparsedata XML, a call `fn(a, b)` is:
#   <expr>                                <- call expr ("outer" expr)
#     <expr>                              <- function-name expr
#       <SYMBOL_FUNCTION_CALL>fn</...>
#     </expr>
#     <OP-LEFT-PAREN>(
#     <expr><SYMBOL>a</SYMBOL></expr>     <- first positional arg
#     <OP-COMMA>,
#     <expr><SYMBOL>b</SYMBOL></expr>
#     <OP-RIGHT-PAREN>)
#   </expr>
# Named args `f(a = 1)` use SYMBOL_SUB/EQ_SUB/expr triples (children of the
# call expr, not wrapped in another expr).
# Helper: from a SYMBOL_FUNCTION_CALL position, navigate to:
#   - the call expr:           `parent::expr/parent::expr`
#   - first positional arg:    `parent::expr/following-sibling::expr[1]`
#   - any named-arg name:      `parent::expr/parent::expr/SYMBOL_SUB`

#' Diagnose `T`/`F` Usage in R Code
#'
#' Flags bare `T` / `F` symbols that should be `TRUE` / `FALSE`. Operates on
#' the parsed AST, so `T` inside string literals or comments is not flagged
#' (a long-standing source of regex false positives). Named-argument names
#' (`f(T = 1)`) and `$T` / `@T` extractions are excluded.
#'
#' @param path Character. Path to package directory.
#' @section Source:
#' No binding rule forbids `T` and `F`, though the CRAN Cookbook keeps a recipe for
#' it under
#' [T/F Instead of TRUE/FALSE](https://contributor.r-project.org/cran-cookbook/code_issues.html#tf-instead-of-truefalse).
#' They are ordinary variables (see `?logical`) that R sets to `TRUE` and `FALSE` at
#' startup but that any code can rebind, so a function reading `T` after something
#' has run `T <- 0` gets the wrong answer. A real risk that no rule makes citable is
#' why this sits at `robustness` tier rather than policy. See `vignette("check-sources", package = "checktor")` for how every
#' check maps to its source.
#'
#' @param verbose Logical. Print diagnostic messages.
#' @param parsed Internal. Pre-parsed source cache; if `NULL`, files are read
#'   from `path` on demand.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' # show_content defaults to TRUE, so the offending file prints first
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R")
#' issues(diagnose_tf_usage(pkg, verbose = FALSE))
diagnose_tf_usage <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "T/F usage check"))
  }

  # `T` and `F` in a NON-EVALUATED language context are language tokens, not
  # logicals. EL builds plotmath labels with
  # `substitute(expression(F[a] - F[b]), ...)`, where F is the cumulative
  # distribution function and has nothing to do with FALSE. quote(), bquote(),
  # expression() and substitute() all construct language rather than evaluate it.
  quoting <- paste(
    sprintf(
      "text() = '%s'",
      c("quote", "bquote", "expression", "substitute", "Quote")
    ),
    collapse = " or "
  )
  # There is NO guard here for `f(T = 1)`, and there must not be. An argument NAME
  # parses as SYMBOL_SUB, not SYMBOL, so `//SYMBOL` never matches it in the first
  # place. The guard that used to sit here, excluding a SYMBOL whose parent expr
  # follows an EQ_SUB, therefore protected nothing and suppressed the argument
  # VALUE instead: `mean(x, na.rm = T)`, which is the single most common bare `T`
  # in R, was silently unreportable.
  xpath <- sprintf(
    paste0(
      "//SYMBOL[(text() = 'T' or text() = 'F')",
      "  and not(parent::expr[OP-DOLLAR or OP-AT])",
      "  and not(ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[%s]])",
      "]"
    ),
    quoting
  )
  issues <- c(xpath_lints(parsed, xpath), parse_error_issues(parsed))

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No {.code T}/{.code F} usage found",
    "Found {.code T}/{.code F} usage (should use {.code TRUE}/{.code FALSE})"
  )
  checktor_check_result(passed, issues, "T/F usage check")
}

#' Diagnose Hardcoded Seed Setting
#'
#' Flags `set.seed(<numeric>)` calls. Multi-line forms are handled because
#' the check matches the call AST node, not raw text.
#'
#' @inheritParams diagnose_tf_usage
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' asks a package not to modify the user's workspace, and `set.seed()` writes
#' `.Random.seed` there, changing the random-number stream for the rest of the
#' session. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/seed_setting_bad.R",
#'                                  show_content = FALSE)
#' diagnose_seed_setting(pkg, verbose = FALSE)   # prints PASSED/FAILED
diagnose_seed_setting <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Seed setting check"))
  }

  # set.seed() call whose first positional arg expression contains a numeric
  # literal (covers `set.seed(123)` and `set.seed(\n  123\n)`).
  # `set.seed(123)` inside `if (FALSE)` can never execute, so it can never mutate
  # the user's RNG state, which is the entire harm this check polices.
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'set.seed']",
    "[not(ancestor::expr[IF][expr[1][count(*) = 1][NUM_CONST[text() = 'FALSE'] or SYMBOL[text() = 'FALSE']]])]",
    "/parent::expr/following-sibling::expr[1]//NUM_CONST"
  )
  issues <- xpath_lints(parsed, xpath)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No hardcoded seed setting found",
    "Found hardcoded seed setting",
    "Treatment: Add a seed parameter to allow user control"
  )
  checktor_check_result(passed, issues, "Seed setting check")
}

#' Diagnose Print/Cat Usage in Functions
#'
#' Flags `print()` / `cat()` calls not guarded by an enclosing `if()`,
#' `for()`, or `while()`. The check uses the ancestor axis, so guard
#' detection is robust regardless of formatting. Calls inside S3 `print.*`
#' and `format.*` methods are exempt, since `cat()` is the required idiom
#' there (base R's own `print.default()` / `print.lm()` use it).
#'
#' @inheritParams diagnose_tf_usage
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Using print()/cat()](https://contributor.r-project.org/cran-cookbook/code_issues.html#using-printcat).
#' Diagnostic output belongs in `message()` or `warning()`, which a user can
#' suppress, rather than in `cat()` or `print()`, which they cannot. Neither the
#' Repository Policy nor Writing R Extensions states this, but reviewers ask for it
#' consistently. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' pkg <- example_diagnose_scenario("code_examples/print_cat_bad.R",
#'                                  show_content = FALSE)
#' diagnose_print_cat_usage(pkg, verbose = FALSE)
diagnose_print_cat_usage <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Print/cat usage check"))
  }

  # Only a VERBOSITY gate is a guard. The previous rule was
  # `not(ancestor::expr[IF or FOR or WHILE])`, which exempted a call under *any*
  # enclosing control flow, so `if (x > 0) print("debug")` and
  # `for (i in xs) print(i)` were silently let through. Those are exactly the
  # unsuppressable output we are looking for.
  # Names packages actually use for an output-control flag. `show` and `echo` are
  # here because checktor's own example_diagnose_scenario() gates its cat() behind
  # `if (show_content)`, and any package with show_*/echo/trace flags would
  # otherwise be flagged for correctly guarding its output.
  # Names packages actually use for an output-control flag.
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
  verbosity_words <- c(
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
  lower <- "translate(text(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')"
  verbosity <- paste(
    sprintf("contains(%s, '%s')", lower, verbosity_words),
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
  # The STR_CONST text carries its quotes, hence the leading quote in the prefix.
  s3_prefixes <- c("print.", "format.", "summary.")
  s3_method <- sprintf(
    "ancestor::expr[FUNCTION][parent::*/expr[1][SYMBOL[%s] or STR_CONST[%s]]]",
    paste(sprintf("starts-with(text(), '%s')", s3_prefixes), collapse = " or "),
    paste(
      c(
        sprintf("starts-with(text(), '\"%s')", s3_prefixes),
        sprintf("starts-with(text(), \"'%s\")", s3_prefixes)
      ),
      collapse = " or "
    )
  )

  # S4's `show` IS S3's `print`: it is the method R invokes to display an object
  # at the prompt, and cat() is the required idiom inside one exactly as it is
  # inside print.default(). The S3 rule above keys off a NAME PREFIX on a
  # top-level assignment, so it is completely blind to
  # `setMethod("show", "Foo", function(object) cat(...))`, where the method is an
  # anonymous function handed to a call. distrMod alone was reported 118 times for
  # its show methods, and geoR and DBI likewise.
  s4_method <- sprintf(
    "ancestor::expr[FUNCTION][parent::expr[expr[1]/SYMBOL_FUNCTION_CALL[%s]][expr[2][STR_CONST[%s] or SYMBOL[%s]]]]",
    "text() = 'setMethod' or text() = 'setReplaceMethod'",
    paste(
      sprintf(
        "text() = '\"%s\"' or text() = \"'%s'\"",
        S4_OUTPUT_GENERICS,
        S4_OUTPUT_GENERICS
      ),
      collapse = " or "
    ),
    paste(sprintf("text() = '%s'", S4_OUTPUT_GENERICS), collapse = " or ")
  )

  # A function that PROMPTS the user is an interactive function by definition, so
  # the text it prints to set up the prompt is part of the prompt. A setup routine
  # that cat()s a file tree and then asks "Overwrite all existing files?" is
  # prompting, and flagging that is flagging the question.
  prompts_user <- paste0(
    "ancestor::expr[FUNCTION][1]//SYMBOL_FUNCTION_CALL[",
    "  text() = 'readline' or text() = 'menu' or text() = 'askYesNo'",
    "  or text() = 'yesno' or text() = 'select.list'",
    "  or text() = 'locator' or text() = 'identify'",
    "]"
  )

  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'print' or text() = 'cat'][",
    "  ",
    NOT_MEMBER_ACCESS, # `app$cat(...)` is not base::cat
    "  and not(",
    guarded,
    ")",
    "  and not(",
    interactive_guard,
    ")",
    "  and not(",
    s3_method,
    ")",
    "  and not(",
    s4_method,
    ")",
    "  and not(",
    prompts_user,
    ")",
    "]"
  )

  # An S3 print method may delegate its output to a helper. The helper is not
  # itself a method, so the XPath above cannot see that its output is only ever
  # reachable through one. Drop hits inside a function whose only callers are S3
  # output methods -- behaviourally identical to inlining the helper into them.
  # Exempt by NAME: an S3 print/format/summary method, an S4 method registered by
  # name (`setMethod("show", "Foo", show_foo)`, which DBI does throughout), and any
  # helper whose output is only ever reachable through one of those.
  exempt_fns <- c(output_method_names(parsed), s3_output_delegates(parsed))
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    keep <- vapply(
      nodes,
      function(n) {
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
      },
      logical(1)
    )
    nodes <- nodes[keep]
    if (length(nodes) == 0L) {
      return(character(0))
    }
    paste0(basename(file), ":", xml2::xml_attr(nodes, "line1"))
  })

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No unsuppressable {.code print()}/{.code cat()} usage found",
    "Potential unsuppressable {.code print()}/{.code cat()} usage",
    "Treatment: Use {.code message()} or {.code if(verbose)} conditions"
  )
  checktor_check_result(passed, issues, "Print/cat usage check")
}

#' Diagnose Unrestored Option Changes
#'
#' Flags a call to `options()`, `par()` or `setwd()` that changes the user's
#' session state without restoring it.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Change of Options, Graphical Parameters and Working Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory),
#' which asks that a function restore any `options()`, `par()` graphics parameters,
#' or working directory it changes, using `on.exit()`. No clause in the Repository
#' Policy or Writing R Extensions states it, yet it is among the most common reasons
#' a package is sent back, because a function that quietly runs `options(digits = 3)`
#' and returns has changed how the rest of the session behaves. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#'
#' @section Exemptions:
#' Two shapes leak nothing and are exempt. A setter that captures the old value and
#' hands it back, as in `old <- options(...); invisible(old)`, honours the base R
#' contract and lets the caller restore. And an option in the package's own
#' namespace, written `options(<PackageName>.key = ...)`, is the package managing
#' its own configuration rather than the user's, so a deliberate session preference
#' like `options(mypkg.threshold = 5)` is fine. If you keep a user setting for the
#' session, give it a namespaced name rather than a bare global one, and restore a
#' genuinely temporary change with `on.exit(options(old))`.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_option_changes(pkg, verbose = FALSE)$passed
diagnose_option_changes <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Option changes check"))
  }

  # options/par/setwd call whose innermost enclosing function body does NOT
  # contain an on.exit() or any withr::local_*/with_* helper.
  #
  # There is a second legitimate shape. options(), par() and setwd() all return
  # their previous value, so a setter that captures it and hands it back is
  # honouring the base R contract and leaves the caller able to restore:
  #
  #     configure <- function(x) { old <- options(digits = x); invisible(old) }
  #
  # The real leak is a bare `options(digits = 3)` whose old value is discarded,
  # so a call that sits on the right-hand side of an assignment is exempt.
  captured <- paste0(
    "not(parent::expr/parent::expr/preceding-sibling::*[1]",
    "[self::LEFT_ASSIGN or self::EQ_ASSIGN])"
  )

  # And the check must first establish that the call CHANGES anything at all.
  # options() and par() both read AND write, and the old rule could not tell the
  # difference:
  #
  #   par("usr")[3]            <- a READ. zoo does this to get plot coordinates.
  #   options("digits")        <- a READ.
  #   options(old)             <- a RESTORE, the documented counterpart to
  #                               `old <- options(...)`. withr's reset_options()
  #                               is literally `function(old) options(old)`, and
  #                               checktor reported withr's own CLEANUP function
  #                               as an unrestored change.
  #   options(digits = 3)      <- a WRITE. This is the violation.
  #
  # A NAMED argument is what makes it a write. An unnamed one is a read or a
  # restore, and neither is something we can call a leak. setwd() is exempt from
  # this rule: it takes a bare path and always writes.
  # A package setting an option in ITS OWN namespace is managing its own state, not
  # the user's. CRAN's concern is a package disturbing options that other code
  # depends on. data.table toggles `datatable.verbose`, cli sets `cli.*`, knitr sets
  # `knitr.*`; none of that touches anyone else.
  # data.table names its option `datatable.verbose`, with the dot dropped from the
  # package name, so both spellings have to count as "its own".
  own <- own_option_prefix(path)
  own_option <- if (nzchar(own)) {
    prefixes <- unique(c(own, gsub(".", "", own, fixed = TRUE)))
    sprintf(
      " and not(parent::expr/parent::expr/SYMBOL_SUB[%s])",
      paste(sprintf("starts-with(text(), '%s.')", prefixes), collapse = " or ")
    )
  } else {
    ""
  }
  sets_something <- paste0(
    "(text() = 'setwd'",
    " or parent::expr/parent::expr/SYMBOL_SUB)",
    own_option
  )
  # A setwd()/options()/par() inside a function handed to a SUBPROCESS runner runs
  # in a child R process and cannot touch the user's session: the child exits and
  # takes its working directory and options with it. aisdk's `callr::r(function()
  # { setwd(wd); ... })` is the canonical shape.
  in_subprocess <- paste0(
    "not(ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[",
    "  text() = 'r' or text() = 'r_bg' or text() = 'r_session'",
    "  or text() = 'rcmd' or text() = 'callr'",
    "]])"
  )
  # A function factored out as an on.exit() restore handler -- registered by the
  # caller as `on.exit(restore_par(op))` -- is doing the restoring, so its own
  # par()/options() writes are the restore, not a leak. Its body holds no on.exit,
  # which is why the guard above cannot see it. paintr's restore_par() is exactly
  # this shape.
  not_restore_handler <- not_on_exit_handler_xpath(on_exit_handler_names(
    parsed
  ))
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'options' or text() = 'par' or text() = 'setwd'][",
    "  ",
    sets_something,
    "  and ",
    not_under_fn_with_call_xpath(c(
      "on.exit",
      "local_options",
      "with_options",
      "local_par",
      "with_par",
      "local_dir",
      "with_dir"
    )),
    "  and ",
    in_subprocess,
    "  and ",
    not_restore_handler,
    "  and ",
    captured,
    "]"
  )
  issues <- xpath_lints(parsed, xpath)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Option changes appear to be properly reset",
    "Option changes without apparent reset",
    paste0(
      "Treatment: For a setting you keep for the session, namespace it as ",
      "{.code options(<PackageName>.key = ...)}. For a temporary change, restore ",
      "it on exit, e.g. ",
      "{.code oldpar <- par(no.readonly = TRUE); on.exit(par(oldpar))}."
    )
  )
  checktor_check_result(passed, issues, "Option changes check")
}

#' Diagnose Writes to the User's Home Directory
#'
#' Flags a write whose destination resolves to `~` or `$HOME`.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' states that "Packages should not write in the user's home filespace ... nor
#' anywhere else on the file system apart from the R session's temporary
#' directory". See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_home_writing(pkg, verbose = FALSE)$passed
diagnose_home_writing <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Home writing check"))
  }

  # The CRAN rule is about WRITING into the user's filespace. Earlier versions of
  # this check inspected only path.expand()/normalizePath()/file.path()/Sys.getenv(),
  # which are all *reads*: it flagged `Sys.getenv("HOME")` (which writes nothing)
  # while missing `writeLines(x, "~/leaked.txt")`, the actual violation. So flag a
  # WRITE whose destination resolves to the user's home.
  write_funs <- c(
    "write.csv",
    "write.csv2",
    "write.table",
    "writeLines",
    "saveRDS",
    "save",
    "file.create",
    "dir.create",
    "file.copy",
    "file.rename",
    "sink",
    "png",
    "pdf",
    "jpeg",
    "ggsave"
  )
  write_pred <- paste(sprintf("text() = '%s'", write_funs), collapse = " or ")

  # An argument resolves to the user's home if it contains a `~`-rooted literal
  # anywhere, or reads HOME / USERPROFILE from the environment. STR_CONST text
  # retains its quotes, hence the "~ / '~ alternation.
  home_pred <- paste0(
    ".//STR_CONST[starts-with(text(), '\"~') or starts-with(text(), \"'~\")]",
    " or .//SYMBOL_FUNCTION_CALL[text() = 'Sys.getenv']/parent::expr",
    "/following-sibling::expr[1]/STR_CONST[",
    "  starts-with(text(), '\"HOME') or starts-with(text(), \"'HOME\")",
    "  or starts-with(text(), '\"USERPROFILE') or starts-with(text(), \"'USERPROFILE\")",
    "]"
  )

  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[%s][parent::expr/parent::expr[%s]]",
    write_pred,
    home_pred
  )
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    paste0(
      basename(file),
      ":",
      xml2::xml_attr(nodes, "line1"),
      " (",
      xml2::xml_text(nodes),
      "() writes under the home directory)"
    )
  })

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No home directory writing detected",
    "Writes into the user's home directory",
    "Treatment: Write to tempdir(), or to a path the caller supplies"
  )
  checktor_check_result(passed, issues, "Home writing check")
}

# Per-tempfile cleanup detection. Only scans `tests/` since R/ helpers may
# legitimately hand temp paths back to callers. A tempfile()/tempdir() call
# is "clean" if cleanup exists either (a) in the innermost enclosing function
# body, OR (b) later in the same top-level scope (handles test scripts).
#' Diagnose Missing Temp-File Cleanup
#'
#' Flags a temporary file created without a matching cleanup.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Leaving Files in the Temporary Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#leaving-files-in-the-temporary-directory).
#' `tempdir()` is removed at session end, so an un-`unlink()`ed tempfile breaks no
#' rule, and tidiness rather than policy is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_temp_cleanup(pkg, verbose = FALSE)$passed
diagnose_temp_cleanup <- function(path, verbose = TRUE, parsed = NULL) {
  # Scope: package code under R/, NOT tests/.
  #
  # This used to scan tests/, which is not shipped behaviour and never runs on a
  # user's machine. That is why it reported withr, fs, rlang, testthat and cli --
  # the packages that handle temp files most carefully of anyone.
  #
  # And note what CRAN's Repository Policy actually says: a package may not write
  # "anywhere else on the file system apart from the R session's temporary
  # directory". The temp directory is the one place it EXPRESSLY permits. Since
  # tempfile() returns a path INSIDE tempdir(), and R removes tempdir() when the
  # session ends, an un-unlinked tempfile() breaks no rule at all. This check is
  # therefore `opinion`: a tidiness hint about disk accumulating inside one long
  # session, not a policy violation. Writing OUTSIDE tempdir is a real breach, and
  # that is what home_writing and file_operations are for.
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Temp cleanup check"))
  }
  test_parsed <- parsed

  cleanup_funs <- c(
    "unlink",
    "file.remove",
    "on.exit",
    "defer",
    "defer_cleanup",
    "local_tempfile",
    "deferred_run"
  )
  predicate <- paste(sprintf("text() = '%s'", cleanup_funs), collapse = " or ")
  # A tempfile()/tempdir() call is "clean" if cleanup exists in any of:
  #   (a) the innermost enclosing function body (most precise),
  #   (b) the same top-level statement (handles testthat blocks like
  #       `test_that("...", { tempfile(); on.exit(...) })` where the lambda is
  #       constructed at runtime, not statically a FUNCTION node), or
  #   (c) a later top-level statement (handles top-level test scripts).
  # Only tempfile() needs explicit cleanup; tempdir() returns the session
  # temp directory which R auto-cleans at session end.
  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[text() = 'tempfile'][
       not(ancestor::expr[parent::expr/FUNCTION][1]//SYMBOL_FUNCTION_CALL[%s])
       and not(
         ancestor::expr[parent::exprlist][1]
         //SYMBOL_FUNCTION_CALL[%s]
       )
       and not(
         ancestor::expr[parent::exprlist][1]
         /following-sibling::expr
         //SYMBOL_FUNCTION_CALL[%s]
       )
     ]",
    predicate,
    predicate,
    predicate
  )
  issues <- xpath_lints(test_parsed, xpath)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Temp file usage appears to include cleanup",
    "Temp files without apparent cleanup",
    "Treatment: Add cleanup (unlink, on.exit, withr::local_tempfile, ...)"
  )
  checktor_check_result(passed, issues, "Temp cleanup check")
}

#' Diagnose Writes to the Global Environment
#'
#' Flags a `<<-` whose target binds in neither an enclosing function nor the package, and so reaches `.GlobalEnv`. A closure updating its parent, or a package-level cache, is not flagged.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' states that "Packages should not modify the global environment (user's
#' workspace)." See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_globalenv_modification(pkg, verbose = FALSE)$passed
diagnose_globalenv_modification <- function(
  path,
  verbose = TRUE,
  parsed = NULL
) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "GlobalEnv modification check"
    ))
  }

  # `<<-` does NOT mean ".GlobalEnv". It walks the enclosing environments and
  # assigns in the first one where the name is already bound, only reaching
  # .GlobalEnv when the name is bound nowhere else. So a `<<-` is a global write
  # only when its target binds in neither an enclosing function nor the package
  # namespace. Flagging every `<<-` false-positives on the two commonest correct
  # uses: a closure updating a variable in its parent frame, and the package-level
  # memoisation idiom (`.cache <<- ...`).
  #
  # The `.GlobalEnv` / globalenv() *reference* rule is gone entirely. It flagged
  # pure reads such as `exists(nm, envir = globalenv())`, and the one write form
  # that matters, `assign(x, envir = .GlobalEnv)`, is already an R CMD check NOTE
  # ("Found the following assignments to the global environment"), so duplicating
  # it here would only add noise.
  pkg_level <- package_level_names(parsed)

  issues <- character(0)
  for (p in parsed) {
    if (!is.null(p$error) || is.null(p$xml)) {
      next
    }
    # A `<<-` inside a setRefClass()/R6Class()/setClass() body is FIELD or PRIVATE
    # assignment, not a global write: it is the documented way an RC method updates
    # its object's own field, and R6's active-binding setters use it too. chapensk's
    # Reference Class alone produced 52 findings this way.
    ops <- xml2::xml_find_all(
      p$xml,
      paste0(
        "(//LEFT_ASSIGN[text() = '<<-'] | //RIGHT_ASSIGN[text() = '->>'])",
        "[not(ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[",
        "  text() = 'setRefClass' or text() = 'R6Class' or text() = 'setClass'",
        "]])]"
      )
    )
    for (op in ops) {
      target <- superassign_target(op)
      if (!nzchar(target)) {
        next
      }
      if (target %in% pkg_level) {
        next
      } # package-level binding, e.g. a cache
      if (binds_in_enclosing_function(op, target)) {
        next
      }
      # The function was stored into a container and gets its closure environment
      # at run time, so we cannot see where this `<<-` lands. Do not guess.
      if (in_container_assigned_function(op)) {
        next
      }
      issues <- c(
        issues,
        paste0(
          basename(p$file),
          ":",
          xml2::xml_attr(op, "line1"),
          " (",
          target,
          ")"
        )
      )
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No {.code .GlobalEnv} modification detected",
    "Assignment reaches the global environment",
    "Treatment: Bind the name in the package or an enclosing function, or use a local cache environment"
  )
  checktor_check_result(passed, issues, "GlobalEnv modification check")
}

#' Diagnose installed.packages() Usage
#'
#' Flags `installed.packages()`, which is slow and is discouraged by its own help page.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' does not let a package install other packages when it runs. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_installed_packages_usage(pkg, verbose = FALSE)$passed
diagnose_installed_packages_usage <- function(
  path,
  verbose = TRUE,
  parsed = NULL
) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "installed.packages() usage check"
    ))
  }
  issues <- undesirable_function_check(
    parsed,
    "installed.packages",
    label = FALSE
  )
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No {.code installed.packages()} usage found",
    "{.code installed.packages()} usage found",
    "Treatment: Use {.code requireNamespace()} or {.code find.package()} instead"
  )
  checktor_check_result(passed, issues, "installed.packages() usage check")
}

# `options(..., warn = -1)` in any form: standalone, multi-arg, or wrapped in
# withr::local_options/with_options. Anchors on the named-arg SYMBOL_SUB
# (a child of the call expr), then checks its value expr for `-1`.
#' Diagnose Changes to options(warn=)
#'
#' Flags a change to `options(warn = )` that is not restored.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Setting options(warn = -1)](https://contributor.r-project.org/cran-cookbook/code_issues.html#setting-optionswarn--1).
#' Suppressing warnings for the rest of the session hides them from everything that
#' runs afterwards, so restore the previous value via `on.exit()`. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_warn_option(pkg, verbose = FALSE)$passed
diagnose_warn_option <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Warn option check"))
  }

  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[",
    "  text() = 'options' or text() = 'local_options' or text() = 'with_options'",
    "]/parent::expr/parent::expr/SYMBOL_SUB[text() = 'warn'][",
    "  following-sibling::expr[1][OP-MINUS and expr/NUM_CONST[text() = '1']]",
    "]"
  )
  issues <- xpath_lints(parsed, xpath)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No {.code options(warn = -1)} usage found",
    "{.code options(warn = -1)} usage found",
    "Treatment: Use {.code suppressWarnings()} for a narrow scope instead"
  )
  checktor_check_result(passed, issues, "Warn option check")
}

#' Diagnose Package Installation From Package Code
#'
#' Flags `install.packages()` and friends. A package may not install software on the user's machine.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' does not let a package download and install external software when it loads
#' or runs. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#'                                  show_content = FALSE)
#' diagnose_software_installation(pkg, verbose = FALSE)$passed
diagnose_software_installation <- function(
  path,
  verbose = TRUE,
  parsed = NULL
) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Software installation check"
    ))
  }

  direct_funs <- c(
    "install.packages",
    "pkg_install",
    "install_local",
    "install_github",
    "install_url",
    "install_bitbucket",
    "install_cran",
    "install_dev",
    "install_git",
    "install_gitlab",
    "install_svn",
    "install_version"
  )
  # CRAN's objection is a package installing software on the user's machine WITHOUT
  # ASKING. rlang, devtools and usethis all prompt first, which is the only way an
  # install helper can exist at all. A call the user consented to is the sanctioned
  # form.
  consented <- not_under_fn_with_call_xpath(c(
    "menu",
    "askYesNo",
    "yesno",
    "readline",
    "select.list",
    "is_interactive",
    "interactive",
    "check_installed"
  ))
  predicate <- paste(sprintf("text() = '%s'", direct_funs), collapse = " or ")
  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[(%s) and %s and %s]",
    predicate,
    NOT_MEMBER_ACCESS,
    consented
  )
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    paste0(
      basename(file),
      ":",
      xml2::xml_attr(nodes, "line1"),
      " (",
      xml2::xml_text(nodes),
      "())"
    )
  })

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No software installation in functions detected",
    "Potential software installation in functions",
    "Treatment: Packages should not install other packages at runtime",
    max_show = 3L
  )
  checktor_check_result(passed, issues, "Software installation check")
}

# Parallelism calls without an explicit per-call core bound. Looks for
# mclapply/parLapply/makeCluster/detectCores whose enclosing call has no
# `mc.cores =` named argument.
#' Diagnose Parallel Core Usage
#'
#' Flags a worker count that can exceed CRAN's two-core limit. Understands parallel, snow, foreach, future, furrr, mirai, RcppParallel, data.table, and BiocParallel.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' states that "If running a package uses multiple threads/cores it must never
#' use more than two simultaneously". See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' diagnose_core_usage(pkg, verbose = FALSE)$passed
diagnose_core_usage <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Core usage check"))
  }

  # CRAN's rule is: "If running a package uses multiple threads/cores it must
  # never use more than two simultaneously." The prohibition is on USING more
  # than two, not on calling detectCores().
  #
  # The old rule required an `mc.cores` named argument on the call itself. But
  # `mc.cores` is an argument of mclapply()/pvec() ONLY: detectCores() takes no
  # arguments at all, makeCluster() takes `spec`, parLapply() takes a cluster. So
  # detectCores() could never satisfy it and was flagged 100% of the time, while
  # `makeCluster(2L)` -- explicitly CRAN-compliant -- was flagged too.
  #
  # What actually matters is the WORKER COUNT handed to each framework, measured
  # under `_R_CHECK_LIMIT_CORES_=TRUE` (the CRAN check environment):
  #
  #     parallel::detectCores()        -> 12   ignores the CRAN limit
  #     parallelly::availableCores()   ->  2   auto-caps
  #     future::availableCores()       ->  2   auto-caps
  #
  # So a worker count is risky when it is a literal above 2, or is derived from
  # detectCores(). It is safe when it comes from availableCores(), is capped at 2,
  # or sits in a function that guards on the CRAN environment variables.
  issues <- character(0)
  for (p in parsed) {
    if (!is.null(p$error) || is.null(p$xml)) {
      next
    }
    calls <- xml2::xml_find_all(
      p$xml,
      sprintf(
        "//SYMBOL_FUNCTION_CALL[%s]",
        paste(
          sprintf("text() = '%s'", names(PARALLEL_WORKER_ARG)),
          collapse = " or "
        )
      )
    )
    for (cl in calls) {
      fn <- xml2::xml_text(cl)
      w <- worker_count_expr(cl, PARALLEL_WORKER_ARG[[fn]])
      if (is.null(w)) {
        next
      } # no explicit count: defaults are safe
      if (!worker_count_is_risky(w)) {
        next
      }
      if (has_cran_core_guard(cl)) {
        next
      }
      issues <- c(
        issues,
        paste0(
          basename(p$file),
          ":",
          xml2::xml_attr(cl, "line1"),
          " (",
          fn,
          "() worker count is unbounded)"
        )
      )
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Core usage is bounded for CRAN",
    "Worker count may exceed the two cores CRAN allows",
    "Treatment: Use {.code parallelly::availableCores()}, which caps at 2 under {.envvar _R_CHECK_LIMIT_CORES_}, or guard the count yourself",
    max_show = 3L
  )
  checktor_check_result(passed, issues, "Core usage check")
}

# Worker-count argument per parallel framework. A name means a named argument;
# `1L` means the first positional argument.
PARALLEL_WORKER_ARG <- list(
  # parallel / snow
  mclapply = "mc.cores",
  mcmapply = "mc.cores",
  pvec = "mc.cores",
  makeCluster = 1L,
  makePSOCKcluster = 1L,
  makeForkCluster = 1L,
  # foreach backends
  registerDoParallel = "cores",
  registerDoMC = "cores",
  registerDoSNOW = 1L,
  # future / furrr (furrr inherits the plan, so plan() is the control point)
  plan = "workers",
  # mirai
  daemons = 1L,
  # RcppParallel
  setThreadOptions = "numThreads",
  # data.table
  setDTthreads = 1L,
  # BiocParallel
  MulticoreParam = "workers",
  SnowParam = "workers"
)

# The expression supplying the worker count for a call, or NULL when none is
# given (the framework defaults are all CRAN-safe).
worker_count_expr <- function(call_node, arg) {
  if (is.character(arg)) {
    e <- xml2::xml_find_first(
      call_node,
      sprintf(
        "parent::expr/parent::expr/SYMBOL_SUB[text() = '%s']/following-sibling::expr[1]",
        arg
      )
    )
  } else {
    # First positional argument. A named argument's value is also an <expr>
    # sibling, so require that it not be preceded by an EQ_SUB.
    e <- xml2::xml_find_first(
      call_node,
      "parent::expr/following-sibling::expr[1][not(preceding-sibling::*[1][self::EQ_SUB])]"
    )
  }
  if (inherits(e, "xml_missing")) NULL else e
}

# A worker count is risky when it is a numeric literal above 2, or is derived
# from detectCores(). availableCores() already caps itself at 2 under the CRAN
# check environment, so it is safe.
worker_count_is_risky <- function(w) {
  if (
    length(xml2::xml_find_all(
      w,
      ".//SYMBOL_FUNCTION_CALL[text() = 'availableCores']"
    ))
  ) {
    return(FALSE)
  }
  if (
    length(xml2::xml_find_all(
      w,
      ".//SYMBOL_FUNCTION_CALL[text() = 'detectCores']"
    ))
  ) {
    return(TRUE)
  }
  nums <- xml2::xml_find_all(w, "descendant-or-self::NUM_CONST")
  if (
    length(nums) == 1L &&
      length(xml2::xml_find_all(w, ".//SYMBOL_FUNCTION_CALL")) == 0L
  ) {
    n <- suppressWarnings(as.numeric(sub("L$", "", xml2::xml_text(nums))))
    return(!is.na(n) && n > 2)
  }
  FALSE # a bare variable: not resolvable statically, so do not guess
}

# TRUE when the enclosing function caps cores for CRAN, i.e. it mentions
# _R_CHECK_LIMIT_CORES_ or NOT_CRAN. This is the guard packages implement to cap
# cores under CRAN, and it is byte-for-byte R's own parallel:::.check_ncores predicate.
has_cran_core_guard <- function(call_node) {
  hits <- xml2::xml_find_all(
    call_node,
    paste0(
      "ancestor::expr[FUNCTION]//STR_CONST[",
      "  contains(text(), '_R_CHECK_LIMIT_CORES_') or contains(text(), 'NOT_CRAN')",
      "]"
    )
  )
  length(hits) > 0L
}

# library() / require() in package R/ code is almost always a mistake -
# package dependencies belong in DESCRIPTION Imports/Depends and should be
# referenced via NAMESPACE imports or pkg::fn calls.
#
# The exception is code destined for a WORKER process. A parallel daemon starts
# with an empty search path, so `mirai::everywhere({ library(pkg) })` and
# `parallel::clusterEvalQ(cl, library(pkg))` are not altering the user's search
# path at all -- they are setting up someone else's. Flagging it was flagging
# the one place library() is the right call.
REMOTE_EVAL_FUNS <- c(
  "everywhere",
  "clusterEvalQ",
  "clusterCall",
  "clusterApply",
  "evalq"
)

#' Diagnose library() in Package Code
#'
#' Flags `library()` / `require()` in package code, which alters the user's search path. Code destined for a parallel worker is exempt, since a daemon starts with an empty search path.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_library_in_pkg_code(pkg, verbose = FALSE)$passed
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Package-Dependencies),
#' under "Package Dependencies", asks package code to reach its dependencies
#' through `Imports` and `::` rather than attaching them with `library()`. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
diagnose_library_in_pkg_code <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "library() in pkg code check"
    ))
  }
  remote <- paste(
    sprintf("text() = '%s'", REMOTE_EVAL_FUNS),
    collapse = " or "
  )
  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[text() = 'library' or text() = 'require'][
       not(ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[%s]])
     ]",
    remote
  )
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    paste0(
      basename(file),
      ":",
      xml2::xml_attr(nodes, "line1"),
      " (",
      xml2::xml_text(nodes),
      "())"
    )
  })
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No {.code library()}/{.code require()} calls in package code",
    "{.code library()}/{.code require()} calls in package code",
    "Treatment: Declare deps in DESCRIPTION Imports and use {.code pkg::fn()}"
  )
  checktor_check_result(passed, issues, "library() in pkg code check")
}

# Sys.setenv() without on.exit()/withr cleanup in the same function body.
# Mirrors diagnose_option_changes for environment variables.
#' Diagnose Unrestored Environment Variables
#'
#' Flags `Sys.setenv()` with no matching cleanup in the same function.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_sys_setenv_no_reset(pkg, verbose = FALSE)$passed
diagnose_sys_setenv_no_reset <- function(path, verbose = TRUE, parsed = NULL) {
#' @section Source:
#' No clause names environment variables, but they are session state exactly as
#' `options()` are, so the same restore-on-exit requirement applies. The CRAN
#' Cookbook states it for options under
#' [Change of Options, Graphical Parameters and Working Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory).
#' See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Sys.setenv reset check"))
  }
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'Sys.setenv'][",
    "  ",
    not_under_fn_with_call_xpath(c(
      "on.exit",
      "Sys.unsetenv",
      "local_envvar",
      "with_envvar"
    )),
    "]"
  )
  # A setter that captures the prior state and hands it back is participating in a
  # restore contract, not leaking: the caller restores. This is how withr's
  # set_path()/set_envvar() are built, and it is the same base-R contract
  # option_changes already honours, just written across statements because
  # Sys.setenv() returns TRUE rather than the old value.
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    keep <- !vapply(nodes, enclosing_fn_returns_capture, logical(1))
    nodes <- nodes[keep]
    if (length(nodes) == 0L) {
      return(character(0))
    }
    paste0(basename(file), ":", xml2::xml_attr(nodes, "line1"))
  })
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "{.code Sys.setenv()} calls appear to be reset",
    "{.code Sys.setenv()} without apparent reset",
    "Treatment: Use {.code on.exit(Sys.unsetenv(...))} or {.code withr::local_envvar()}"
  )
  checktor_check_result(passed, issues, "Sys.setenv reset check")
}

#' Diagnose Unguarded `detectCores()`
#'
#' Flags a `parallel::detectCores()` call whose result is used without an `NA`
#' guard.
#'
#' `?detectCores` says so in as many words: *"An integer, `NA` if the answer is
#' unknown"*, and R's own advice is to avoid it, *"First because it may return
#' `NA`"*. `NA` then propagates silently through the arithmetic packages usually
#' do next, and the failure surfaces far from its cause:
#'
#' ```r
#' n <- parallel::detectCores() - 1   # NA - 1 is NA
#' if (cores > n) cores <- n          # Error: missing value where TRUE/FALSE needed
#' ```
#'
#' This is a robustness defect rather than a policy one, and it is distinct from
#' the `core_usage` check, which asks how many cores you *use*. A package can cap
#' itself at two cores perfectly and still crash on the machine where
#' `detectCores()` returns `NA`.
#'
#' A call is treated as guarded when its enclosing function tests for `NA`
#' (`is.na()`), passes `na.rm = TRUE`, or supplies a fallback with `%||%`. The
#' durable fix is `parallelly::availableCores()`, which never returns `NA` and
#' also honours the CRAN core limit.
#'
#' @inheritParams diagnose_tf_usage
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_detect_cores_robustness(pkg, verbose = FALSE)$passed
diagnose_detect_cores_robustness <- function(
  path,
  verbose = TRUE,
  parsed = NULL
) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
#' @section Source:
#' No formal rule. `?detectCores` states it returns "`NA` if the answer is
#' unknown", and the arithmetic that usually follows then crashes, which is why
#' this sits at `robustness` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "detectCores() NA check"))
  }

  # Guarded when the enclosing function tests for NA, strips it, or defaults it.
  guarded <- paste0(
    "ancestor::expr[FUNCTION][1][",
    "  .//SYMBOL_FUNCTION_CALL[text() = 'is.na']",
    "  or .//SYMBOL_SUB[text() = 'na.rm']",
    "  or .//SPECIAL[text() = '%||%']",
    "]"
  )
  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[text() = 'detectCores'][not(%s)]",
    guarded
  )
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    paste0(
      basename(file),
      ":",
      xml2::xml_attr(nodes, "line1"),
      " (detectCores() may return NA)"
    )
  })

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "{.code detectCores()} results are NA-guarded",
    "{.code detectCores()} result used without an {.code NA} guard",
    "Treatment: Use {.code parallelly::availableCores()}, which never returns NA",
    level = "warning"
  )
  checktor_check_result(passed, issues, "detectCores() NA check")
}

#' Diagnose Hardcoded Credentials in Package Code
#'
#' Flags a secret that looks like an API key, access token, or private key
#' sitting in a string literal in `R/`. `R CMD check` does not scan for leaked
#' credentials, yet a token committed to a package is a security problem: once
#' the package is published to CRAN the secret is public and must be revoked.
#'
#' Only string literals in the parsed sources are examined, so the same text in
#' a comment or a variable name never matches, and the check's own pattern
#' strings never flag themselves.
#'
#' @details
#' Each format is anchored on a provider-specific prefix so ordinary code does
#' not match. The recognised credentials, and the prefix each is keyed on, are:
#'
#' - **Version control and registries**: GitHub tokens (`ghp_`, `gho_`, `ghu_`,
#'   `ghs_`, `ghr_`, and fine-grained `github_pat_`), GitLab tokens (`glpat-`),
#'   npm tokens (`npm_`), and PyPI upload tokens (`pypi-AgEIcHlwaS5vcmc`).
#' - **Cloud providers**: AWS access keys (`AKIA`, `ASIA`, `AROA`, `AIDA`,
#'   `AGPA`, `ABIA`, `ACCA`), Google API keys (`AIza`), Google OAuth client
#'   secrets (`GOCSPX-`), and DigitalOcean tokens (`dop_v1_`).
#' - **AI and ML providers**: OpenAI keys (`sk-`, `sk-proj-`), Anthropic keys
#'   (`sk-ant-`), and Hugging Face tokens (`hf_`).
#' - **Payments**: Stripe secret and restricted keys (`sk_live_`, `sk_test_`,
#'   `rk_live_`, `rk_test_`) and Square tokens (`sq0atp-`, `sq0csp-`, `EAAA`).
#' - **Messaging**: Slack tokens (`xoxb-`, `xoxp-`, ...) and incoming webhooks
#'   (`hooks.slack.com/services/...`), SendGrid keys (`SG.`), and Telegram bot
#'   tokens (`<id>:AA...`).
#' - **Platforms**: Shopify tokens (`shpat_`, `shpss_`, `shpca_`, `shppa_`),
#'   Databricks tokens (`dapi`), and Postman keys (`PMAK-`).
#' - **Generic**: JSON Web Tokens (`eyJ...`) and PEM private-key headers
#'   (`-----BEGIN ... PRIVATE KEY-----`).
#'
#' The prefixes and lengths follow each provider's published token format and
#' the community-maintained gitleaks secret-detection ruleset.
#'
#' @references
#' Provider token formats and the gitleaks ruleset:
#' \url{https://github.com/gitleaks/gitleaks}
#'
#' @inheritParams diagnose_tf_usage
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/credentials_bad.R",
#'                                  show_content = FALSE)
#' diagnose_hardcoded_credentials(pkg, verbose = FALSE)$passed
diagnose_hardcoded_credentials <- function(
  path,
  verbose = TRUE,
  parsed = NULL
) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
#' @section Source:
#' No formal rule. A token or key committed to a package is public the moment it
#' reaches CRAN and must be revoked, which is why this sits at `robustness`
#' tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
    return(checktor_check_result(
      TRUE,
      character(0),
      "Hardcoded credential check"
    ))
  }

  # Well-known secret shapes only, keyed on a provider prefix so ordinary code
  # does not match. Prefixes and lengths follow each provider's published token
  # format and the gitleaks ruleset. The random-tail quantifiers mean the
  # pattern strings below never match themselves when checktor scans its own R/.
  patterns <- c(
    # version control and package registries
    "GitHub token" = "gh[pousr]_[A-Za-z0-9]{36}",
    "GitHub fine-grained PAT" = "github_pat_[A-Za-z0-9_]{80,}",
    "GitLab token" = "glpat-[A-Za-z0-9_-]{20}",
    "npm token" = "npm_[A-Za-z0-9]{36}",
    "PyPI token" = "pypi-AgEIcHlwaS5vcmc[A-Za-z0-9_-]{50,}",
    # cloud providers
    "AWS access key" = "(?:AKIA|ASIA|AIDA|AROA|AGPA|ABIA|ACCA)[A-Z0-9]{16}",
    "Google API key" = "AIza[A-Za-z0-9_-]{35}",
    "Google OAuth secret" = "GOCSPX-[A-Za-z0-9_-]{28}",
    "DigitalOcean token" = "dop_v1_[a-f0-9]{64}",
    # AI / ML providers
    "OpenAI key" = "sk-proj-[A-Za-z0-9_-]{20,}",
    "OpenAI key (legacy)" = "sk-[A-Za-z0-9]{32,}",
    "Anthropic key" = "sk-ant-[A-Za-z0-9_-]{20,}",
    "Hugging Face token" = "hf_[A-Za-z0-9]{34,}",
    # payments
    "Stripe key" = "(?:sk|rk)_(?:live|test|prod)_[A-Za-z0-9]{10,99}",
    "Square token" = "(?:EAAA|sq0atp-|sq0csp-)[A-Za-z0-9_-]{22,60}",
    # messaging
    "Slack token" = "xox[baprs]-[A-Za-z0-9-]{10,}",
    "Slack webhook" = "https://hooks\\.slack\\.com/(?:services|workflows|triggers)/[A-Za-z0-9+/]{43,56}",
    "SendGrid key" = "SG\\.[A-Za-z0-9_.=-]{66}",
    "Telegram bot token" = "[0-9]{6,16}:AA[A-Za-z0-9_-]{33}",
    # platforms
    "Shopify token" = "shp(?:at|ss|ca|pa)_[a-fA-F0-9]{32}",
    "Databricks token" = "dapi[a-f0-9]{32}",
    "Postman API key" = "PMAK-[a-fA-F0-9]{24}-[a-fA-F0-9]{34}",
    # generic
    "JSON Web Token" = "eyJ[A-Za-z0-9_-]{10,}\\.eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}",
    "private key" = "-----BEGIN [A-Z ]*PRIVATE KEY-----"
  )

  issues <- xpath_per_file(parsed, "//STR_CONST", function(file, nodes) {
    text <- xml2::xml_text(nodes)
    line <- xml2::xml_attr(nodes, "line1")
    hits <- character(0)
    for (k in seq_along(patterns)) {
      # A left boundary so a prefix like `sk-` or `AKIA` only matches when it
      # starts a token, not when it sits inside a longer word (`disk-...`).
      m <- grepl(
        paste0("(?<![A-Za-z0-9])", patterns[[k]]),
        text,
        perl = TRUE
      )
      if (any(m)) {
        hits <- c(
          hits,
          paste0(basename(file), ":", line[m], " (", names(patterns)[k], ")")
        )
      }
    }
    hits
  })
  issues <- unique(issues)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No hardcoded credentials found",
    "Possible hardcoded credential in package code",
    "Treatment: remove the secret, revoke it, and read it from an environment variable at run time"
  )
  checktor_check_result(passed, issues, "Hardcoded credential check")
}

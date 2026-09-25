# Example check for session state an example changes and never puts back.

#' Diagnose Session State Left Changed by Examples
#'
#' Flags an example, vignette or demo that changes `options()`, `par()` or the
#' working directory without putting it back. A reader who runs the example is left
#' with a session that behaves differently afterwards.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Change of Options, Graphical Parameters and Working Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory),
#' and the rejection reads "Please always make sure to reset to user's options(),
#' working directory or par() after you changed it in examples and vignettes and
#' demos." See `vignette("check-sources", package = "checktor")` for how every check
#' maps to its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_option_changes()] for the same rule in `R/`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/example_state_bad.Rmd",
#'                                  show_content = FALSE)
#' lab_example_state(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_example_state <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette", "demo"))
  if (length(parsed) == 0L) {
    return(pass_result(check_label("example_state")))
  }

  issues <- character(0)
  for (src in parsed) {
    # A named argument is what makes options() or par() a write rather than a
    # read. par()'s no.readonly is the exception: it asks for the settings and
    # changes none of them.
    setters <- xml2::xml_find_all(
      src$xml,
      paste0(
        "//SYMBOL_FUNCTION_CALL[text() = 'options']",
        "/parent::expr/parent::expr[SYMBOL_SUB]",
        " | //SYMBOL_FUNCTION_CALL[text() = 'par']",
        "/parent::expr/parent::expr[SYMBOL_SUB[text() != 'no.readonly']]",
        " | //SYMBOL_FUNCTION_CALL[text() = 'setwd']/parent::expr/parent::expr"
      )
    )
    if (length(setters) == 0L) {
      next
    }
    # Each kind of state is judged on its own: par() put back leaves a changed
    # working directory changed.
    kinds <- STATE_RESTORE_KIND[xml2::xml_text(
      xml2::xml_find_first(setters, "./expr[1]/SYMBOL_FUNCTION_CALL")
    )]
    setters <- setters[!kinds %in% state_restored(src$xml)]
    if (length(setters) == 0L) {
      next
    }
    lines <- xml2::xml_attr(setters, "line1")
    issues <- c(
      issues,
      paste0(src$kind, " ", basename(src$file), ":", lines, " (never restored)")
    )
  }
  issues <- unique(issues)

  report_check(
    issues,
    verbose,
    check_label("example_state"),
    "Examples restore any session state they change",
    "Examples change session state without restoring it",
    treatment = paste("Treatment:", treatments$example_state$treatment)
  )
}

# The kinds of state an example can change, by the calls that read or replace
# them. A value captured from one kind is put back only by that kind's setter:
# an old directory handed to options() restores nothing.
STATE_CAPTURE_KIND <- c(
  options = "options",
  getOption = "options",
  par = "par",
  setwd = "wd",
  getwd = "wd"
)
STATE_RESTORE_KIND <- c(options = "options", par = "par", setwd = "wd")

# Calls that evaluate the code they are handed in a call of their own, so an
# on.exit() in that code fires when the call returns, as in a function. Code
# handed to suppressWarnings() or invisible() is a promise, evaluated where it
# was written, so an on.exit() there is as top level as the call.
ON_EXIT_FRAME_CALLS <- c("local", "with", "within", "eval", "evalq")

# Calls that return the value they wrap, so `suppressWarnings(par(...))` still
# holds what par() returned.
STATE_VALUE_WRAPPERS <- c("suppressWarnings", "suppressMessages", "invisible")

# Which kinds of state does this example, vignette or demo put back? The old value
# has to be captured and then handed back, which is what the reviewer asks for,
# and a restore anywhere later in the same file counts.
#
# A capture is an assignment whose value IS the call that reads or replaces the
# state, or one setting taken out of it: `old <- options(digits = 3)`, `op <-
# par(no.readonly = TRUE)`, `owd = getwd()`, `old <- par()[["mfrow"]]`, `old <-
# getOption("digits")`, or `old <- setwd(tempdir())`, since setwd() returns the
# directory it leaves as options() and par() return the values they replace. The
# call may be wrapped in suppressWarnings() or invisible(), or be the right-hand
# side of a pipe, as in `old <- tempdir() |> setwd()`. A function that calls
# setwd(), or a tryCatch() around it, holds no old state.
#
# The restore is that captured name handed back to the setter of the same kind,
# by position or by name, through do.call(), or down a pipe. Inside on.exit() it
# counts only when the on.exit() belongs to a function or to one of
# ON_EXIT_FRAME_CALLS: at top level there is nothing to exit, so R CMD check
# never runs it, and knitr runs it right after its own line, before the change
# it was meant to undo. A capture never handed back keeps the way home and never
# takes it, which is the shape CRAN sends back.
state_restored <- function(xml) {
  targets <- xml2::xml_find_all(
    xml,
    paste0(
      "//", ASSIGN_NODE, "[LEFT_ASSIGN or EQ_ASSIGN]/expr[1][count(*) = 1]/SYMBOL",
      " | //", ASSIGN_NODE, "[RIGHT_ASSIGN]/expr[2][count(*) = 1]/SYMBOL"
    )
  )
  top_level_exit <- paste0(
    "ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[text() = 'on.exit']]",
    "[not(ancestor::expr[FUNCTION or OP-LAMBDA or expr[1]/SYMBOL_FUNCTION_CALL[",
    paste0("text() = '", ON_EXIT_FRAME_CALLS, "'", collapse = " or "),
    "]])]"
  )
  restored <- character(0)
  for (target in targets) {
    assignment <- xml2::xml_find_first(target, "parent::expr/parent::*")
    right <- xml2::xml_find_lgl(assignment, "boolean(RIGHT_ASSIGN)")
    value <- xml2::xml_find_first(assignment, if (right) "expr[1]" else "expr[2]")
    kind <- captured_state(value)
    if (is.na(kind) || kind %in% restored) {
      next
    }
    setter <- names(STATE_RESTORE_KIND)[STATE_RESTORE_KIND == kind]
    calls <- sprintf("following::SYMBOL_FUNCTION_CALL[text() = '%s']", setter)
    do_calls <- sprintf(
      paste0(
        "following::SYMBOL_FUNCTION_CALL[text() = 'do.call']/parent::expr",
        "/parent::expr[expr[2][SYMBOL[text() = '%1$s']",
        " or STR_CONST[text() = '\"%1$s\"' or text() = \"'%1$s'\"]]]"
      ),
      setter
    )
    pipes <- sprintf(
      paste0(
        "following::expr[PIPE or SPECIAL[%s]]",
        "[expr[2]/expr[1]/SYMBOL_FUNCTION_CALL[text() = '%s']]"
      ),
      paste(sprintf("text() = '%s'", MAGRITTR_PIPES), collapse = " or "),
      setter
    )
    handed_back <- xml2::xml_find_all(
      assignment,
      paste0(
        calls, "/parent::expr/parent::expr[not(", top_level_exit, ")]",
        "/expr[position() > 1][count(*) = 1]/SYMBOL",
        " | ", do_calls, "[not(", top_level_exit, ")]/expr[3][count(*) = 1]/SYMBOL",
        " | ", pipes, "[not(", top_level_exit, ")]/expr[1][count(*) = 1]/SYMBOL"
      )
    )
    if (xml2::xml_text(target) %in% xml2::xml_text(handed_back)) {
      restored <- c(restored, kind)
    }
  }
  restored
}

# The kind of state an assigned value holds, or NA. It holds one when it is a
# call that reads or replaces the state, one setting taken out of such a call,
# that call inside a wrapper that returns it, or that call on the right of a pipe
# that returns its result. `%T>%` returns its left-hand side, so it is not one.
captured_state <- function(node, depth = 0L) {
  if (inherits(node, "xml_missing") || depth > 5L) {
    return(NA_character_)
  }
  rhs <- xml2::xml_find_first(
    node,
    paste0(
      "./expr[preceding-sibling::*[1][self::PIPE",
      " or self::SPECIAL[text() = '%>%' or text() = '%!>%']]]"
    )
  )
  if (!inherits(rhs, "xml_missing")) {
    fn <- xml2::xml_text(xml2::xml_find_first(rhs, "./expr[1]/SYMBOL_FUNCTION_CALL"))
    if (fn %in% STATE_VALUE_WRAPPERS) {
      return(captured_state(xml2::xml_find_first(node, "./expr[1]"), depth + 1L))
    }
    return(unname(STATE_CAPTURE_KIND[fn]))
  }
  fn <- xml2::xml_text(xml2::xml_find_first(node, "./expr[1]/SYMBOL_FUNCTION_CALL"))
  if (!is.na(fn)) {
    if (fn %in% STATE_VALUE_WRAPPERS) {
      return(captured_state(xml2::xml_find_first(node, "./expr[2]"), depth + 1L))
    }
    return(unname(STATE_CAPTURE_KIND[fn]))
  }
  if (xml2::xml_find_lgl(node, "boolean(LBB or OP-LEFT-BRACKET or OP-DOLLAR)")) {
    return(captured_state(xml2::xml_find_first(node, "./expr[1]"), depth + 1L))
  }
  NA_character_
}

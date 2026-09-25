# Example check for interactive calls hidden in \dontrun{} or \donttest{}.

# Functions that need a person at the keyboard: an app or gadget that blocks until
# it is closed, a viewer, a browser, or a prompt waiting for input.
INTERACTIVE_CALLS <- c(
  "runApp", "shinyApp", "shinyAppDir", "shinyAppFile", "runGadget", "runExample",
  "runUrl", "runGitHub", "runGist", "browseURL", "browseVignettes", "View",
  "readline", "menu", "select.list", "askYesNo", "file.choose", "choose.files",
  "choose.dir", "file.edit"
)

# These build an app object, which runs only when it is printed. Kept in a
# variable or handed to another function, nothing starts.
INTERACTIVE_WHEN_PRINTED <- c("shinyApp", "shinyAppDir", "shinyAppFile")

# Launchers named for what they open, such as run_app(), launch_dashboard(),
# runShinyApp(), launch_shinystan() and launchGUI(). Every app package names its
# own, so this matches the shape of the name rather than a list of them.
INTERACTIVE_LAUNCHER_RE <- paste0(
  "^(run|launch)[A-Za-z0-9_.]*",
  "([Aa]pp|[Gg]adget|[Dd]ashboard|GUI|[Gg]ui|[Ss]hiny[A-Za-z0-9]*)$"
)

# Whether a call runs only in an interactive session.
interactive_guarded <- function(call) guarded_by(call, is_interactive_call)

# Every unguarded interactive call inside a hidden block, as list(fn, tag). A
# call outside every hidden block is left to R CMD check, which runs it.
hidden_interactive_calls <- function(xml) {
  calls <- xml2::xml_find_all(
    xml,
    paste0("//SYMBOL_FUNCTION_CALL[", NOT_MEMBER_ACCESS, "]")
  )
  names <- xml2::xml_text(calls)
  calls <- calls[
    names %in% INTERACTIVE_CALLS | grepl(INTERACTIVE_LAUNCHER_RE, names)
  ]
  # A statement at top level, or inside a `{` block that is not a function body,
  # has its value printed.
  printed <- paste0(
    "parent::expr/parent::expr[parent::exprlist or ",
    "parent::expr[OP-LEFT-BRACE][not(parent::expr[FUNCTION or OP-LAMBDA])]]"
  )
  marker <- paste0(
    "ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[",
    paste0("text() = '", HIDDEN_EXAMPLE_MARKERS, "'", collapse = " or "),
    "]][1]/expr[1]/SYMBOL_FUNCTION_CALL"
  )
  out <- list()
  for (call in calls) {
    fn <- xml2::xml_text(call)
    if (
      fn %in% INTERACTIVE_WHEN_PRINTED &&
        length(xml2::xml_find_all(call, printed)) == 0L
    ) {
      next
    }
    if (interactive_guarded(call)) {
      next
    }
    block <- xml2::xml_find_first(call, marker)
    if (inherits(block, "xml_missing")) {
      next
    }
    tag <- names(HIDDEN_EXAMPLE_MARKERS)[
      match(xml2::xml_text(block), HIDDEN_EXAMPLE_MARKERS)
    ]
    out[[length(out) + 1L]] <- list(fn = fn, tag = tag)
  }
  out
}

#' Diagnose Interactive Examples Hidden in `\\dontrun{}` or `\\donttest{}`
#'
#' Flags an interactive call, such as a shiny app, a viewer or a prompt, that an
#' example hides in `\\dontrun{}` or `\\donttest{}` instead of guarding with
#' `if (interactive())`.
#'
#' In `\\dontrun{}`, CRAN asks for the guard instead, so a reader can see that the
#' function needs a session, not only that it does not run. In `\\donttest{}` the
#' call is a failure waiting to happen: `R CMD check --as-cran` runs that code,
#' where a prompt errors and an app waits for input until the check times out.
#'
#' The example is read as parsed R, so a function named in a comment or a string
#' is not a call, and only a guard that actually encloses the call excuses it,
#' including roxygen's `@examplesIf interactive()`. An app that `shinyApp()`
#' builds is reported only where it is printed, which is what runs it; kept in a
#' variable or handed to another function, it starts nothing.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples),
#' and the rejection reads "Functions which are supposed to only run interactively
#' (e.g. shiny) should be wrapped in if(interactive()). Please replace \\dontrun{}
#' with if(interactive()){} if possible". `R CMD check --as-cran` has run
#' `\\donttest{}` examples since R 4.0.0. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_example_structure()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/example_interactive_bad.Rd",
#'                                  show_content = FALSE)
#' lab_example_interactive(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_example_interactive <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  if (length(rd_files) == 0L) {
    return(pass_result(check_label("example_interactive")))
  }

  issues <- character(0)
  for (page in rd_examples(path, rd_files)) {
    file <- page$file
    examples <- page$examples
    xml <- rd_example_xml(examples)
    found <- if (!is.null(xml)) {
      hidden_interactive_calls(xml)
    } else {
      # The code outside the hidden blocks will not parse either, so no guard
      # around a block can be read. Read each block on its own.
      unlist(
        lapply(rd_hidden_blocks(examples), function(block) {
          block_xml <- parse_text_xml(rd_marked_code(block, repair = TRUE))
          if (is.null(block_xml)) list() else hidden_interactive_calls(block_xml)
        }),
        recursive = FALSE
      )
    }
    for (hit in found) {
      issues <- c(
        issues,
        if (identical(hit$tag, "\\dontrun")) {
          paste0(basename(file), ": ", hit$fn, "() is hidden in \\dontrun{}")
        } else {
          paste0(
            basename(file), ": ", hit$fn,
            "() in \\donttest{} runs under R CMD check --as-cran"
          )
        }
      )
    }
  }
  issues <- unique(issues)

  report_check(
    issues,
    verbose,
    check_label("example_interactive"),
    "Interactive examples use {.code if (interactive())}",
    "Interactive examples not guarded by {.code if (interactive())}",
    treatment = paste("Treatment:", treatments$example_interactive$treatment)
  )
}

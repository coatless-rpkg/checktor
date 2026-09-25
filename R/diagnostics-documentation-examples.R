# Documentation checks on the \examples{} sections of the help pages.

#' Diagnose Example Structure
#'
#' Walks `\examples{}` sections via [tools::parse_Rd()] and flags
#' `\dontrun{}` subtrees that don't appear to have a justifying reason
#' (interactive, network, credentials, long-running, etc.).
#'
#' @inheritParams lab_value_tags
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples).
#' `\dontrun{}` should wrap only code that genuinely cannot run inside a check, a
#' convention rather than a rule, which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/example_structure_bad.Rd",
#'                                  show_content = FALSE)
#' lab_example_structure(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_example_structure <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  if (length(rd_files) == 0L) {
    return(pass_result(check_label("example_structure")))
  }

  # What makes \dontrun{} legitimate is code that CANNOT run in a check: it needs
  # a network, credentials, a person at the keyboard, a database, a running app,
  # or more time than CRAN allows.
  #
  # The reactive-context markers matter as much as the rest. Some examples
  # define `server <- function(input, output, session)`, which is
  # meaningless outside a running Shiny app, but the word "shiny" never appears
  # in them -- so a literal search for it reported three correct \dontrun{} blocks
  # as unnecessary.
  justify_re <- paste(
    # needs a person
    "interactive",
    "readline",
    "menu\\(",
    "askYesNo",
    # needs credentials or a network
    "API",
    "password",
    "token",
    "key",
    "secret",
    "credentials?",
    "auth",
    "download\\.file",
    "httr2?::",
    "curl",
    "network",
    "http[s]?://",
    # needs a database
    "dbConnect",
    "DBI::",
    "RPostgres",
    "RSQLite",
    "dbWriteTable",
    # needs a running app / reactive context
    "shiny",
    "shinyApp",
    "runApp",
    "server\\s*<-\\s*function",
    "\\binput\\$",
    "\\boutput\\$",
    "\\bsession\\b",
    "observeEvent",
    "reactive",
    # needs more time than a check allows
    "long.running",
    "long.time",
    "Sys.sleep",
    # runs a system command
    "system2?\\(",
    # a placeholder path the example cannot actually open
    "path/to",
    "your[-_/ ]",
    sep = "|"
  )

  issues <- character(0)
  for (page in rd_examples(path, rd_files)) {
    file <- page$file
    examples <- page$examples
    if (!contains_dontrun(examples)) {
      next
    }
    text <- collect_rd_text(examples)
    if (!grepl(justify_re, text, ignore.case = TRUE, perl = TRUE)) {
      issues <- c(
        issues,
        paste0(basename(file), ": potential unnecessary \\dontrun{}")
      )
    }
  }

  report_check(
    issues,
    verbose,
    check_label("example_structure"),
    "Example structure appears appropriate",
    "Potential example structure issues",
    level = "warning"
  )
}

# Flags commented-out code lines inside \examples{}. A "commented-out call"
# is heuristically a line that starts with `#`, has no other code before it,
# and contains a `(` (the giveaway that it's a call rather than prose).
#' Diagnose Examples That Run Nothing
#'
#' Flags an `\examples{}` block whose only content is commented out, so it demonstrates nothing. A comment beside live code is illustration and is not flagged.
#'
#' @section Source:
#' No formal rule. An `\examples{}` block that is entirely commented out
#' demonstrates nothing, a convention which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/commented_examples_bad.Rd",
#'                                  show_content = FALSE)
#' lab_commented_examples(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_commented_examples <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  if (length(rd_files) == 0L) {
    return(pass_result(check_label("commented_examples")))
  }

  issues <- character(0)
  for (page in rd_examples(path, rd_files)) {
    file <- page$file
    examples <- page$examples
    text <- collect_rd_text(examples)
    lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]

    has_commented <- any(vapply(lines, is_commented_out_code, logical(1)))
    if (!has_commented) {
      next
    }

    # The defect is an example that DEMONSTRATES NOTHING because the code that
    # would run has been commented out. A comment sitting alongside live code is
    # a different thing entirely: some examples comment out server and .qmd
    # snippets that belong in the user's OWN files, then call a setup function
    # for real. That is illustration, not a disabled example,
    # and reporting it was reporting the documentation for doing its job.
    #
    # So: only flag when the block has no runnable code at all. \dontrun{} is
    # skipped, since its contents are not meant to run either.
    runnable <- parse_text_xml(
      collect_rd_text(examples, skip = c("\\dontrun", "\\donttest"))
    )
    if (
      !is.null(runnable) &&
        length(xml2::xml_find_all(runnable, "//expr")) > 0L
    ) {
      next
    }

    issues <- c(
      issues,
      paste0(
        basename(file),
        ": \\examples{} contains only commented-out code, so it runs nothing"
      )
    )
  }

  report_check(
    issues,
    verbose,
    check_label("commented_examples"),
    "Every {.code \\examples{{}}} block runs something",
    "{.code \\examples{{}}} blocks that run nothing",
    treatment = paste("Treatment:", treatments$commented_examples$treatment),
    level = "warning"
  )
}

# The signs that an example's \dontrun{} code is only slow: a Sys.sleep() or a
# comment calling it long-running.
SLOW_EXAMPLE_RE <- "Sys\\.sleep\\b|long.running|long.time"

# Whether the slow code in an example's \dontrun{} blocks uses a Suggested package
# without a guard, which it could not keep doing once moved to \donttest{}. Each
# block is judged on its own, so a block that needs a package does not hold back
# the advice for another block that is only slow. The slow blocks are those whose
# own code shows a sign of it; when the sign sits outside every block, such as a
# comment before one, any block may be the slow one.
dontrun_needs_suggests <- function(examples, suggests) {
  if (length(suggests) == 0L) {
    return(FALSE)
  }
  xml <- rd_example_xml(examples)
  if (is.null(xml)) {
    return(FALSE)
  }
  marker <- sprintf(
    "expr[1]/SYMBOL_FUNCTION_CALL[text() = '%s']",
    HIDDEN_EXAMPLE_MARKERS[["\\dontrun"]]
  )
  blocks <- xml2::xml_find_all(
    xml,
    sprintf("//expr[%s][not(ancestor::expr[%s])]", marker, marker)
  )
  slow <- grepl(
    SLOW_EXAMPLE_RE,
    xml2::xml_text(blocks),
    ignore.case = TRUE,
    perl = TRUE
  )
  if (any(slow)) {
    blocks <- blocks[slow]
  }
  length(blocks) > 0L && all(vapply(
    blocks,
    function(block) {
      inside <- function(use) {
        ancestors <- xml2::xml_find_all(use, "ancestor::expr")
        any(vapply(ancestors, identical, logical(1), block))
      }
      length(unguarded_suggests(xml, suggests, inside)) > 0L
    },
    logical(1)
  ))
}

# Suggest \donttest{} for code that is only slow, not impossible to run.
# Heuristic: an \examples block contains \dontrun{} AND the only "justifying"
# pattern is Sys.sleep() or a "long.running"/"long.time" comment - in that
# case \donttest{} would be the correct macro.
#' Diagnose dontrun Where donttest Belongs
#'
#' Flags `\dontrun{}` around code that is merely slow. `\donttest{}` is the right wrapper, since it still runs under `--run-donttest`.
#'
#' A slow block that uses a Suggested package without a guard is left alone:
#' `R CMD check --as-cran` runs `\donttest{}` code, so after the move
#' [lab_suggested_in_examples()] would report it. Each `\dontrun{}` block is
#' judged on its own, so such a block does not hold back the advice for another
#' that is only slow.
#'
#' @section Source:
#' The CRAN Cookbook covers the distinction under
#' [Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples),
#' where `\donttest{}` is the wrapper for an example that merely runs long. Nothing
#' enforces the choice, which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/donttest_vs_dontrun_bad.Rd",
#'                                  show_content = FALSE)
#' lab_donttest_vs_dontrun(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_donttest_vs_dontrun <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  if (length(rd_files) == 0L) {
    return(pass_result(check_label("donttest_vs_dontrun")))
  }
  suggests <- suggested_packages(path)

  issues <- character(0)
  for (page in rd_examples(path, rd_files)) {
    file <- page$file
    examples <- page$examples
    if (!contains_dontrun(examples)) {
      next
    }
    text <- collect_rd_text(examples)
    only_slow <- grepl(
      SLOW_EXAMPLE_RE,
      text,
      ignore.case = TRUE,
      perl = TRUE
    ) &&
      !grepl(
        "interactive|API|password|token|key|secret|credentials?|auth|download\\.file|httr2?::|curl",
        text,
        ignore.case = TRUE,
        perl = TRUE
      )
    # R CMD check --as-cran runs \donttest{}, so moving a block that needs a
    # Suggested package would trade this advice for a suggested_in_examples
    # finding.
    if (only_slow && !dontrun_needs_suggests(examples, suggests)) {
      issues <- c(
        issues,
        paste0(
          basename(file),
          ": uses \\dontrun{} for slow code; ",
          "prefer \\donttest{}"
        )
      )
    }
  }

  report_check(
    issues,
    verbose,
    check_label("donttest_vs_dontrun"),
    "{.code \\dontrun{{}}} use is appropriate",
    "Some {.code \\dontrun{{}}} blocks should be {.code \\donttest{{}}}",
    treatment = paste("Treatment:", treatments$donttest_vs_dontrun$treatment),
    level = "warning"
  )
}

#' Diagnose Exported Functions Missing Examples
#'
#' CRAN expects exported functions to carry a runnable `\examples{}` section.
#' Walks `.Rd` files via [tools::parse_Rd()] and reports exported function
#' topics that lack one. Data, class, methods, package-level, and re-export
#' topics are skipped, and only topics whose name appears in NAMESPACE
#' `export()` are considered (so internal helpers and S3 methods aren't
#' required to have examples). A function that exists only for its side effect
#' may be reported here even though it is fine, so use your judgement.
#'
#' @inheritParams lab_value_tags
#' @section Source:
#' The CRAN Cookbook covers examples under
#' [Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples).
#' Exported functions are expected to carry an `\examples{}` block, a convention
#' rather than a rule, which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @return [checktor_check_result()] with `passed`, `issues`, `missing`,
#'   `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/missing_examples_bad.Rd",
#'                                  show_content = FALSE)
#' writeLines("export(undocumented_fn)", file.path(pkg, "NAMESPACE"))
#' lab_missing_examples(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_missing_examples <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  if (length(rd_files) == 0L) {
    return(pass_result(check_label("missing_examples")))
  }

  ex <- package_exports(path)
  if (is.null(ex) || length(ex$names) == 0L) {
    # NAMESPACE missing or unparseable: we cannot tell what is exported, so we
    # must not enforce. Guessing here is how a check starts accusing a package's
    # flagship function of not existing.
    return(pass_result(check_label("missing_examples")))
  }

  missing <- character(0)
  for (file in rd_files) {
    rd <- read_rd_quietly(file)
    if (is.null(rd)) {
      next
    }
    if (is_non_function_rd_obj(rd)) {
      next
    }
    # \keyword{internal} pages are deprecated shims and other non-API topics that
    # are deliberately hidden from the index. R's own checkRdContents exempts them
    # from its Rd-content checks on the strength of the keyword alone, so requiring
    # a runnable example of them is not a rule anyone enforces.
    if (rd_is_internal(rd)) {
      next
    }
    names <- c(rd_primary_name(rd), rd_aliases(rd))
    names <- names[!is.na(names) & nzchar(names)]
    # Only exported function topics. exportPattern() means a name can be exported
    # without ever being listed, so ask name_is_exported() rather than %in%.
    if (!any(vapply(names, name_is_exported, logical(1), ex = ex))) {
      next
    }
    if (is.null(extract_rd_section(rd, "\\examples"))) {
      missing <- c(missing, basename(file))
    }
  }

  report_check(
    missing,
    verbose,
    check_label("missing_examples"),
    "Exported functions include {.code \\examples}",
    "Exported functions missing {.code \\examples}",
    treatment = paste("Treatment:", treatments$missing_examples$treatment),
    level = "warning",
    missing = missing
  )
}

#' Diagnose Suggested Packages Used in Examples Without a Guard
#'
#' Under CRAN's `noSuggests` check a package must work without its Suggested
#' packages installed. This flags an example that needs a Suggested package, through
#' `pkg::`, `library()` or `require()`, in code that runs without a guard naming
#' that package: an enclosing `if (requireNamespace("pkg", quietly = TRUE))` or
#' `if (require("pkg"))`, including roxygen's `@examplesIf` with one of them.
#' `rlang::is_installed("pkg")` counts too, but it needs rlang, so it is a use of
#' rlang when rlang is only suggested.
#'
#' The example is read as parsed R, so a package named in a comment or a string is
#' not a use, and a guard in a comment, a guard for another package, or one that
#' does not enclose the use excuses nothing. Usage inside `\dontrun{}` is not
#' flagged, since it never runs. Usage inside `\donttest{}` is, since
#' `R CMD check --as-cran` runs it. A condition that is false under R CMD check
#' keeps the use out of the check as surely as `\dontrun{}` does, so
#' `interactive()`, `identical(Sys.getenv("IN_PKGDOWN"), "true")`,
#' `nzchar(Sys.getenv("IN_PKGDOWN"))` and a test that `NOT_CRAN` is `"true"` excuse
#' it too. A bare `as.logical(Sys.getenv("NOT_CRAN"))` does not: it is `NA` there,
#' and `if (NA)` stops the example with an error. R's base packages, such as
#' parallel and tools, and its recommended packages, such as MASS, Matrix and
#' survival, ship with R and are never flagged.
#'
#' @inheritParams lab_value_tags
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Suggested-packages),
#' under "Suggested packages", asks that a package from `Suggests` used in
#' an example be guarded so the example still runs without it. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/suggested_in_examples_bad.Rd",
#'                                  show_content = FALSE)
#' cat("Suggests: somesuggest\n",
#'     file = file.path(pkg, "DESCRIPTION"), append = TRUE)
#' lab_suggested_in_examples(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_suggested_in_examples <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  suggests <- suggested_packages(path)
  if (length(rd_files) == 0L || length(suggests) == 0L) {
    return(pass_result(check_label("suggested_in_examples")))
  }

  # The example text used to be grepped, so a package named in a comment was a use,
  # `library(dplyrExtra)` was a use of dplyr, a guard written anywhere in the file,
  # even in a comment, excused every use, and the word examplesIf excused them all
  # whatever the @examplesIf asked. Read the parse tree and judge each use by the
  # guards that enclose it.
  #
  # The rule serves CRAN's noSuggests check, which is R CMD check, so a use
  # behind a condition that is false there, such as `interactive()`, is never
  # reached by it and is excused like one behind requireNamespace().
  issues <- character(0)
  for (page in rd_examples(path, rd_files)) {
    file <- page$file
    examples <- page$examples
    xml <- rd_example_xml(examples)
    if (is.null(xml)) {
      next
    }
    missing <- unguarded_suggests(
      xml,
      suggests,
      function(use) !in_hidden_block(use, "\\dontrun")
    )
    if (length(missing) > 0L) {
      # One report per file is enough.
      issues <- c(
        issues,
        paste0(
          basename(file),
          ": uses Suggested package '",
          missing[[1L]],
          "' in \\examples without a guard"
        )
      )
    }
  }

  report_check(
    issues,
    verbose,
    check_label("suggested_in_examples"),
    "Examples guard Suggested-package usage",
    "Examples use Suggested packages without a guard",
    treatment = paste("Treatment:", treatments$suggested_in_examples$treatment),
    level = "warning"
  )
}

#' Diagnose Bare Calls to Unexported Functions in Examples
#'
#' Flags an `\examples{}` block that calls its own topic bare when that topic is
#' not exported. Examples run with only the package's exports attached, so the
#' call fails.
#'
#' `R CMD check` does catch this, but only by RUNNING the examples, which is late
#' and slow, and it is skipped entirely when examples are wrapped in `\dontrun{}`
#' or when you check with `--no-examples`. This finds it statically in a second.
#'
#' @section Source:
#' No formal rule. An example that reaches for an unexported object will
#' error when it runs, which is why this sits at `robustness` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/unexported_example_ns_bad.Rd",
#'                                  show_content = FALSE)
#' # The package exports something, but not internal_values()
#' writeLines("export(public_values)", file.path(pkg, "NAMESPACE"))
#' lab_unexported_example_ns(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_unexported_example_ns <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  if (length(rd_files) == 0L) {
    return(pass_result(check_label("unexported_example_ns")))
  }

  ex <- package_exports(path)
  if (is.null(ex) || length(ex$names) == 0L) {
    return(pass_result(check_label("unexported_example_ns")))
  }

  issues <- character(0)
  for (page in rd_examples(path, rd_files)) {
    file <- page$file
    names <- c(rd_primary_name(page$rd), rd_aliases(page$rd))
    names <- names[!is.na(names) & nzchar(names)]
    if (length(names) == 0L) {
      next
    }
    if (any(vapply(names, name_is_exported, logical(1), ex = ex))) {
      next
    }
    examples <- page$examples
    # \dontrun{} is not executed, so a bare call in there cannot fail. R CMD check
    # would not run it either.
    text <- collect_rd_text(examples, skip = "\\dontrun")

    # Parse the example code rather than grepping it. A comment reading
    # `# call helper(1) yourself`, or the string "helper(", is not a call, and
    # only the parse tree knows that. `pkg:::helper()` still produces a
    # SYMBOL_FUNCTION_CALL, so the `:::` is detected as a preceding NS_GET_INT
    # sibling rather than by looking for a colon in the text.
    xml <- parse_text_xml(text)
    if (is.null(xml)) {
      next
    } # example does not parse; not our check to report

    for (nm in names) {
      bare <- xml2::xml_find_all(
        xml,
        sprintf(
          "//SYMBOL_FUNCTION_CALL[text() = '%s' and not(preceding-sibling::NS_GET) and not(preceding-sibling::NS_GET_INT)]",
          nm
        )
      )
      if (length(bare) > 0L) {
        issues <- c(
          issues,
          paste0(
            basename(file),
            ": example calls unexported '",
            nm,
            "()', so it fails when the example runs"
          )
        )
        break
      }
    }
  }

  report_check(
    issues,
    verbose,
    check_label("unexported_example_ns"),
    "Every documented example calls an object it can reach",
    "An example calls an object the package does not export",
    treatment = paste("Treatment:", treatments$unexported_example_ns$treatment),
    level = "warning"
  )
}

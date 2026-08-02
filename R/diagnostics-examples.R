# Checks over the code CRAN reads outside R/: examples, vignettes and demos.
#
# Each rule here comes from a rejection letter rather than from a guess, and the
# CRAN Cookbook records every one of them.

#' Diagnose Installs in Examples, Vignettes and Demos
#'
#' Flags a call that installs a package or external software from an example, a
#' vignette or a demo. CRAN asks maintainers not to install anything from these,
#' because a check then has to do the install too, and the user did not ask for it.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Installing Software](https://contributor.r-project.org/cran-cookbook/code_issues.html#installing-software),
#' and it is a rejection maintainers receive verbatim: "Please do not install
#' packages in your functions, examples or vignette." See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_software_install()] for the same rule in `R/`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_example_installs(pkg, verbose = FALSE)$passed
lab_example_installs <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette", "demo"))
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Example installs check"))
  }

  installers <- c(
    "install.packages",
    "install_github",
    "install_gitlab",
    "install_bitbucket",
    "install_version",
    "install_local",
    "install_deps",
    "pak",
    "pkg_install",
    "biocLite"
  )
  predicate <- paste(
    sprintf("text() = '%s'", installers),
    collapse = " or "
  )
  issues <- example_lints(
    parsed,
    sprintf("//SYMBOL_FUNCTION_CALL[%s]", predicate),
    label = "installs software"
  )

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No installs in examples, vignettes or demos",
    "Installs found in examples, vignettes or demos",
    "Treatment: Assume the package is already available, or guard the example with {.code if (requireNamespace(...))}"
  )
  checktor_check_result(passed, issues, "Example installs check")
}

#' Diagnose Writes Outside the Temporary Directory in Examples
#'
#' Flags a write from an example, vignette or demo whose destination is a literal
#' path, so it lands in the user's filespace rather than in `tempdir()`. A
#' destination the caller supplies is permission and is not flagged.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Writing Files and Directories to the Home Filespace](https://contributor.r-project.org/cran-cookbook/code_issues.html#writing-files-and-directories-to-the-home-filespace),
#' and the rejection reads "Please ensure that your functions do not write by
#' default or in your examples/vignettes/tests in the user's home filespace". See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_file_operations()] for the same rule in `R/`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_example_writes(pkg, verbose = FALSE)$passed
lab_example_writes <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette", "demo"))
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Example writes check"))
  }

  predicate <- paste(
    sprintf("text() = '%s'", WRITE_FUNCTIONS),
    collapse = " or "
  )
  xpath <- sprintf("//SYMBOL_FUNCTION_CALL[%s]", predicate)

  # The same destination logic the R/ check uses, so a write is judged the same way
  # wherever it appears. Only a literal root can be proven to land in the user's
  # filespace, and anything built from tempfile() or tempdir() is the safe place.
  issues <- character(0)
  for (src in parsed) {
    nodes <- tryCatch(
      xml2::xml_find_all(src$xml, xpath),
      error = function(e) NULL
    )
    if (is.null(nodes) || length(nodes) == 0L) {
      next
    }
    keep <- vapply(
      nodes,
      function(n) dest_is_unsafe_literal(write_destination(n)),
      logical(1)
    )
    nodes <- nodes[keep]
    if (length(nodes) == 0L) {
      next
    }
    issues <- c(
      issues,
      paste0(
        src$kind,
        " ",
        basename(src$file),
        ":",
        xml2::xml_attr(nodes, "line1"),
        " (",
        xml2::xml_text(nodes),
        "())"
      )
    )
  }
  issues <- unique(issues)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Examples write only to {.code tempdir()} or a caller-supplied path",
    "Examples write to a literal path outside {.code tempdir()}",
    "Treatment: Write to {.code tempfile()} or {.code tempdir()} in an example"
  )
  checktor_check_result(passed, issues, "Example writes check")
}

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
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_example_state(pkg, verbose = FALSE)$passed
lab_example_state <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette", "demo"))
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Example state check"))
  }

  issues <- character(0)
  for (src in parsed) {
    # A named argument is what makes options() or par() a write rather than a read.
    setters <- xml2::xml_find_all(
      src$xml,
      paste0(
        "//SYMBOL_FUNCTION_CALL[text() = 'options' or text() = 'par']",
        "/parent::expr/parent::expr[SYMBOL_SUB]",
        " | //SYMBOL_FUNCTION_CALL[text() = 'setwd']/parent::expr/parent::expr"
      )
    )
    if (length(setters) == 0L) {
      next
    }
    # A restore anywhere in the same file is enough: the old value is captured and
    # handed back, which is what the reviewer asks for.
    restored <- length(xml2::xml_find_all(
      src$xml,
      paste0(
        "//expr[LEFT_ASSIGN or EQ_ASSIGN]",
        "[.//SYMBOL_FUNCTION_CALL[",
        "  text() = 'options' or text() = 'par' or text() = 'getwd'",
        "]]"
      )
    )) > 0L
    if (restored) {
      next
    }
    lines <- xml2::xml_attr(setters, "line1")
    issues <- c(
      issues,
      paste0(src$kind, " ", basename(src$file), ":", lines, " (never restored)")
    )
  }
  issues <- unique(issues)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Examples restore any session state they change",
    "Examples change session state without restoring it",
    "Treatment: Capture and restore, as in {.code old <- options(digits = 3)} then {.code options(old)}"
  )
  checktor_check_result(passed, issues, "Example state check")
}

#' Diagnose Interactive Examples Wrapped in `\\dontrun{}`
#'
#' Flags an `\\examples{}` block that hides an interactive function behind
#' `\\dontrun{}`. CRAN asks for `if (interactive())` instead, so a reader can see
#' the function is not meant for a script rather than only that it does not run.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples),
#' and the rejection reads "Functions which are supposed to only run interactively
#' (e.g. shiny) should be wrapped in if(interactive()). Please replace \\dontrun{}
#' with if(interactive()){} if possible". See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_example_structure()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_example_interactive(pkg, verbose = FALSE)$passed
lab_example_interactive <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
  if (length(rd_files) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Interactive example check"
    ))
  }

  # Names that mean a person has to be at the keyboard. A shiny app, a launcher,
  # a viewer or a prompt all belong behind if (interactive()).
  interactive_re <- paste(
    "runApp",
    "shinyApp",
    "run_app",
    "runGadget",
    "runExample",
    "launch",
    "browseURL",
    "browseVignettes",
    "View\\(",
    "readline",
    "menu\\(",
    "askYesNo",
    "file\\.choose",
    "electron",
    sep = "|"
  )

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) {
      next
    }
    hidden <- collect_rd_text_within(examples, c("\\dontrun", "\\donttest"))
    if (!nzchar(trimws(hidden))) {
      next
    }
    if (!grepl(interactive_re, hidden, perl = TRUE)) {
      next
    }
    # The guard has to be inside the hidden block to excuse it. Read against the
    # whole examples section, an unrelated `if (interactive())` sitting outside
    # \dontrun{} would excuse the very call the check exists to report.
    if (grepl("interactive\\s*\\(", hidden, perl = TRUE)) {
      next
    }
    issues <- c(
      issues,
      paste0(basename(file), ": interactive example hidden in \\dontrun{}")
    )
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Interactive examples use {.code if (interactive())}",
    "Interactive examples hidden in {.code \\dontrun{}}",
    "Treatment: Replace {.code \\dontrun{}} with {.code if (interactive()) { ... }} so a reader sees the function needs a session"
  )
  checktor_check_result(passed, issues, "Interactive example check")
}

#' Diagnose `:::` in Examples
#'
#' Flags a `pkg:::fn()` call in an example. The triple colon reaches an unexported
#' object, whose behaviour the author is free to change, so CRAN asks for one colon
#' or for the object to be exported.
#'
#' @section Source:
#' CRAN sends this back verbatim as "Using foo:::f instead of foo::f allows access
#' to unexported objects ... Please omit one colon", listing the `.Rd` files it
#' appears in. See `vignette("check-sources", package = "checktor")` for how every
#' check maps to its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_unexported_example_ns()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_example_internal_ns(pkg, verbose = FALSE)$passed
lab_example_internal_ns <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette"))
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Example ::: check"))
  }

  issues <- example_lints(parsed, "//NS_GET_INT", label = "uses :::")

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No {.code :::} in examples or vignettes",
    "{.code :::} used in examples or vignettes",
    "Treatment: Use {.code ::} on an exported object, or export the object the example needs"
  )
  checktor_check_result(passed, issues, "Example ::: check")
}

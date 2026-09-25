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
#' pkg <- example_diagnose_scenario("documentation_examples/example_installs_bad.Rd",
#'                                  show_content = FALSE)
#' lab_example_installs(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_example_installs <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette", "demo"))
  if (length(parsed) == 0L) {
    return(pass_result(check_label("example_installs")))
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

  report_check(
    issues,
    verbose,
    check_label("example_installs"),
    "No installs in examples, vignettes or demos",
    "Installs found in examples, vignettes or demos",
    treatment = paste("Treatment:", treatments$example_installs$treatment)
  )
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
#' pkg <- example_diagnose_scenario("documentation_examples/example_writes_bad.Rd",
#'                                  show_content = FALSE)
#' lab_example_writes(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_example_writes <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette", "demo"))
  if (length(parsed) == 0L) {
    return(pass_result(check_label("example_writes")))
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

  report_check(
    issues,
    verbose,
    check_label("example_writes"),
    "Examples write only to {.code tempdir()} or a caller-supplied path",
    "Examples write to a literal path outside {.code tempdir()}",
    treatment = paste("Treatment:", treatments$example_writes$treatment)
  )
}

#' Diagnose Examples That Are Not Valid R
#'
#' Flags an `\examples{}` section whose code does not parse as R, reporting the
#' `.Rd` file and the line the parser stopped on. The code inside `\dontrun{}` is
#' read too. `R CMD check` writes it out as comments and never parses it, so a
#' missing bracket or a `<your key>` placeholder there passes every check.
#'
#' @section Source:
#' A rejection CRAN reviewers send verbatim: "Warning: Unexecutable code in
#' man/make.trait.model.Rd". [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Documenting-functions),
#' under "Documenting functions", says example code outside `\dontrun{}` "must be
#' executable", and that the text inside it "need not be valid R code". Reviewers
#' run the examples with `\dontrun{}` included all the same, so a placeholder
#' belongs in a string or a variable, as in `key <- "<your key>"`. An example that
#' is deliberately not R, such as C++ source shown for reading, can be turned off
#' with `Config/checktor/disable`. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_example_structure()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/example_unparseable_bad.Rd",
#'                                  show_content = FALSE)
#' lab_example_unparseable(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_example_unparseable <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  issues <- character(0)
  for (page in rd_examples(path)) {
    file <- page$file
    section <- page$examples
    src <- rd_example_source(section)
    err <- tryCatch(
      {
        parse(text = src$code, keep.source = FALSE)
        NULL
      },
      error = conditionMessage
    )
    if (is.null(err)) {
      next
    }
    issues <- c(issues, unparseable_issue(err, src, basename(file)))
  }

  report_check(
    issues,
    verbose,
    check_label("example_unparseable"),
    "Every example parses as R",
    "Examples that do not parse as R, {.code \\dontrun{{}}} included",
    treatment = paste("Treatment:", treatments$example_unparseable$treatment)
  )
}

# "example f.Rd:12 (unexpected symbol)" from a parse error in code that
# rd_example_source() gave. The parser gives `<text>:line:col: message` and then
# the offending lines; the position is on the code's lines, which `src$lines`
# maps to the .Rd file's. An unfinished example ends past its last line of
# code, so the line is held to the last one with code on it.
unparseable_issue <- function(err, src, file) {
  first <- strsplit(err, "\n", fixed = TRUE)[[1L]][[1L]]
  at <- suppressWarnings(
    as.integer(sub("^<text>:([0-9]+):[0-9]+: .*$", "\\1", first))
  )
  what <- sub("^<text>:[0-9]+:[0-9]+: ", "", first)
  if (is.na(at)) {
    return(paste0("example ", file, " (", what, ")"))
  }
  code <- strsplit(src$code, "\n", fixed = TRUE)[[1L]]
  last <- max(c(1L, which(nzchar(trimws(code)))))
  line <- src$lines[min(at, last, length(src$lines))]
  paste0("example ", file, ":", line, " (", what, ")")
}

#' Diagnose `T`/`F` Usage in Examples, Vignettes and Demos
#'
#' Flags a bare `T` or `F` in an example, a vignette chunk that runs, or a demo,
#' judged exactly as [lab_tf_usage()] judges `R/`: a `T` in a string, a comment,
#' an argument name, `x$T` or language built by `quote()` is not reported.
#'
#' @section Source:
#' The CRAN Cookbook recipe
#' [T/F Instead of TRUE/FALSE](https://contributor.r-project.org/cran-cookbook/code_issues.html#tf-instead-of-truefalse)
#' says `T` and `F` "should not be used as variable names in your code, examples,
#' tests or vignettes", and the reviewer's letter names the `.Rd` file: "'T' and
#' 'F' instead of TRUE and FALSE: man/quiet.Rd: quiet(x, be_quiet = T)". No rule
#' makes it binding, so it sits at `robustness` tier like [lab_tf_usage()]. Tests
#' are left out unless `tests = TRUE`, since CRAN rarely reads them. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param tests Logical. Read `tests/` as well. Default: `FALSE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_tf_usage()] for the same rule in `R/`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/example_tf_usage_bad.Rd",
#'                                  show_content = FALSE)
#' lab_example_tf_usage(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_example_tf_usage <- function(path = ".", verbose = TRUE, tests = FALSE) {
  path <- find_package_root(path)
  kinds <- c("example", "vignette", "demo", if (isTRUE(tests)) "test")
  parsed <- read_example_xml(path, kinds = kinds)
  issues <- example_lints(parsed, TF_XPATH)

  report_check(
    issues,
    verbose,
    check_label("example_tf_usage"),
    "No {.code T}/{.code F} usage in examples, vignettes or demos",
    "Found {.code T}/{.code F} usage in examples, vignettes or demos",
    treatment = paste("Treatment:", treatments$example_tf_usage$treatment)
  )
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
#' pkg <- example_diagnose_scenario("documentation_examples/example_internal_ns_bad.Rd",
#'                                  show_content = FALSE)
#' lab_example_internal_ns(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_example_internal_ns <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette"))
  if (length(parsed) == 0L) {
    return(pass_result(check_label("example_internal_ns")))
  }

  issues <- example_lints(parsed, "//NS_GET_INT", label = "uses :::")

  report_check(
    issues,
    verbose,
    check_label("example_internal_ns"),
    "No {.code :::} in examples or vignettes",
    "{.code :::} used in examples or vignettes",
    treatment = paste("Treatment:", treatments$example_internal_ns$treatment)
  )
}

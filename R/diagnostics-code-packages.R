# Code checks for installing, loading and querying packages from package code.

#' Diagnose installed.packages() Usage
#'
#' Flags `installed.packages()`, which is slow and is discouraged by its own help page.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' does not let a package install other packages when it runs. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/installed_packages_bad.R",
#'                                  show_content = FALSE)
#' lab_installed_packages(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_installed_packages <- function(
  path,
  verbose = TRUE,
  parsed = NULL
) {
  path <- find_package_root(path)
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

#' Diagnose Package Installation From Package Code
#'
#' Flags `install.packages()` and friends. A package may not install software on the user's machine.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' does not let a package download and install external software when it loads
#' or runs. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/software_install_bad.R",
#'                                  show_content = FALSE)
#' lab_software_install(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_software_install <- function(
  path,
  verbose = TRUE,
  parsed = NULL
) {
  path <- find_package_root(path)
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
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Package-Dependencies),
#' under "Package Dependencies", asks package code to reach its dependencies
#' through `Imports` and `::` rather than attaching them with `library()`. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/library_in_pkg_bad.R",
#'                                  show_content = FALSE)
#' lab_library_in_pkg(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_library_in_pkg <- function(path, verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
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
       %s
       and not(ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[%s]])
     ]",
    NOT_MEMBER_ACCESS, # `api$library(...)` is a method, not base::library
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

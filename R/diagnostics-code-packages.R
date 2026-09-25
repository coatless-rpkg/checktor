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
  path = ".",
  verbose = TRUE,
  parsed = NULL
) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("installed_packages")))
  }
  report_check(
    undesirable_function_check(parsed, "installed.packages", label = FALSE),
    verbose,
    check_label("installed_packages"),
    "No {.code installed.packages()} usage found",
    "{.code installed.packages()} usage found",
    paste("Treatment:", treatments$installed_packages$treatment)
  )
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
  path = ".",
  verbose = TRUE,
  parsed = NULL
) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("software_install")))
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
    PROMPT_CALLS,
    "is_interactive",
    "interactive",
    "check_installed"
  ))
  report_check(
    xpath_per_file(parsed, xp_call(direct_funs, consented), fn_hits),
    verbose,
    check_label("software_install"),
    "No software installation in functions detected",
    "Potential software installation in functions",
    paste("Treatment:", treatments$software_install$treatment),
    max_show = 3L
  )
}

# The calls that ask the user a question and wait for the answer. A function that
# makes one is interactive by definition: its install is one the user agreed to,
# and the output it prints to set up the question is part of the question.
PROMPT_CALLS <- c("menu", "askYesNo", "yesno", "readline", "select.list")

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
lab_library_in_pkg <- function(path = ".", verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("library_in_pkg")))
  }
  # xp_call() leaves out `api$library(...)`, a method rather than base::library.
  xpath <- xp_call(
    c("library", "require"),
    sprintf(
      "not(ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[%s]])",
      xp_text_in(REMOTE_EVAL_FUNS)
    )
  )
  report_check(
    xpath_per_file(parsed, xpath, fn_hits),
    verbose,
    check_label("library_in_pkg"),
    "No {.code library()}/{.code require()} calls in package code",
    "{.code library()}/{.code require()} calls in package code",
    paste("Treatment:", treatments$library_in_pkg$treatment)
  )
}

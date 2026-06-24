#' Quick Health Check
#'
#' Runs [checktor()] with minimal output, suitable for CI/CD pipelines.
#'
#' @param path Character. Path to the R package directory. Default: `"."`.
#'
#' @return
#' Logical. `TRUE` if no issues were found, `FALSE` otherwise.
#'
#' @export
#' @examples
#' # A clean synthetic package passes; a known-bad one does not
#' pkg_bad <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                      show_content = FALSE)
#' checkup(pkg_bad)
checkup <- function(path = ".") {
  results <- checktor(path, verbose = FALSE, progress = FALSE)
  results$metadata$total_issues == 0L
}

#' Configure Package Doctor Defaults
#'
#' Sets session-wide defaults for [checktor()] behavior. Subsequent calls to
#' `checktor()` (and helpers that delegate to it) pick up these defaults via
#' `getOption()`.
#'
#' @param verbose_default Logical. Default verbosity for `checktor()`.
#' @param progress_default Logical. Default progress-bar setting.
#' @param color Logical. Whether `cli` should emit ANSI color. Sets
#'   `cli.num_colors` via `options()`.
#'
#' @return
#' Invisibly returns the previous values of the changed options, so the call
#' can be reversed with `options(.)`.
#'
#' @export
#' @examples
#' # Save defaults so we can restore them after the example runs
#' old <- options(checktor.verbose = NULL, checktor.progress = NULL)
#' on.exit(options(old), add = TRUE)
#'
#' configure_doctor(verbose_default = FALSE)
#' getOption("checktor.verbose")
configure_doctor <- function(verbose_default = TRUE,
                             progress_default = TRUE,
                             color = TRUE) {
  old <- options(
    checktor.verbose  = verbose_default,
    checktor.progress = progress_default,
    cli.num_colors    = if (isTRUE(color)) NULL else 1L
  )

  cli::cli_alert_success("Package doctor configuration updated")
  invisible(old)
}

# ---- internal helpers --------------------------------------------------------

safe_read_lines <- function(file) {
  if (!file.exists(file)) {
    return(character(0))
  }
  tryCatch(readLines(file, warn = FALSE), error = function(e) character(0))
}

# Lists R source files under <path>/R/. Returns character(0) if R/ is absent.
list_r_files <- function(path) {
  r_dir <- file.path(path, "R")
  if (!dir.exists(r_dir)) return(character(0))
  list.files(r_dir, pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
}

# Reads .Rbuildignore patterns and returns a function(rel_path) -> logical
# that's TRUE when the path matches any ignore pattern. The always-skip set
# (.git, .Rproj.user, .DS_Store, etc.) is applied unconditionally.
build_ignore_matcher <- function(path) {
  always_skip <- c("^\\.git(/|$)", "^\\.Rproj\\.user(/|$)",
                   "^\\.Rhistory$", "^\\.RData$", "^\\.DS_Store$")

  rbi <- file.path(path, ".Rbuildignore")
  patterns <- if (file.exists(rbi)) {
    lns <- safe_read_lines(rbi)
    lns <- lns[nzchar(lns)]
    lns[!grepl("^\\s*#", lns)]
  } else {
    character(0)
  }
  patterns <- c(patterns, always_skip)

  function(rel_path) {
    keep <- logical(length(rel_path))
    for (pat in patterns) {
      keep <- keep | grepl(pat, rel_path, perl = TRUE)
    }
    keep
  }
}

# Schedule `unlink(path, recursive = TRUE)` on the caller's exit. Used by
# scenario builders that hand out temp paths the caller still needs to use.
defer_cleanup <- function(path, envir = parent.frame()) {
  do.call(
    base::on.exit,
    list(substitute(
      if (dir.exists(p)) unlink(p, recursive = TRUE),
      list(p = path)
    ), add = TRUE),
    envir = envir
  )
  invisible(path)
}

# Build the named $passed logical vector from a list of checktor_check_result
# objects (one per sub-diagnostic). Tolerates entries that are themselves
# raw logicals (e.g., the no-R-files shortcut).
summarise_passed <- function(results) {
  vapply(
    results,
    function(x) if (is.logical(x)) x[[1L]] else isTRUE(x$passed),
    logical(1)
  )
}

# Runs a list of sub-diagnostics under a tryCatch wrapper. Each entry of
# `checks` is a (name -> function(path, verbose)) pair. Any error becomes a
# failing checktor_check_result with the error message as its single issue,
# so errors surface in reports rather than being silently swallowed.
run_checks <- function(checks, path, verbose) {
  results <- list()
  for (nm in names(checks)) {
    results[[nm]] <- tryCatch(
      checks[[nm]](path, verbose),
      error = function(e) {
        if (verbose) {
          cli::cli_alert_danger("Error in {nm} diagnostic: {e$message}")
        }
        checktor_check_result(
          FALSE,
          paste0("Diagnostic errored: ", conditionMessage(e)),
          paste0(nm, " (errored)")
        )
      }
    )
  }
  results$passed <- summarise_passed(results[names(checks)])
  results
}

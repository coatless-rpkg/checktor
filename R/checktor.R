#' Diagnose Package for CRAN Submission Issues
#'
#' Runs a comprehensive diagnostic suite for common CRAN submission issues that
#' are not caught by standard R CMD check. Like a doctor for your package, this
#' function examines your code, DESCRIPTION file, documentation, general
#' package structure, and CRAN policy compliance to identify potential problems
#' that could cause CRAN submission delays or rejections.
#'
#' @param path Character. Path to the R package directory. Defaults to current
#'   directory (`"."`).
#' @param verbose Logical. Whether to print detailed diagnostic output to
#'   console. Defaults to `getOption("checktor.verbose", TRUE)`.
#' @param progress Logical. Whether to show progress bars during diagnostics.
#'   Defaults to `getOption("checktor.progress", verbose)`.
#'
#' @return
#' A `checktor_results` object (list) containing:
#'
#' - `code_issues`: Results from code diagnostics
#' - `description_issues`: Results from DESCRIPTION file diagnostics
#' - `documentation_issues`: Results from documentation diagnostics
#' - `general_issues`: Results from general package diagnostics
#' - `policy_issues`: Results from CRAN policy violation diagnostics
#' - `metadata`: List with package path, diagnosis time, total issue count,
#'   total failed-check count, and checktor version
#'
#' Each diagnostic category contains a `passed` element showing which individual
#' checks passed/failed, plus detailed results for each check.
#'
#' @details
#' The function runs five categories of diagnostics: **Code**, **DESCRIPTION**,
#' **Documentation**, **General**, and **Policy**. See [diagnose_code_issues()],
#' [diagnose_description_issues()], [diagnose_documentation_issues()],
#' [diagnose_general_issues()], and [diagnose_policy_violations()] for the
#' specific checks within each category.
#'
#' The `metadata$total_issues` figure counts the total number of distinct
#' issues found across all checks (e.g., 80 lines using `T`/`F` count as 80,
#' not 1). The `metadata$failed_checks` figure counts how many individual
#' checks reported any issue at all.
#'
#' @seealso
#' [health_report()] to generate detailed reports, [prescribe()] for treatment
#' recommendations, [checkup()] for quick health checks
#'
#' @export
#' @examples
#' # Run against a synthetic package with known T/F issues
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#'
#' # Inspect the metadata
#' results$metadata$total_issues
#' results$metadata$failed_checks
#'
#' # Check whether a specific diagnostic passed
#' results$code_issues$tf_usage$passed
checktor <- function(path = ".",
                     verbose = getOption("checktor.verbose", TRUE),
                     progress = getOption("checktor.progress", verbose)) {
  validate_package_directory(path)

  if (verbose) {
    cli::cli_rule(left = "Package Doctor - Diagnostic Report",
                  right = paste0("v", utils::packageVersion("checktor")))
    cli::cli_text("Examining package at: {.path {path}}")
    cli::cli_text()
  }

  categories <- list(
    code_issues          = diagnose_code_issues,
    description_issues   = diagnose_description_issues,
    documentation_issues = diagnose_documentation_issues,
    general_issues       = diagnose_general_issues,
    policy_issues        = diagnose_policy_violations
  )

  if (progress && verbose) {
    cli::cli_progress_bar("Running diagnostics",
                          total = length(categories), type = "tasks")
  }

  results <- list()
  for (cat_name in names(categories)) {
    if (progress && verbose) cli::cli_progress_update()
    results[[cat_name]] <- categories[[cat_name]](path, verbose)
  }
  if (progress && verbose) cli::cli_progress_done()

  counts <- count_results(results)
  total_issues  <- counts$issues
  failed_checks <- counts$failed_checks

  if (verbose) {
    cli::cli_text()
    cli::cli_rule(left = "Diagnosis Summary")
    if (total_issues == 0L) {
      cli::cli_alert_success("Clean bill of health! No CRAN submission issues found.")
      cli::cli_text("{.emph Your package appears ready for CRAN submission.}")
    } else {
      cli::cli_alert_danger(
        "Found {total_issues} issue{?s} across {failed_checks} failed check{?s}"
      )
      cli::cli_text("Review the detailed diagnosis above for specific remedies.")
      cli::cli_text()
      cli::cli_text("Use {.code prescribe()} to get treatment recommendations.")
    }

    cli::cli_text()
    cli::cli_h3("Recommended Next Steps")
    if (total_issues > 0L) {
      cli::cli_ol(c(
        "Apply the treatments suggested above",
        "Run {.code devtools::check()} for standard R CMD check",
        "Re-run {.code checktor()} to verify treatments",
        "Submit to CRAN when diagnosis is clean"
      ))
    } else {
      cli::cli_ol(c(
        "Run {.code devtools::check()} for standard R CMD check",
        "Review any additional CRAN submission requirements",
        "Submit to CRAN with confidence!"
      ))
    }
  }

  results$metadata <- list(
    package_path     = path,
    diagnosis_time   = Sys.time(),
    total_issues     = total_issues,
    failed_checks    = failed_checks,
    checktor_version = utils::packageVersion("checktor")
  )

  class(results) <- "checktor_results"
  invisible(results)
}

# Single walk over a checktor_results-shaped list. Returns a list with:
#   $issues        - total individual issues (e.g., 80 T/F hits -> 80)
#   $failed_checks - number of sub-checks where any issue was found
# A check that errored (no $issues, only $error) counts as one issue so it
# surfaces in reports instead of being silently dropped.
count_results <- function(results) {
  issues <- 0L
  failed <- 0L
  for (cat in results) {
    if (!is.list(cat)) next
    if (!is.null(cat$passed)) {
      failed <- failed + sum(!cat$passed, na.rm = TRUE)
    }
    for (nm in setdiff(names(cat), "passed")) {
      check <- cat[[nm]]
      if (!is.list(check)) next
      if (!is.null(check$issues)) {
        issues <- issues + length(check$issues)
      } else if (isFALSE(check$passed)) {
        issues <- issues + 1L
      }
    }
  }
  list(issues = issues, failed_checks = failed)
}

#' Print Method for checktor_results Objects
#'
#' Provides a clean, formatted summary of diagnostic results from [checktor()].
#'
#' @param x A `checktor_results` object from [checktor()]
#' @param ... Additional arguments passed to print methods (currently unused)
#'
#' @return Returns `x` invisibly. Called primarily for its side effect of
#'   printing a formatted summary to the console.
#'
#' @seealso [checktor()] to generate results, [health_report()] for detailed reports
#'
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' print(results)
print.checktor_results <- function(x, ...) {
  cli::cli_rule("Package Doctor - Diagnosis Summary")

  cli::cli_text("Patient: {.path {x$metadata$package_path}}")
  cli::cli_text("Examined: {x$metadata$diagnosis_time}")
  cli::cli_text("Doctor version: {x$metadata$checktor_version}")
  cli::cli_text()

  categories <- c("code_issues", "description_issues", "documentation_issues",
                  "general_issues", "policy_issues")
  for (cat in categories) {
    if (!cat %in% names(x)) next
    failed <- sum(!x[[cat]]$passed, na.rm = TRUE)
    status <- if (failed == 0L) "HEALTHY"
              else paste0(failed, " failing check", if (failed > 1L) "s" else "")
    cat_label <- gsub("_", " ", toupper(cat))
    cli::cli_text("{.strong {cat_label}}: {status}")
  }

  cli::cli_text()
  total_issues <- x$metadata$total_issues
  if (total_issues == 0L) {
    cli::cli_alert_success("Overall health: EXCELLENT")
  } else {
    cli::cli_alert_warning(
      "Overall health: NEEDS ATTENTION ({total_issues} issue{?s})"
    )
    cli::cli_text("Run {.code checktor()} for detailed diagnosis")
  }
  invisible(x)
}

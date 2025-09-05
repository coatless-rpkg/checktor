# Main function to run all CRAN diagnostics ----

#' Diagnose Package for CRAN Submission Issues
#'
#' @description Runs a comprehensive diagnostic suite for common CRAN submission
#' issues that are not caught by standard R CMD check. Like a doctor for your package.
#'
#' @param path Character. Path to the R package directory. Defaults to current directory.
#' @param verbose Logical. Whether to print detailed output. Default TRUE.
#' @param progress Logical. Whether to show progress bars. Default TRUE when verbose.
#'
#' @return A list containing results of all diagnostics with status and messages
#'
#' @examples
#' \dontrun{
#' # Diagnose current package
#' results <- checktor()
#'
#' # Diagnose specific package
#' results <- checktor("path/to/package")
#'
#' # Quiet mode
#' results <- checktor(verbose = FALSE)
#' }
#'
#' @export
checktor <- function(path = ".", verbose = TRUE, progress = verbose) {
  # Validate inputs
  validate_package_directory(path)

  if (verbose) {
    cli_rule(left = "Package Doctor - Diagnostic Report", right = "v{utils::packageVersion('checktor')}", line_col = "blue")
    cli_text("Examining package at: {.path {path}}")
    cli_text()
  }

  # Initialize progress if requested
  if (progress && verbose) {
    cli_progress_bar("Running diagnostics", total = 4, type = "tasks")
  }

  results <- list()

  # Run diagnostics with progress updates
  if (progress && verbose) cli_progress_update()
  results$code_issues <- diagnose_code_issues(path, verbose)

  if (progress && verbose) cli_progress_update()
  results$description_issues <- diagnose_description_issues(path, verbose)

  if (progress && verbose) cli_progress_update()
  results$documentation_issues <- diagnose_documentation_issues(path, verbose)

  if (progress && verbose) cli_progress_update()
  results$general_issues <- diagnose_general_issues(path, verbose)

  if (progress && verbose) cli_progress_done()

  # Summarize results
  if (verbose) {
    cli_text()
    cli_rule(left = "Diagnosis Summary", line_col = "blue")
    total_issues <- sum(sapply(results, function(x) sum(!x$passed, na.rm = TRUE)))

    if (total_issues == 0) {
      cli_alert_success("Clean bill of health! No CRAN submission issues found.")
      cli_text("{.emph Your package appears ready for CRAN submission.}")
    } else {
      cli_alert_danger("Found {total_issues} issue{?s} requiring treatment")
      cli_text("Review the detailed diagnosis above for specific remedies.")
      cli_text()
      cli_text("Use {.code prescribe()} to get treatment recommendations.")
    }

    # Add helpful next steps
    cli_text()
    cli_h3("Recommended Next Steps")
    if (total_issues > 0) {
      cli_ol(c(
        "Apply the treatments suggested above",
        "Run {.code devtools::check()} for standard R CMD check",
        "Re-run {.code checktor()} to verify treatments",
        "Submit to CRAN when diagnosis is clean"
      ))
    } else {
      cli_ol(c(
        "Run {.code devtools::check()} for standard R CMD check",
        "Review any additional CRAN submission requirements",
        "Submit to CRAN with confidence!"
      ))
    }
  }

  # Add metadata to results
  results$metadata <- list(
    package_path = path,
    diagnosis_time = Sys.time(),
    total_issues = sum(sapply(results[1:4], function(x) sum(!x$passed, na.rm = TRUE))),
    checktor_version = utils::packageVersion("checktor")
  )

  class(results) <- "checktor_results"
  invisible(results)
}

# Print method for checktor_results
#' @export
print.checktor_results <- function(x, ...) {
  cli_rule("Package Doctor - Diagnosis Summary", line_col = "blue")

  # Package info
  cli_text("Patient: {.path {x$metadata$package_path}}")
  cli_text("Examined: {x$metadata$diagnosis_time}")
  cli_text("Doctor version: {x$metadata$checktor_version}")
  cli_text()

  # Results by category
  categories <- c("code_issues", "description_issues", "documentation_issues", "general_issues")
  for (cat in categories) {
    if (cat %in% names(x)) {
      issues <- sum(!x[[cat]]$passed, na.rm = TRUE)
      status <- if (issues == 0) "HEALTHY" else paste(issues, "issue" %+% if(issues > 1) "s" else "")
      cat_name <- gsub("_", " ", toupper(cat))
      cli_text("{.strong {cat_name}}: {status}")
    }
  }

  cli_text()
  total_issues <- x$metadata$total_issues
  if (total_issues == 0) {
    cli_alert_success("Overall health: EXCELLENT")
  } else {
    cli_alert_warning("Overall health: NEEDS ATTENTION ({total_issues} issue{?s})")
    cli_text("Run {.code checktor()} for detailed diagnosis")
  }
}


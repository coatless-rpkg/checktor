#' Create a Standard Diagnostic Check Result Object
#'
#' Constructor function for creating consistent diagnostic check result objects
#' used by all individual diagnostic functions.
#'
#' @param passed Logical. TRUE if the check passed, FALSE if issues were found.
#' @param issues Character vector. Specific issues found, typically in "file:line" format.
#' @param message Character. Description of what was checked.
#' @param ... Additional named elements specific to the particular check.
#'
#' @return
#' An object of class `checktor_check_result` containing:
#'
#' - `passed`: The passed status
#' - `issues`: Vector of issues found
#' - `message`: Description of the check
#' - Additional elements passed via `...`
#'
#' @seealso
#' Individual diagnostic functions like [diagnose_tf_usage()], [diagnose_seed_setting()]
#'
#' @export
#' @examples
#' # Create a passing check result
#' result <- checktor_check_result(
#'   passed = TRUE,
#'   issues = character(0),
#'   message = "Example check"
#' )
#' print(result)
#'
#' # Create a failing check result with additional elements
#' result <- checktor_check_result(
#'   passed = FALSE,
#'   issues = c("file1.R:5", "file2.R:10"),
#'   message = "T/F usage check",
#'   file_issues = list("file1.R" = 5, "file2.R" = 10)
#' )
#' print(result)
checktor_check_result <- function(passed, issues, message, ...) {
  # Validate inputs
  stopifnot(is.logical(passed), length(passed) == 1)
  stopifnot(is.character(issues))
  stopifnot(is.character(message), length(message) == 1)

  # Create the base structure
  result <- list(
    passed = passed,
    issues = issues,
    message = message
  )

  # Add any additional elements
  additional <- list(...)
  if (length(additional) > 0) {
    result <- c(result, additional)
  }

  # Set class and return
  class(result) <- "checktor_check_result"
  result
}

#' Create a Multi-Category Diagnostic Result Object
#'
#' Constructor function for creating diagnostic category result objects
#' used by multi-category diagnostic functions like [diagnose_code_issues()].
#'
#' @param ... Named arguments where each is a [checktor_check_result] object
#'   representing individual checks within the category.
#'
#' @return
#'
#' An object of class `checktor_category_result` containing:
#'
#' - Individual [checktor_check_result] objects for each check
#' - `passed`: Named logical vector showing which individual checks passed
#'
#' @seealso
#' Multi-category functions like [diagnose_code_issues()], [diagnose_documentation_issues()]
#'
#' @export
#' @examples
#' # Create individual check results
#' tf_check <- checktor_check_result(FALSE, "file.R:5", "T/F usage check")
#' seed_check <- checktor_check_result(TRUE, character(0), "Seed setting check")
#'
#' # Create category result
#' code_results <- checktor_category_result(
#'   tf_usage = tf_check,
#'   seed_setting = seed_check
#' )
#' print(code_results)
checktor_category_result <- function(...) {
  checks <- list(...)

  # Validate that all inputs are checktor_check_result objects
  for (i in seq_along(checks)) {
    if (!inherits(checks[[i]], "checktor_check_result")) {
      stop("All arguments must be checktor_check_result objects")
    }
  }

  # Extract passed status for each check
  passed_status <- sapply(checks, function(x) x$passed)
  names(passed_status) <- names(checks)

  # Add passed status to the result
  result <- c(checks, list(passed = passed_status))

  # Set class and return
  class(result) <- "checktor_category_result"
  result
}

#' Print Method for checktor_check_result Objects
#'
#' @param x A checktor_check_result object
#' @param ... Additional arguments (unused)
#'
#' @return
#' Returns `x` invisibly
#'
#' @export
print.checktor_check_result <- function(x, ...) {
  if (x$passed) {
    cli::cli_alert_success("{x$message}: PASSED")
  } else {
    cli::cli_alert_danger("{x$message}: FAILED")
    if (length(x$issues) > 0) {
      cli::cli_text("Issues found:")
      cli::cli_ul(utils::head(x$issues, 5))
      if (length(x$issues) > 5) {
        cli::cli_text("... and {length(x$issues) - 5} more")
      }
    }
  }
  invisible(x)
}

#' Print Method for checktor_category_result Objects
#'
#' @param x A checktor_category_result object
#' @param ... Additional arguments (unused)
#'
#' @return
#' Returns `x` invisibly
#'
#' @export
print.checktor_category_result <- function(x, ...) {
  if ("passed" %in% names(x)) {
    total_checks <- length(x$passed)
    passed_checks <- sum(x$passed, na.rm = TRUE)
    failed_checks <- total_checks - passed_checks

    cli::cli_rule("Diagnostic Category Results")
    if (failed_checks == 0) {
      cli::cli_alert_success("All {total_checks} checks passed")
    } else {
      cli::cli_alert_warning("{failed_checks} of {total_checks} checks failed")

      # Show failed checks
      failed_names <- names(x$passed)[!x$passed]
      cli::cli_text("Failed checks:")
      for (check_name in failed_names) {
        if (check_name %in% names(x) && inherits(x[[check_name]], "checktor_check_result")) {
          issue_count <- length(x[[check_name]]$issues)
          cli::cli_text("  {check_name}: {issue_count} issue{?s}")
        }
      }
    }
  }
  invisible(x)
}

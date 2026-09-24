#' Create a Standard Diagnostic Check Result Object
#'
#' Constructor function for creating consistent diagnostic check result objects
#' used by all individual diagnostic functions.
#'
#' @param passed Logical. TRUE if the check passed, FALSE if issues were found.
#' @param issues Character vector. Specific issues found, typically in "file:line" format.
#' @param message Character. Description of what was checked.
#' @param ... Additional named elements specific to the particular check. Two
#'   are read by checktor itself: `skipped = TRUE` marks a check that could not
#'   run, and `skip_reason` says why. See Details.
#'
#' @return
#' An object of class `checktor_check_result` containing:
#'
#' - `passed`: The passed status
#' - `issues`: Vector of issues found
#' - `message`: Description of the check
#' - Additional elements passed via `...`
#'
#' @details
#' A check that could not run where it is, because it needs a network, a tool
#' or a file that is not there, should say so rather than pass. Return
#' `checktor_check_result(TRUE, character(0), "<message>", skipped = TRUE,
#' skip_reason = "<why>")`. `passed` stays `TRUE` so the skip cannot fail a
#' verdict, and `skipped` makes [tidy()][tidy.checktor_results],
#' [summary()][summary.checktor_results], `metadata$skipped_checks`, the printed
#' report, [health_report()] and [ci_report()] report it as a check that did not
#' run rather than one that passed. A result with `passed = FALSE` reads as
#' failed whatever `skipped` says.
#'
#' @seealso
#' Individual diagnostic functions like [lab_tf_usage()], [lab_seed_setting()]
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
#'
#' # Report a check that could not run where it is
#' result <- checktor_check_result(
#'   passed = TRUE,
#'   issues = character(0),
#'   message = "License server check",
#'   skipped = TRUE,
#'   skip_reason = "no license server configured"
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
#' - `passed`: Named logical vector showing which individual checks did not
#'   fail. A check that did not run is `TRUE` here, since it cannot fail a
#'   verdict; its own `skipped` element records that it did not run.
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
#' @examples
#' res <- checktor_check_result(FALSE, c("foo.R:3", "bar.R:9"), "T/F usage")
#' print(res)
print.checktor_check_result <- function(x, ...) {
  if (check_status(x) == "skipped") {
    reason <- x$skip_reason
    if (length(reason) == 1L && nzchar(reason)) {
      cli::cli_alert_info("{x$message}: SKIPPED ({reason})")
    } else {
      cli::cli_alert_info("{x$message}: SKIPPED")
    }
    return(invisible(x))
  }
  if (x$passed) {
    cli::cli_alert_success("{x$message}: PASSED")
  } else {
    cli::cli_alert_danger("{x$message}: FAILED")
    if (length(x$issues) > 0) {
      cli::cli_text("Issues found:")
      cli::cli_ul(cli_literal(utils::head(x$issues, 5)))
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
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' print(diagnose_code_issues(pkg, verbose = FALSE))
print.checktor_category_result <- function(x, ...) {
  if (!"passed" %in% names(x)) {
    return(invisible(x))
  }
  # Each check's own status, so a check that did not run is neither a pass nor a
  # failure. A category that returned early has no checks, only its verdict.
  checks <- .check_names(x)
  status <- if (length(checks) > 0L) {
    vapply(checks, function(nm) check_status(x[[nm]]), character(1))
  } else {
    ifelse(x$passed, "passed", "failed")
  }
  total_checks <- length(status)
  passed_checks <- sum(status == "passed")
  failed_checks <- sum(status == "failed")
  failed <- names(status)[status == "failed"]
  skipped <- names(status)[status == "skipped"]

  cli::cli_rule("Diagnostic Category Results")
  if (failed_checks == 0 && length(skipped) == 0L) {
    cli::cli_alert_success("All {total_checks} checks passed")
  } else if (failed_checks == 0 && passed_checks > 0) {
    cli::cli_alert_success("{passed_checks} of {total_checks} checks passed")
  } else if (failed_checks == 0) {
    cli::cli_alert_info("{passed_checks} of {total_checks} checks passed")
  } else {
    cli::cli_alert_warning("{failed_checks} of {total_checks} checks failed")
    if (length(failed) > 0L) {
      cli::cli_text("Failed checks:")
    }
    for (check_name in failed) {
      issue_count <- length(x[[check_name]]$issues)
      cli::cli_text("  {check_name}: {issue_count} issue{?s}")
    }
  }
  if (length(skipped) > 0L) {
    cli::cli_alert_info(
      "{length(skipped)} check{?s} did not run: {.val {skipped}}"
    )
  }
  invisible(x)
}

#' Treatment Recommendations
#'
#' Prints specific treatment recommendations for the checks that failed in a
#' [checktor()] run, whatever their severity tier, so an advisory finding outside
#' the verdict still gets its remedy.
#'
#' @param results A `checktor_results` object.
#'
#' @return
#' Invisibly returns `NULL`. Called for the side effect of printing
#' recommendations.
#'
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' prescribe(results)
prescribe <- function(results) {
  if (!inherits(results, "checktor_results")) {
    cli::cli_abort("Input must be a checktor_results object")
  }

  # `total_issues` is the VERDICT, and it counts only the severity tiers the run
  # was a verdict about. A package can therefore be submission-clean and still
  # have advisory findings worth acting on. Prescribing for the verdict alone
  # would silently withhold the remedy for every one of them, so prescribe for
  # anything that failed, whatever its tier.
  advisory <- results$metadata$advisory_issues
  if (
    results$metadata$total_issues == 0 &&
      (is.null(advisory) || advisory == 0L)
  ) {
    cli::cli_alert_success("No treatment needed - patient is healthy!")
    return(invisible())
  }

  cli::cli_rule("Treatment Recommendations")

  # The same checks health_report() lists; see failed_results().
  for (failed in failed_results(results)) {
    check <- failed$check
    # Treatments are keyed by check name, which is unique across categories; a
    # registered check may not take a built-in name. R/treatments.R holds them,
    # so this prints the remedy health_report() does.
    rx <- treatments[[failed$name]]
    if (!is.null(rx)) {
      # Heading, what was found, one-line remedy, worked example. An example
      # built from the finding already quotes it, so it is not listed twice.
      cli::cli_h3(cli_literal(rx$title))
      if (is.null(rx$example_fn)) {
        prescribe_issues(check)
      }
      # The treatment strings carry cli inline markup, so they have to reach cli
      # as part of the format string. Interpolating them with {rx$treatment}
      # passes them as a *value*, and cli deliberately does not re-parse markup
      # inside interpolated values, so the braces would print literally.
      cli::cli_text(paste0("{.strong Treatment:} ", rx$treatment))
      example <- treatment_example(rx, check)
      if (length(example) > 0L) {
        cli::cli_code(example)
      }
    } else {
      # A registered check has no treatment: still surface the check and the
      # issues it found, so prescribe() never stays silent about a failure.
      prescribe_generic(check, failed$name)
    }
    cli::cli_text()
  }
  invisible()
}

# Fallback treatment block for a failed check that has no treatment entry: show
# the check's own message as the heading and list the concrete issues found.
prescribe_generic <- function(check, chk_name) {
  title <- check$message %||% chk_name
  cli::cli_h3("{title}")
  prescribe_issues(check)
  cli::cli_text(
    "{.strong Treatment:} Review the detailed diagnosis above; re-run {.code checktor(verbose = TRUE)} for specifics."
  )
}

# The first five issues a check found, printed as the package wrote them.
prescribe_issues <- function(check) {
  if (length(check$issues) == 0L) {
    return(invisible())
  }
  issues <- truncate_issues(check$issues, 5L)
  cli::cli_text("{.strong Issues found:}")
  cli::cli_ul(cli_literal(issues$shown))
  if (issues$extra > 0L) {
    cli::cli_text("{.emph ... and {issues$extra} more}")
  }
}

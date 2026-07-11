#' Treatment Recommendations
#'
#' Prints specific treatment recommendations for issues found by [checktor()].
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

  if (results$metadata$total_issues == 0) {
    cli::cli_alert_success("No treatment needed - patient is healthy!")
    return(invisible())
  }

  cli::cli_rule("Treatment Recommendations")

  # Index the curated treatments by "category::check" so any failed check can
  # look up its rich remediation snippet in one step.
  rx_index <- treatments
  names(rx_index) <- vapply(
    treatments,
    function(rx) paste(rx$category, rx$check, sep = "::"),
    character(1)
  )

  categories <- c("code_issues", "description_issues", "documentation_issues",
                  "general_issues", "policy_issues")
  for (cat in categories) {
    cat_res <- results[[cat]]
    if (is.null(cat_res) || is.null(cat_res$passed) ||
        is.null(names(cat_res$passed))) {
      next
    }
    failed <- names(cat_res$passed)[!cat_res$passed]
    for (chk in failed) {
      rx <- rx_index[[paste(cat, chk, sep = "::")]]
      if (!is.null(rx)) {
        # Curated treatment: heading, one-line remedy, worked example.
        cli::cli_h3(rx$title)
        cli::cli_text("{.strong Treatment:} {rx$treatment}")
        cli::cli_code(rx$example)
      } else {
        # No curated snippet yet: still surface the check and the specific
        # issues it found, so prescribe() never stays silent about a failure.
        prescribe_generic(cat_res[[chk]], chk)
      }
      cli::cli_text()
    }
  }
  invisible()
}

# Fallback treatment block for a failed check that has no curated entry: show
# the check's own message as the heading and list the concrete issues found.
prescribe_generic <- function(check, chk_name) {
  title <- if (is.list(check) && !is.null(check$message)) check$message else chk_name
  cli::cli_h3(title)
  issues <- if (is.list(check)) check$issues else NULL
  if (length(issues) > 0L) {
    cli::cli_text("{.strong Issues found:}")
    cli::cli_ul(utils::head(issues, 5L))
    if (length(issues) > 5L) {
      cli::cli_text("{.emph ... and {length(issues) - 5L} more}")
    }
  }
  cli::cli_text(
    "{.strong Treatment:} Review the detailed diagnosis above; re-run {.code checktor(verbose = TRUE)} for specifics."
  )
}

# Treatment data indexed by (category, check). Adding a new treatment is just
# appending an entry here - no need to edit prescribe()'s control flow.
treatments <- list(
  list(
    category  = "code_issues",
    check     = "tf_usage",
    title     = "T/F Usage Issues",
    treatment = "Replace {.code T} with {.code TRUE} and {.code F} with {.code FALSE}",
    example   = c(
      "# Before",
      "result <- T",
      "",
      "# After",
      "result <- TRUE"
    )
  ),
  list(
    category  = "code_issues",
    check     = "seed_setting",
    title     = "Hardcoded Seed Issues",
    treatment = "Add a seed parameter so callers control randomness",
    example   = c(
      "# Before",
      "my_function <- function(data) {",
      "  set.seed(123)",
      "  # ...",
      "}",
      "",
      "# After",
      "my_function <- function(data, seed = NULL) {",
      "  if (!is.null(seed)) set.seed(seed)",
      "  # ...",
      "}"
    )
  ),
  list(
    category  = "code_issues",
    check     = "print_cat_usage",
    title     = "Unsuppressable Output Issues",
    treatment = "Use {.code message()} or gate output on a verbose parameter",
    example   = c(
      "# Before",
      "print('Processing...')",
      "",
      "# After - option 1",
      "message('Processing...')",
      "",
      "# After - option 2",
      "my_function <- function(data, verbose = TRUE) {",
      "  if (verbose) cli::cli_inform('Processing...')",
      "}"
    )
  ),
  list(
    category  = "documentation_issues",
    check     = "value_tags",
    title     = "Missing \\value Tags",
    treatment = "Add {.code @return} tags to your roxygen documentation",
    example   = c(
      "#' My Function",
      "#' @param x A parameter",
      "#' @return A character vector with results",
      "#' @export",
      "my_function <- function(x) paste('Result:', x)"
    )
  )
)

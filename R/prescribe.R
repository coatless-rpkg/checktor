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
  for (rx in treatments) {
    check <- results[[rx$category]][[rx$check]]
    if (is.null(check) || isTRUE(check$passed)) next
    cli::cli_h3(rx$title)
    cli::cli_text("{.strong Treatment:} {rx$treatment}")
    cli::cli_code(rx$example)
    cli::cli_text()
  }
  invisible()
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

#' Treatment Recommendations
#'
#' @description Provides specific treatment recommendations for found issues
#'
#' @param results checktor_results object
#'
#' @export
prescribe <- function(results) {
  if (!inherits(results, "checktor_results")) {
    cli_abort("Input must be a checktor_results object")
  }

  if (results$metadata$total_issues == 0) {
    cli_alert_success("No treatment needed - patient is healthy!")
    return(invisible())
  }

  cli_rule("Treatment Recommendations", line_col = "green")

  # T/F usage fixes
  if (!is.null(results$code_issues$tf_usage) && !results$code_issues$tf_usage$passed) {
    cli_h3("T/F Usage Issues")
    cli_text("{.strong Treatment:} Replace {.code T} with {.code TRUE} and {.code F} with {.code FALSE}")
    cli_code("# Before treatment
result <- T

# After treatment
result <- TRUE")
    cli_text()
  }

  # Seed setting fixes
  if (!is.null(results$code_issues$seed_setting) && !results$code_issues$seed_setting$passed) {
    cli_h3("Hardcoded Seed Issues")
    cli_text("{.strong Treatment:} Add a seed parameter to your function")
    cli_code("# Before treatment
my_function <- function(data) {
  set.seed(123)
  # ... rest of function
}

# After treatment
my_function <- function(data, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  # ... rest of function
}")
    cli_text()
  }

# Print/cat fixes
if (!is.null(results$code_issues$print_cat_usage) && !results$code_issues$print_cat_usage$passed) {
  cli_h3("Unsuppressable Output Issues")
  cli_text("{.strong Treatment:} Use {.code message()} or add verbose parameter")
  cli_code("# Before treatment
print('Processing...')

# After treatment - Option 1
message('Processing...')

# After treatment - Option 2
my_function <- function(data, verbose = TRUE) {
  if (verbose) cat('Processing...\\n')
}")
  cli_text()
}

# Value tag fixes
if (!is.null(results$documentation_issues$value_tags) && !results$documentation_issues$value_tags$passed) {
  cli_h3("Missing \\value Tags")
  cli_text("{.strong Treatment:} Add {.code @return} tags to your roxygen documentation")
  cli_code("#' My Function
#' @param x A parameter
#' @return A character vector with results
#' @export
my_function <- function(x) {
  return(paste('Result:', x))
}")
  cli_text()
}
}

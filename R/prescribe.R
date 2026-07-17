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

  # Index the curated treatments by "category::check" so any failed check can
  # look up its rich remediation snippet in one step.
  rx_index <- treatments
  names(rx_index) <- vapply(
    treatments,
    function(rx) paste(rx$category, rx$check, sep = "::"),
    character(1)
  )

  categories <- c(
    "code_issues",
    "description_issues",
    "documentation_issues",
    "general_issues",
    "policy_issues"
  )
  for (cat in categories) {
    cat_res <- results[[cat]]
    if (
      is.null(cat_res) ||
        is.null(cat_res$passed) ||
        is.null(names(cat_res$passed))
    ) {
      next
    }
    failed <- names(cat_res$passed)[!cat_res$passed]
    for (chk in failed) {
      rx <- rx_index[[paste(cat, chk, sep = "::")]]
      if (!is.null(rx)) {
        # Curated treatment: heading, one-line remedy, worked example.
        cli::cli_h3(rx$title)
        # The treatment strings carry cli inline markup, so they have to reach
        # cli as part of the format string. Interpolating them with
        # {rx$treatment} passes them as a *value*, and cli deliberately does not
        # re-parse markup inside interpolated values, so the braces would print
        # literally.
        cli::cli_text(paste0("{.strong Treatment:} ", rx$treatment))
        # A treatment may carry a static `example`, or an `example_fn` that
        # builds the snippet from the failed check itself (spelling fills in the
        # words it actually flagged).
        example <- if (!is.null(rx$example_fn)) {
          rx$example_fn(cat_res[[chk]])
        } else {
          rx$example
        }
        cli::cli_code(example)
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
  title <- if (is.list(check) && !is.null(check$message)) {
    check$message
  } else {
    chk_name
  }
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
    category = "code_issues",
    check = "tf_usage",
    title = "T/F Usage Issues",
    treatment = "Replace {.code T} with {.code TRUE} and {.code F} with {.code FALSE}",
    example = c(
      "# Before",
      "result <- T",
      "",
      "# After",
      "result <- TRUE"
    )
  ),
  list(
    category = "code_issues",
    check = "seed_setting",
    title = "Hardcoded Seed Issues",
    treatment = "Add a seed parameter so callers control randomness",
    example = c(
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
    category = "code_issues",
    check = "print_cat_usage",
    title = "Unsuppressable Output Issues",
    treatment = "Use {.code message()} or gate output on a verbose parameter",
    example = c(
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
    category = "documentation_issues",
    check = "value_tags",
    title = "Missing \\value Tags",
    treatment = "Add {.code @return} tags to your roxygen documentation",
    example = c(
      "#' My Function",
      "#' @param x A parameter",
      "#' @return A character vector with results",
      "#' @export",
      "my_function <- function(x) paste('Result:', x)"
    )
  ),
  list(
    category = "description_issues",
    check = "spelling",
    title = "Possibly Misspelled Words",
    treatment = "Record the correct terms in a {.file .aspell} dictionary, which {.code R CMD check --as-cran} reads",
    example_fn = function(check) {
      words <- if (is.list(check)) check$issues else character(0)
      build_aspell_snippet(words)
    }
  )
)

# Build the .aspell/ setup snippet, pre-filled with the words a run flagged.
# inst/WORDLIST (the spelling package) does NOT clear CRAN's aspell NOTE; a
# .aspell/ dictionary does, so that is what we prescribe.
build_aspell_snippet <- function(words) {
  if (length(words) == 0L) {
    words <- "TechnicalTerm"
  }
  vec <- paste0(
    "c(",
    paste(sprintf('"%s"', words), collapse = ", "),
    ")"
  )
  c(
    "# In the package root, record the accepted spellings:",
    paste0("saveRDS(", vec, ', ".aspell/words.rds")'),
    "",
    "# .aspell/defaults.R (point aspell at that dictionary):",
    "Rd_files <- vignettes <- R_files <- description <-",
    '  list(encoding = "UTF-8", dictionaries = c("en_stats", "words"))'
  )
}

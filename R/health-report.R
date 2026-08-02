# Enhanced reporting with more detail and formatting

#' Comprehensive Health Report
#'
#' @description Creates a comprehensive report with specific treatment instructions
#'
#' @param results List. Results from checktor()
#' @param file Character. Output file path (optional)
#' @param format Character. Report format: "markdown", "html", or "text"
#'
#' @return Character vector with report content
#'
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' report <- health_report(results, format = "text")
#' head(report)
health_report <- function(results, file = NULL, format = "markdown") {
  if (!inherits(results, "checktor_results")) {
    cli::cli_abort("Input must be a checktor_results object")
  }

  if (format == "markdown") {
    report <- generate_markdown_report(results)
  } else if (format == "html") {
    report <- generate_html_report(results)
  } else {
    report <- generate_text_report(results)
  }

  if (!is.null(file)) {
    writeLines(report, file)
    cli::cli_alert_success("Health report written to: {.path {file}}")
  }

  return(report)
}

# The categories a report walks, in the order checktor() runs them. Kept in one
# place because every format has to agree: the CRAN policy panel was once missing
# from the markdown report, which hid exactly the findings a reviewer acts on.
REPORT_CATEGORIES <- c(
  "code_issues",
  "description_issues",
  "documentation_issues",
  "general_issues",
  "policy_issues"
)

# Every failing check in a result, flattened to list(category, check, result), so
# the markdown, text and HTML writers all report the same findings.
report_findings <- function(results) {
  out <- list()
  for (category in intersect(REPORT_CATEGORIES, names(results))) {
    cat_results <- results[[category]]
    if (!("passed" %in% names(cat_results))) {
      next
    }
    for (check in names(cat_results$passed)[!cat_results$passed]) {
      res <- cat_results[[check]]
      if (!is.list(res) || !("issues" %in% names(res))) {
        next
      }
      out[[length(out) + 1L]] <- list(
        category = category,
        check = check,
        result = res
      )
    }
  }
  out
}

# A sentence naming any check that did not run, so a report never reads as though
# everything was examined when it was not.
report_skipped_line <- function(results) {
  skipped <- results$metadata$skipped_checks
  if (length(skipped) == 0L) {
    return(character(0))
  }
  paste0(
    "Checks that did not run: ",
    paste(skipped, collapse = ", "),
    "."
  )
}

pretty_label <- function(x) gsub("_", " ", tools::toTitleCase(x))

# Findings carry things like <YEAR> and <COPYRIGHT HOLDER>, which would otherwise
# be swallowed as markup by a browser.
escape_html <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

generate_markdown_report <- function(results) {
  report <- c(
    "# Package Doctor - Health Report",
    "",
    paste("**Patient:** `", results$metadata$package_path, "`", sep = ""),
    paste("**Examination Date:** ", results$metadata$diagnosis_time),
    paste("**Doctor Version:** ", results$metadata$checktor_version),
    "",
    "## Executive Summary",
    ""
  )

  total_issues <- results$metadata$total_issues
  if (total_issues == 0) {
    report <- c(
      report,
      "**CLEAN BILL OF HEALTH** - Your package appears ready for CRAN submission.",
      "",
      "### Next Steps",
      "1. Run `R CMD check` or `devtools::check()` for standard checks",
      "2. Review the [CRAN submission checklist](https://cran.r-project.org/web/packages/submission_checklist.html)",
      "3. Submit to CRAN with confidence!"
    )
  } else {
    report <- c(
      report,
      paste(
        "**REQUIRES TREATMENT:** ",
        total_issues,
        " issue(s) found that should be addressed before CRAN submission."
      ),
      ""
    )

    # The total counts only the tiers the verdict is about, so say what the
    # sections below actually contain rather than letting the two disagree.
    advisory <- results$metadata$advisory_issues
    if (!is.null(advisory) && advisory > 0L) {
      report <- c(
        report,
        paste0(
          "Every failing check is listed below, including ",
          advisory,
          " advisory finding(s) that do not count toward that total."
        ),
        ""
      )
    }

    findings <- report_findings(results)
    current <- ""
    for (finding in findings) {
      if (!identical(finding$category, current)) {
        current <- finding$category
        report <- c(report, paste("## ", pretty_label(current)), "")
      }
      check_result <- finding$result
      report <- c(report, paste("### ", pretty_label(finding$check)))

      treatment_instructions <- get_treatment_instructions(
        finding$check,
        check_result
      )
      if (!is.null(treatment_instructions)) {
        report <- c(report, "", "**Treatment:**", treatment_instructions, "")
      }

      if (length(check_result$issues) > 0) {
        report <- c(report, "**Affected Areas:**")
        for (issue in utils::head(check_result$issues, 10)) {
          report <- c(report, paste("- `", issue, "`", sep = ""))
        }
        if (length(check_result$issues) > 10) {
          report <- c(
            report,
            paste("- ... and", length(check_result$issues) - 10, "more")
          )
        }
        report <- c(report, "")
      }
    }
  }

  skipped <- report_skipped_line(results)
  if (length(skipped) > 0L) {
    report <- c(report, "", skipped, "")
  }

  report <- c(
    report,
    "",
    "---",
    "*Report generated by [checktor - The Package Doctor](https://github.com/coatless-rpkg/checktor)*"
  )

  return(report)
}

get_treatment_instructions <- function(check_name, check_result) {
  instructions <- switch(
    check_name,
    "tf_usage" = c(
      "Replace all instances of `T` with `TRUE` and `F` with `FALSE`.",
      "```r",
      "# Before treatment",
      "result <- T",
      "",
      "# After treatment",
      "result <- TRUE",
      "```"
    ),
    "seed_setting" = c(
      "Add a `seed` parameter to functions that set seeds:",
      "```r",
      "# Before treatment",
      "my_function <- function(data) {",
      "  set.seed(123)",
      "  # ...",
      "}",
      "",
      "# After treatment",
      "my_function <- function(data, seed = NULL) {",
      "  if (!is.null(seed)) set.seed(seed)",
      "  # ...",
      "}",
      "```"
    ),
    "print_cat_usage" = c(
      "Replace `print()`/`cat()` with `message()` or add verbose parameter:",
      "```r",
      "# Before treatment",
      "print('Processing...')",
      "",
      "# After treatment - Option 1",
      "message('Processing...')",
      "",
      "# After treatment - Option 2",
      "if (verbose) cat('Processing...\\n')",
      "```"
    ),
    NULL # Default case
  )

  return(instructions)
}

generate_text_report <- function(results) {
  # Simple text version of the report
  report <- c(
    "Package Doctor - Health Report",
    paste("Generated on:", results$metadata$diagnosis_time),
    paste("Patient:", results$metadata$package_path),
    "",
    "Summary:",
    paste("Total Issues:", results$metadata$total_issues)
  )

  if (results$metadata$total_issues == 0) {
    report <- c(
      report,
      "",
      "Clean bill of health! Package appears ready for CRAN."
    )
  } else {
    report <- c(report, "", "Findings:")
    current <- ""
    for (finding in report_findings(results)) {
      if (!identical(finding$category, current)) {
        current <- finding$category
        report <- c(report, "", paste0("  ", pretty_label(current)))
      }
      report <- c(report, paste0("    ", pretty_label(finding$check)))
      for (issue in utils::head(finding$result$issues, 10)) {
        report <- c(report, paste0("      - ", issue))
      }
      extra <- length(finding$result$issues) - 10
      if (extra > 0) {
        report <- c(report, paste0("      - ... and ", extra, " more"))
      }
    }
    report <- c(
      report,
      "",
      "Run prescribe() on the same results for treatment instructions."
    )
  }

  skipped <- report_skipped_line(results)
  if (length(skipped) > 0L) {
    report <- c(report, "", skipped)
  }

  return(report)
}

generate_html_report <- function(results) {
  # HTML version with basic styling
  html <- c(
    "<!DOCTYPE html>",
    "<html>",
    "<head>",
    "<title>Package Doctor - Health Report</title>",
    "<style>",
    "body { font-family: Arial, sans-serif; margin: 40px; }",
    ".header { color: #2c3e50; border-bottom: 2px solid #3498db; }",
    ".summary { background: #ecf0f1; padding: 15px; border-radius: 5px; }",
    ".issue { color: #e74c3c; }",
    ".success { color: #27ae60; }",
    "</style>",
    "</head>",
    "<body>",
    "<h1 class='header'>Package Doctor - Health Report</h1>",
    paste(
      "<p><strong>Patient:</strong>",
      results$metadata$package_path,
      "</p>"
    ),
    paste(
      "<p><strong>Examination Date:</strong>",
      results$metadata$diagnosis_time,
      "</p>"
    ),
    "<div class='summary'>",
    paste(
      "<h2>Diagnosis:",
      results$metadata$total_issues,
      "issue(s) found</h2>"
    )
  )

  if (results$metadata$total_issues == 0) {
    html <- c(html, "<p class='success'>Clean bill of health!</p>")
  } else {
    current <- ""
    for (finding in report_findings(results)) {
      if (!identical(finding$category, current)) {
        if (nzchar(current)) {
          html <- c(html, "</ul>")
        }
        current <- finding$category
        html <- c(
          html,
          paste0("<h3>", escape_html(pretty_label(current)), "</h3>"),
          "<ul>"
        )
      }
      html <- c(
        html,
        paste0("<li><strong>", escape_html(pretty_label(finding$check)), "</strong>")
      )
      if (length(finding$result$issues) > 0) {
        html <- c(html, "<ul>")
        for (issue in utils::head(finding$result$issues, 10)) {
          html <- c(html, paste0("<li>", escape_html(issue), "</li>"))
        }
        extra <- length(finding$result$issues) - 10
        if (extra > 0) {
          html <- c(html, paste0("<li>... and ", extra, " more</li>"))
        }
        html <- c(html, "</ul>")
      }
      html <- c(html, "</li>")
    }
    if (nzchar(current)) {
      html <- c(html, "</ul>")
    }
  }

  skipped <- report_skipped_line(results)
  if (length(skipped) > 0L) {
    html <- c(html, paste0("<p>", escape_html(skipped), "</p>"))
  }

  html <- c(html, "</div>", "</body>", "</html>")

  return(html)
}

# Helper functions for better error messages
validate_package_directory <- function(path) {
  if (!dir.exists(path)) {
    cli::cli_abort("Directory {.path {path}} does not exist")
  }

  if (!file.exists(file.path(path, "DESCRIPTION"))) {
    cli::cli_abort(c(
      "No DESCRIPTION file found in {.path {path}}, or in any directory above it.",
      "i" = "checktor runs from anywhere inside a package. Is this one?"
    ))
  }

  return(TRUE)
}

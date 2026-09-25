# Enhanced reporting with more detail and formatting

#' Comprehensive Health Report
#'
#' @description Creates a report of every failing check, whatever its severity
#'   tier, with the treatment [prescribe()] gives for it. Every format carries
#'   the same treatment text.
#'
#' @param results A `checktor_results` object from [checktor()].
#' @param file Character. A path to write the report to, or `NULL` (the default)
#'   to only return it.
#' @param format Character. Report format: `"markdown"` (the default), `"html"`,
#'   or `"text"`. Any other value gives the text format.
#'
#' @return The report as a character vector, one element per line. It is
#'   returned visibly even when `file` is given, so assign it to keep a console
#'   call from printing it.
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

# The checks of a result that failed, in report order, as result_checks() lists
# them. A check fails when its category's `passed` vector says so, which is the
# verdict apply_suppressions() keeps in step with any muted findings.
# prescribe() and the report writers select through here, so they report the
# same checks.
failed_results <- function(results) {
  Filter(
    function(rc) {
      passed <- results[[CATEGORY_FIELDS[[rc$category]]]]$passed
      rc$name %in% names(passed) && !passed[[rc$name]]
    },
    result_checks(results)
  )
}

# Every failing check in a result, flattened to list(category, check, result), so
# the markdown, text and HTML writers all report the same findings. `category`
# is the result's field, such as "code_issues".
report_findings <- function(results) {
  lapply(
    Filter(function(rc) "issues" %in% names(rc$check), failed_results(results)),
    function(rc) {
      list(
        category = CATEGORY_FIELDS[[rc$category]],
        check = rc$name,
        result = rc$check
      )
    }
  )
}

# The first `n` of a check's findings, and how many more there are, for a
# report that lists a few and counts the rest.
truncate_issues <- function(issues, n) {
  list(shown = utils::head(issues, n), extra = length(issues) - n)
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

      rx <- treatments[[finding$check]]
      if (!is.null(rx)) {
        report <- c(
          report,
          "",
          paste("**Treatment:**", treatment_markdown(rx$treatment))
        )
        example <- treatment_example(rx, check_result)
        if (length(example) > 0L) {
          report <- c(report, "", "```r", example, "```")
        }
        report <- c(report, "")
      }

      if (length(check_result$issues) > 0) {
        issues <- truncate_issues(check_result$issues, 10)
        report <- c(
          report,
          "**Affected Areas:**",
          paste0("- `", issues$shown, "`"),
          if (issues$extra > 0) paste("- ... and", issues$extra, "more"),
          ""
        )
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
      issues <- truncate_issues(finding$result$issues, 10)
      report <- c(
        report,
        paste0("    ", pretty_label(finding$check)),
        paste0("      - ", issues$shown, recycle0 = TRUE),
        if (issues$extra > 0) paste0("      - ... and ", issues$extra, " more")
      )
      rx <- treatments[[finding$check]]
      if (!is.null(rx)) {
        report <- c(
          report,
          paste0("      Treatment: ", treatment_markdown(rx$treatment))
        )
        example <- treatment_example(rx, finding$result)
        if (length(example) > 0L) {
          report <- c(report, "", paste0("        ", example), "")
        }
      }
    }
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
        issues <- truncate_issues(finding$result$issues, 10)
        html <- c(
          html,
          "<ul>",
          paste0("<li>", escape_html(issues$shown), "</li>"),
          if (issues$extra > 0) {
            paste0("<li>... and ", issues$extra, " more</li>")
          },
          "</ul>"
        )
      }
      rx <- treatments[[finding$check]]
      if (!is.null(rx)) {
        html <- c(
          html,
          paste0(
            "<p><strong>Treatment:</strong> ",
            treatment_html(rx$treatment),
            "</p>"
          )
        )
        example <- treatment_example(rx, finding$result)
        if (length(example) > 0L) {
          html <- c(
            html,
            paste0(
              "<pre><code>",
              paste(escape_html(example), collapse = "\n"),
              "</code></pre>"
            )
          )
        }
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

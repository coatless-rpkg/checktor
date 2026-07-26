#' Diagnose Package for CRAN Submission Issues
#'
#' Runs a comprehensive diagnostic suite for common CRAN submission issues that
#' are not caught by standard R CMD check. Like a doctor for your package, this
#' function examines your code, DESCRIPTION file, documentation, general
#' package structure, and CRAN policy compliance to identify potential problems
#' that could cause CRAN submission delays or rejections.
#'
#' @param path Character. Any directory inside the R package, or a file within
#'   one. Defaults to the working directory (`"."`). checktor walks up to find the
#'   `DESCRIPTION`, so running it from `R/` or `tests/testthat/` examines the whole
#'   package rather than failing. See [find_package_root()].
#' @param verbose Logical. Whether to print detailed diagnostic output to
#'   console. Defaults to `getOption("checktor.verbose", TRUE)`.
#' @param progress Logical. Whether to show progress bars during diagnostics.
#'   Defaults to `getOption("checktor.progress", verbose)`.
#' @param severity Character. Which severity tiers count toward the verdict:
#'   any of `"policy"`, `"robustness"`, `"opinion"`. Defaults to
#'   `getOption("checktor.severity", c("policy", "robustness"))`.
#'
#'   Every check still runs, and every finding stays in the result and appears in
#'   [issues()] with its tier. What this argument decides is which findings count
#'   against a clean bill of health. `"policy"` is a citable CRAN Repository
#'   Policy or Writing R Extensions violation. `"robustness"` is a real defect
#'   that CRAN will nonetheless let you ship, such as a `detectCores()` that may
#'   return `NA`. `"opinion"` is a convention with no authority behind it.
#'
#'   The default therefore makes "0 issues" mean *nothing here will get you
#'   rejected, and nothing here will crash a user*. Pass all three tiers to hold
#'   yourself to the conventions as well.
#'
#' @return
#' A `checktor_results` object (list) containing:
#'
#' - `code_issues`: Results from code diagnostics
#' - `description_issues`: Results from DESCRIPTION file diagnostics
#' - `documentation_issues`: Results from documentation diagnostics
#' - `general_issues`: Results from general package diagnostics
#' - `policy_issues`: Results from CRAN policy violation diagnostics
#' - `metadata`: List with package path, diagnosis time, total issue count,
#'   total failed-check count, and checktor version
#'
#' Each diagnostic category contains a `passed` element showing which individual
#' checks passed/failed, plus detailed results for each check.
#'
#' @details
#' The function runs five categories of diagnostics: **Code**, **DESCRIPTION**,
#' **Documentation**, **General**, and **Policy**. See [diagnose_code_issues()],
#' [diagnose_description_issues()], [diagnose_documentation_issues()],
#' [diagnose_general_issues()], and [diagnose_policy_violations()] for the
#' specific checks within each category.
#'
#' The `metadata$total_issues` figure counts the total number of distinct
#' issues found across all checks (e.g., 80 lines using `T`/`F` count as 80,
#' not 1). The `metadata$failed_checks` figure counts how many individual
#' checks reported any issue at all.
#'
#' A package can configure checktor from `Config/checktor/*` fields in its own
#' `DESCRIPTION` (comma-separated lists):
#' - `Config/checktor/disable`: check names to skip entirely. A disabled check
#'   does not run and is not counted anywhere in the results.
#' - `Config/checktor/allow`: `check` to mute a whole check, or `check:substring`
#'   to mute only findings whose text contains `substring`. The check still
#'   runs; muted findings are dropped from the results and tallied in
#'   `metadata$suppressed`, while a `disable`d check is removed entirely and
#'   never counted there.
#' - `Config/checktor/software_names`, `Config/checktor/language_names`,
#'   `Config/checktor/acronyms`: names appended to those checks' vocabularies.
#'
#' @seealso
#' [health_report()] to generate detailed reports, [prescribe()] for treatment
#' recommendations, [checkup()] for quick health checks
#'
#' @export
#' @examples
#' # Run against a synthetic package with known T/F issues
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#'
#' results              # the diagnosis summary
#' summary(results)     # per-category overview
#' issues(results)      # every issue as a tidy data frame
#' is_healthy(results)  # FALSE
checktor <- function(
  path = ".",
  verbose = getOption("checktor.verbose", TRUE),
  progress = getOption("checktor.progress", verbose),
  severity = getOption("checktor.severity", DEFAULT_SEVERITY)
) {
  path <- find_package_root(path)
  validate_package_directory(path)
  severity <- match.arg(severity, SEVERITY_LEVELS, several.ok = TRUE)

  if (verbose) {
    cli::cli_rule(
      left = "Package Doctor - Diagnostic Report",
      right = paste0("v", utils::packageVersion("checktor"))
    )
    cli::cli_text("Examining package at: {.path {path}}")
    cli::cli_text()
  }

  categories <- list(
    code_issues = diagnose_code_issues,
    description_issues = diagnose_description_issues,
    documentation_issues = diagnose_documentation_issues,
    general_issues = diagnose_general_issues,
    policy_issues = diagnose_policy_violations
  )

  if (progress && verbose) {
    cli::cli_progress_bar(
      "Running diagnostics",
      total = length(categories),
      type = "tasks"
    )
  }

  results <- list()
  for (cat_name in names(categories)) {
    if (progress && verbose) {
      cli::cli_progress_update()
    }
    results[[cat_name]] <- categories[[cat_name]](path, verbose)
  }
  if (progress && verbose) {
    cli::cli_progress_done()
  }

  config <- checktor_config(path)
  suppression <- apply_suppressions(results, config)
  results <- suppression$results

  counts <- count_results(results, severity)
  total_issues <- counts$issues
  failed_checks <- counts$failed_checks

  # Everything ran, so anything outside the verdict's tiers is still here to be
  # reported -- just not counted against a clean bill of health.
  advisory <- count_results(results, setdiff(SEVERITY_LEVELS, severity))$issues

  if (verbose) {
    cli::cli_text()
    cli::cli_rule(left = "Diagnosis Summary")
    if (suppression$suppressed > 0L) {
      cli::cli_alert_info(
        "{suppression$suppressed} finding{?s} muted by Config/checktor."
      )
    }
    if (total_issues == 0L) {
      cli::cli_alert_success(
        "Clean bill of health! No CRAN submission issues found."
      )
      cli::cli_text("{.emph Your package appears ready for CRAN submission.}")
      if (advisory > 0L) {
        cli::cli_alert_info(
          "{advisory} advisory finding{?s} not counted here (severity: {.val {setdiff(SEVERITY_LEVELS, severity)}})."
        )
      }
    } else {
      cli::cli_alert_danger(
        "Found {total_issues} issue{?s} across {failed_checks} failed check{?s}"
      )
      cli::cli_text(
        "Review the detailed diagnosis above for specific remedies."
      )
      cli::cli_text()
      cli::cli_text("Use {.code prescribe()} to get treatment recommendations.")
    }

    cli::cli_text()
    cli::cli_h3("Recommended Next Steps")
    if (total_issues > 0L) {
      cli::cli_ol(c(
        "Apply the treatments suggested above",
        "Run {.code devtools::check()} for standard R CMD check",
        "Re-run {.code checktor()} to verify treatments",
        "Submit to CRAN when diagnosis is clean"
      ))
    } else {
      cli::cli_ol(c(
        "Run {.code devtools::check()} for standard R CMD check",
        "Review any additional CRAN submission requirements",
        "Submit to CRAN with confidence!"
      ))
    }
  }

  results$metadata <- list(
    package_path = path,
    diagnosis_time = Sys.time(),
    total_issues = total_issues,
    failed_checks = failed_checks,
    severity = severity,
    advisory_issues = advisory,
    suppressed = suppression$suppressed,
    checktor_version = utils::packageVersion("checktor")
  )

  class(results) <- "checktor_results"
  invisible(results)
}

# Single walk over a checktor_results-shaped list. Returns a list with:
#   $issues        - total individual issues (e.g., 80 T/F hits -> 80)
#   $failed_checks - number of sub-checks where any issue was found
# A check that errored (no $issues, only $error) counts as one issue so it
# surfaces in reports instead of being silently dropped.
# The headline verdict counts only the tiers it is a verdict ABOUT. Every check
# still RUNS and its findings stay in the object; what `severity` decides is
# whether a finding counts against a clean bill of health. So the default,
# policy + robustness, makes "0 issues" mean "nothing here will get you rejected,
# and nothing here will crash a user" -- rather than "nobody disagrees with any of
# your stylistic choices", which is not a question anyone was asking.
count_results <- function(results, severity = SEVERITY_LEVELS) {
  issues <- 0L
  failed <- 0L
  for (cat in results) {
    if (!is.list(cat)) {
      next
    }
    for (nm in setdiff(names(cat), "passed")) {
      check <- cat[[nm]]
      if (!is.list(check)) {
        next
      }
      if (!(check_severity(nm) %in% severity)) {
        next
      }
      if (isFALSE(check$passed)) {
        failed <- failed + 1L
      }
      if (!is.null(check$issues)) {
        issues <- issues + length(check$issues)
      } else if (isFALSE(check$passed)) {
        issues <- issues + 1L
      }
    }
  }
  list(issues = issues, failed_checks = failed)
}

#' Print Method for checktor_results Objects
#'
#' Provides a clean, formatted summary of diagnostic results from [checktor()].
#'
#' @param x A `checktor_results` object from [checktor()]
#' @param ... Additional arguments passed to print methods (currently unused)
#'
#' @return Returns `x` invisibly. Called primarily for its side effect of
#'   printing a formatted summary to the console.
#'
#' @seealso [checktor()] to generate results, [health_report()] for detailed reports
#'
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' print(results)
print.checktor_results <- function(x, ...) {
  cli::cli_rule("Package Doctor - Diagnosis Summary")

  cli::cli_text("Patient: {.pkg {package_label(x$metadata$package_path)}}")
  cli::cli_text("Examined: {x$metadata$diagnosis_time}")
  cli::cli_text("Doctor version: {x$metadata$checktor_version}")
  cli::cli_text()

  categories <- c(
    "code_issues",
    "description_issues",
    "documentation_issues",
    "general_issues",
    "policy_issues"
  )
  for (cat in categories) {
    if (!cat %in% names(x)) {
      next
    }
    failed <- sum(!x[[cat]]$passed, na.rm = TRUE)
    status <- if (failed == 0L) {
      "HEALTHY"
    } else {
      paste0(failed, " failing check", if (failed > 1L) "s" else "")
    }
    cat_label <- gsub("_", " ", toupper(cat))
    cli::cli_text("{.strong {cat_label}}: {status}")
  }

  cli::cli_text()
  suppressed <- x$metadata$suppressed
  if (!is.null(suppressed) && suppressed > 0L) {
    cli::cli_alert_info(
      "{suppressed} finding{?s} muted by {.file Config/checktor}."
    )
  }
  total_issues <- x$metadata$total_issues
  if (total_issues == 0L) {
    cli::cli_alert_success("Overall health: EXCELLENT")
  } else {
    cli::cli_alert_warning(
      "Overall health: NEEDS ATTENTION ({total_issues} issue{?s})"
    )
    cli::cli_text(
      "Run {.code summary()}, {.code issues()}, or {.code prescribe()} for details"
    )
  }
  invisible(x)
}

# Human-friendly package label: the DESCRIPTION Package field if readable,
# else the directory basename.
package_label <- function(path) {
  desc <- file.path(path, "DESCRIPTION")
  if (file.exists(desc)) {
    nm <- tryCatch(
      unname(read.dcf(desc, fields = "Package")[1, 1]),
      error = function(e) NA_character_
    )
    if (!is.na(nm) && nzchar(nm)) return(nm)
  }
  basename(normalizePath(path, mustWork = FALSE))
}

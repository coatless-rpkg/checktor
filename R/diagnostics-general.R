#' Diagnose General Package Issues
#'
#' Runs general diagnostics on package structure and content that don't fit
#' into specific code, documentation, or DESCRIPTION categories.
#'
#' @details
#' This function checks:
#'
#' - Package size — measured against the files that would ship in the
#'   tarball (`.Rbuildignore` and standard scratch dirs are excluded), with
#'   a 5 MB warning threshold matching CRAN's recommendation.
#' - Invalid or problematic URLs in package files.
#'
#' @param path Character. Path to package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return List of [checktor_check_result()] objects plus a `passed` summary.
#'
#' @seealso [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' general_results <- diagnose_general_issues(pkg_path, verbose = FALSE)
#' general_results$package_size$size_mb
diagnose_general_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("General Health Check")
  }

  run_checks(list(
    package_size = diagnose_package_size,
    urls         = diagnose_urls
  ), path, verbose)
}

#' Diagnose Package Size
#'
#' Estimates the size of the source package that would be shipped to CRAN
#' (files matched by `.Rbuildignore`, plus standard scratch directories like
#' `.git`, `.Rproj.user`, are excluded). Warns at the 5 MB threshold.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`,
#'   and `size_mb`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' diagnose_package_size(pkg_path, verbose = FALSE)$size_mb
diagnose_package_size <- function(path, verbose = TRUE) {
  all_files <- list.files(path, recursive = TRUE, full.names = FALSE,
                          all.files = TRUE, no.. = TRUE)
  ignore <- build_ignore_matcher(path)
  keep <- !ignore(all_files)
  all_files <- all_files[keep]

  full <- file.path(path, all_files)
  info <- file.info(full)
  size_mb <- sum(info$size, na.rm = TRUE) / (1024^2)

  passed <- size_mb <= 5
  issues <- if (passed) character(0) else paste0(
    "Package size ", round(size_mb, 2), " MB exceeds 5 MB"
  )

  if (verbose) {
    if (passed) {
      cli::cli_alert_success(
        "Package size: {.val {round(size_mb, 2)} MB} (under 5 MB limit)"
      )
    } else {
      cli::cli_alert_warning(
        "Package size: {.val {round(size_mb, 2)} MB} (over 5 MB recommended limit)"
      )
      cli::cli_text(
        "{.emph Treatment: Reduce package size or document in cran-comments.md}"
      )
    }
  }
  checktor_check_result(passed, issues, "Package size check", size_mb = size_mb)
}

#' Diagnose URL Issues in Package Files
#'
#' Checks common package files for `http://` URLs (should usually be
#' `https://`) and known URL shortener domains.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt",
#'                                       show_content = FALSE)
#' issues(diagnose_urls(pkg_path, verbose = FALSE))
diagnose_urls <- function(path, verbose = TRUE) {
  rd_files <- list.files(file.path(path, "man"),
                         pattern = "\\.Rd$", full.names = TRUE)
  vignette_files <- list.files(file.path(path, "vignettes"),
                               pattern = "\\.(Rmd|qmd|md)$", full.names = TRUE)
  text_files <- c(
    file.path(path, "DESCRIPTION"),
    file.path(path, "README.md"),
    file.path(path, "README.Rmd"),
    vignette_files
  )
  text_files <- text_files[file.exists(text_files)]

  if (length(text_files) == 0L && length(rd_files) == 0L) {
    return(checktor_check_result(TRUE, character(0), "URLs check"))
  }

  http_re      <- "http://(?!localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0)"
  shortener_re <- "\\b(bit\\.ly|tinyurl\\.com|goo\\.gl|t\\.co|ow\\.ly)\\b"

  issues <- character(0)
  for (file in text_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0L) next
    if (any(grepl(http_re, content, perl = TRUE))) {
      issues <- c(issues,
                  paste0(basename(file), ": http:// URL (should be https://)"))
    }
    if (any(grepl(shortener_re, content, perl = TRUE))) {
      issues <- c(issues,
                  paste0(basename(file), ": URL shortener (may redirect)"))
    }
  }

  # Rd files: parse and collect prose text so URLs in macros/sections are
  # caught but Rd markup itself isn't matched.
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) next
    text <- collect_rd_text(rd)
    if (!nzchar(text)) next
    if (grepl(http_re, text, perl = TRUE)) {
      issues <- c(issues,
                  paste0(basename(file), ": http:// URL (should be https://)"))
    }
    if (grepl(shortener_re, text, perl = TRUE)) {
      issues <- c(issues,
                  paste0(basename(file), ": URL shortener (may redirect)"))
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No obvious URL issues found",
    "Potential URL issues",
    level = "warning"
  )
  checktor_check_result(passed, issues, "URLs check")
}

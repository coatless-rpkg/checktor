#' Diagnose General Package Issues
#'
#' Runs general diagnostics on package structure and content that don't
#' fit into specific code, documentation, or DESCRIPTION categories.
#'
#' @details
#' This function checks for:
#'
#' - Package size (warns if >5MB)
#' - Invalid or problematic URLs in package files
#'
#' @param path Character. Path to package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return
#' List containing results of all general diagnostics
#'
#' @seealso
#' [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' # General diagnostics with any example package
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R")
#' general_results <- diagnose_general_issues(pkg_path, verbose = TRUE)
#'
#' # Check package size
#' size_mb <- general_results$package_size$size_mb
#' cat("Example package size:", round(size_mb, 3), "MB\n")
#' cat("CRAN limit: 5 MB\n")
diagnose_general_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("General Health Check")
  }

  results <- list()

  # Check package size
  results$package_size <- diagnose_package_size(path, verbose)

  # Check for invalid URLs
  results$urls <- diagnose_urls(path, verbose)

  results$passed <- sapply(results, function(x) if(is.logical(x)) x else x$passed)

  return(results)
}

#' Diagnose Package Size
#'
#' Calculates total package size and warns if it exceeds CRAN's
#' recommended 5MB limit for packages.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return
#' List with elements:
#'
#' - `passed`: Logical, TRUE if package size <= 5MB
#' - `size_mb`: Numeric, package size in megabytes
#' - `message`: Description of the check
#'
#' @export
#' @examples
#' # Check package size calculation
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' result <- diagnose_package_size(pkg_path, verbose = TRUE)
#'
#' cat("Package size:", round(result$size_mb, 3), "MB\n")
#' cat("Within CRAN limit:", result$passed, "\n")
diagnose_package_size <- function(path, verbose) {
  # Get directory size
  all_files <- list.files(path, recursive = TRUE, full.names = TRUE)
  file_info <- file.info(all_files)
  size_mb <- sum(file_info$size, na.rm = TRUE) / (1024^2)

  passed <- size_mb <= 5
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("Package size: {.val {round(size_mb, 2)} MB} (under 5 MB limit)")
    } else {
      cli::cli_alert_warning("Package size: {.val {round(size_mb, 2)} MB} (over 5 MB recommended limit)")
      cli::cli_text("{.emph Treatment: Consider reducing package size or document in cran-comments.md}")
    }
  }

  return(list(passed = passed, size_mb = size_mb, message = "Package size check"))
}

#' Diagnose URL Issues in Package Files
#'
#' Checks common package files for problematic URLs such as `http://`
#' links (should be `https://`) and URL shorteners that may redirect.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return
#' List with elements:
#'
#' - `passed`: Logical, TRUE if no obvious URL issues found
#' - `issues`: Character vector of URL issues found
#' - `message`: Description of the check
#'
#' @examples
#' # DESCRIPTION containing http URL
#' pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt")
#' result <- diagnose_urls(pkg_path, verbose = TRUE)
#'
#' # Should detect http:// URL
#' result$passed                    # Should be FALSE
diagnose_urls <- function(path, verbose) {
  # Check URLs in common files
  files_to_check <- c(
    file.path(path, "DESCRIPTION"),
    file.path(path, "README.md"),
    file.path(path, "README.Rmd"),
    list.files(file.path(path, "man"), pattern = "\\.Rd$", full.names = TRUE),
    list.files(file.path(path, "vignettes"), pattern = "\\.(Rmd|md)$", full.names = TRUE)
  )

  files_to_check <- files_to_check[file.exists(files_to_check)]

  if (length(files_to_check) == 0) {
    return(list(passed = TRUE, message = "No files to check for URLs"))
  }

  issues <- character(0)
  for (file in files_to_check) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    # Look for http:// URLs (should be https://)
    http_lines <- grep("http://(?!localhost|127\\.0\\.0\\.1)", content, perl = TRUE)
    if (length(http_lines) > 0) {
      issues <- c(issues, paste0(basename(file), ": http:// URL (should be https://)"))
    }

    # Look for potential redirect patterns
    if (any(grepl("bit\\.ly|tinyurl|goo\\.gl", content))) {
      issues <- c(issues, paste0(basename(file), ": potential URL shortener (may redirect)"))
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No obvious URL issues found")
    } else {
      cli::cli_alert_warning("Potential URL issues")
      cli::cli_ul(utils::head(issues, 5))
      if (length(issues) > 5) {
        cli::cli_text("{.emph ... and {length(issues) - 5} more}")
      }
    }
  }

  return(list(passed = passed, issues = issues, message = "URLs check"))
}

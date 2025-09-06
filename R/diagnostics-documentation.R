#' Diagnose Documentation Issues
#'
#' Runs diagnostics on package documentation to identify common issues
#' that can cause CRAN submission problems or poor user experience.
#'
#' @details
#' This function checks for:
#' - Missing \\value tags in function documentation
#' - Roxygen2 usage patterns
#' - Example structure and appropriateness
#'
#' @param path Character. Path to package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return
#' List containing results of all documentation diagnostics
#'
#' @seealso
#' [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' # Test with example missing value tags
#' pkg_path <- example_diagnose_scenario("documentation_examples/missing_value_tag.Rd")
#' doc_results <- diagnose_documentation_issues(pkg_path, verbose = TRUE)
#'
#' # Check for missing value tags
#' doc_results$value_tags$passed  # Should be FALSE
#'
#' # Compare with good documentation
#' pkg_path_good <- example_diagnose_scenario("documentation_examples/good_documentation.Rd")
#' good_results <- diagnose_documentation_issues(pkg_path_good, verbose = FALSE)
#' good_results$value_tags$passed  # Should be TRUE
diagnose_documentation_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("Documentation Health Check")
  }

  results <- list()

  # Check for missing \\value tags
  results$value_tags <- diagnose_value_tags(path, verbose)

  # Check roxygen2 usage
  results$roxygen_usage <- diagnose_roxygen_usage(path, verbose)

  # Check example structure
  results$example_structure <- diagnose_example_structure(path, verbose)

  results$passed <- sapply(results, function(x) if(is.logical(x)) x else x$passed)

  return(results)
}

#' Diagnose Missing Value Tags in Documentation
#'
#' @description
#' Checks .Rd files for missing \\value tags in function documentation.
#' CRAN requires that all exported functions document their return values.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return
#' List with elements:
#' - `passed`: Logical, TRUE if all functions have \\value tags
#' - `missing`: Character vector of .Rd files missing \\value tags
#' - `message`: Description of the check
#'
#' @export
#' @examples
#' # Test with documentation missing value tags
#' pkg_path <- example_diagnose_scenario("documentation_examples/missing_value_tag.Rd")
#' result <- diagnose_value_tags(pkg_path, verbose = TRUE)
#'
#' # Check results
#' result$passed                    # Should be FALSE
diagnose_value_tags <- function(path, verbose) {
  rd_files <- list.files(file.path(path, "man"), pattern = "\\.Rd$", full.names = TRUE)
  if (length(rd_files) == 0) {
    if (verbose) cli::cli_alert_info("No .Rd files found")
    return(list(passed = TRUE, message = "No .Rd files found"))
  }

  missing_value <- character(0)
  for (file in rd_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    # Skip if it's a data documentation
    if (any(grepl("\\\\docType\\{data\\}", content))) next

    # Check for \\value tag
    if (!any(grepl("\\\\value", content))) {
      missing_value <- c(missing_value, basename(file))
    }
  }

  passed <- length(missing_value) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("All function documentation has {.code \\\\value} tags")
    } else {
      cli::cli_alert_danger("Missing {.code \\\\value} tags in")
      cli::cli_ul(utils::head(missing_value, 5))
      if (length(missing_value) > 5) {
        cli::cli_text("{.emph ... and {length(missing_value) - 5} more}")
      }
    }
  }

  return(list(passed = passed, missing = missing_value, message = "Value tags check"))
}

#' Diagnose Roxygen2 Usage Patterns
#'
#' Detects whether the package uses Roxygen2 for documentation generation
#' and provides guidance for CRAN submission preparation.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return
#' List with elements:
#'
#' - `passed`: Logical, always TRUE (informational check)
#' - `has_roxygen`: Logical, TRUE if Roxygen2 comments detected
#' - `message`: Description of the check
#'
#' @export
#' @examples
#' # Test Roxygen2 detection
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R")
#' result <- diagnose_roxygen_usage(pkg_path, verbose = TRUE)
diagnose_roxygen_usage <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE)
  if (length(r_files) == 0) {
    return(list(passed = TRUE, message = "No R files found"))
  }

  has_roxygen <- FALSE
  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) > 0 && any(grepl("^\\s*#'", content))) {
      has_roxygen <- TRUE
      break
    }
  }

  if (verbose) {
    if (has_roxygen) {
      cli::cli_alert_info("Roxygen2 usage detected - ensure to run {.code roxygenize()} before submission")
    } else {
      cli::cli_alert_info("No Roxygen2 usage detected")
    }
  }

  return(list(passed = TRUE, has_roxygen = has_roxygen, message = "Roxygen usage check"))
}

#' Diagnose Example Structure in Documentation
#'
#' Checks for appropriate use of \\dontrun in examples, ensuring it's
#' only used when necessary (interactive functions, API calls, etc.).
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return
#' List with elements:
#'
#' - `passed`: Logical, TRUE if example structure appears appropriate
#' - `issues`: Character vector of potential example issues
#' - `message`: Description of the check
#'
#' @export
#' @examples
#' # Test with network example
#' pkg_path <- example_diagnose_scenario("network_examples/bad_network_example.Rd")
#' result <- diagnose_example_structure(pkg_path, verbose = TRUE)
diagnose_example_structure <- function(path, verbose) {
  rd_files <- list.files(file.path(path, "man"), pattern = "\\.Rd$", full.names = TRUE)
  if (length(rd_files) == 0) {
    return(list(passed = TRUE, message = "No .Rd files found"))
  }

  issues <- character(0)
  for (file in rd_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    # Find examples section
    example_start <- grep("\\\\examples\\{", content)
    if (length(example_start) == 0) next

    # Check for problematic patterns
    if (any(grepl("\\\\dontrun", content))) {
      # Check if it's appropriate (look for interactive, API, etc.)
      example_content <- paste(content[example_start:length(content)], collapse = " ")
      if (!grepl("interactive|API|password|token|key", example_content, ignore.case = TRUE)) {
        issues <- c(issues, paste0(basename(file), ": potential unnecessary \\dontrun"))
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("Example structure appears appropriate")
    } else {
      cli::cli_alert_warning("Potential example structure issues")
      cli::cli_ul(issues)
    }
  }

  return(list(passed = passed, issues = issues, message = "Example structure check"))
}

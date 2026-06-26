#' Create Example Diagnostic Scenario
#'
#' Creates a temporary package structure with a specified example file for
#' testing diagnostic functions. This is primarily used in documentation
#' examples to demonstrate diagnostic capabilities with known problematic code.
#'
#' @param example_path Character. Relative path to example file within
#'   inst/diagnose/. Should include subdirectory and filename
#'   (e.g., "code_examples/tf_usage_bad.R").
#' @param show_content Logical. Whether to display the example file content
#'   in the console. Default: `TRUE`.
#' @param description_type Character. Type of DESCRIPTION file to create.
#'   Options: "minimal" (basic fields only), "bad" (with known issues),
#'   "good" (properly formatted). Default: "minimal".
#' @param cleanup Logical. Whether to register cleanup of temporary directory
#'   on exit. Default: `FALSE` (user manages cleanup).
#'
#' @return
#' Character. Path to the temporary package directory containing the example
#' file. Returns `NULL` if the example file cannot be found.
#'
#' @details
#' This function:
#'
#' 1. Locates the specified example file in the package's `inst/diagnose/` directory
#' 2. Creates a temporary package directory structure
#' 3. Copies the example file to the appropriate location
#' 4. Optionally displays the example file content
#' 5. Returns the path to the temporary package for diagnostic testing
#'
#' The temporary package includes minimal structure (`R/`, `man/`, etc.) needed
#' for running diagnostics, plus a basic `DESCRIPTION` file.
#'
#' @section Example File Structure:
#'
#' The temporary package created has this structure:
#'
#' ```
#' /tmp/checktor_example_XXXX/
#' |-- DESCRIPTION          # Basic or custom DESCRIPTION file
#' |-- R/                   # Contains copied example R files
#' |   `-- example.R        # The example file with issues
#' |-- man/                 # Empty directory for .Rd files
#' `-- tests/               # Empty directory for test files
#' ```
#'
#' @seealso
#' Used in examples for diagnostic functions like [diagnose_tf_usage()],
#' [diagnose_seed_setting()], etc.
#'
#' @export
#' @examples
#' # Create scenario with T/F usage issues
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R")
#' result <- diagnose_tf_usage(pkg_path, verbose = TRUE)
#' issues(checktor(pkg_path, verbose = FALSE, progress = FALSE))
#'
#' # Create scenario without showing file content
#' pkg_path <- example_diagnose_scenario("code_examples/seed_setting_bad.R",
#'                                       show_content = FALSE)
#'
#' # Create scenario with problematic DESCRIPTION file
#' pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt",
#'                                       description_type = "bad")
#' desc_result <- diagnose_description_issues(pkg_path)
#'
#' # Manual cleanup when done
#' unlink(pkg_path, recursive = TRUE)
#'
#' # Or use with automatic cleanup
#' pkg_path <- example_diagnose_scenario("code_examples/browser_calls_bad.R",
#'                                       cleanup = TRUE)
#' # Cleanup happens automatically when R session ends
example_diagnose_scenario <- function(example_path,
                                      show_content = TRUE,
                                      description_type = "minimal",
                                      cleanup = FALSE) {

  # Validate input
  if (missing(example_path) || !is.character(example_path) || length(example_path) != 1) {
    stop("example_path must be a single character string")
  }

  # Find the example file
  example_file <- system.file("diagnose", example_path, package = "checktor")

  if (!file.exists(example_file)) {
    warning("Example file not found: ", example_path)
    return(NULL)
  }

  # Create temporary package directory
  temp_pkg <- file.path(tempdir(), paste0("checktor_example_",
                                          format(Sys.time(), "%Y%m%d_%H%M%S_"),
                                          sample(1000:9999, 1)))

  # Create package structure
  dir.create(temp_pkg, recursive = TRUE)
  dir.create(file.path(temp_pkg, "R"), recursive = TRUE)
  dir.create(file.path(temp_pkg, "man"), recursive = TRUE)
  dir.create(file.path(temp_pkg, "tests"), recursive = TRUE)

  # Determine target location based on file type
  if (grepl("description_examples", example_path, ignore.case = TRUE)) {
    # DESCRIPTION files go to package root
    target_file <- file.path(temp_pkg, "DESCRIPTION")
    file.copy(example_file, target_file)
  } else if (grepl("documentation_examples", example_path, ignore.case = TRUE)) {
    # .Rd files go to man/
    target_file <- file.path(temp_pkg, "man", basename(example_file))
    file.copy(example_file, target_file)
  } else {
    # R code files go to R/
    target_file <- file.path(temp_pkg, "R", basename(example_file))
    file.copy(example_file, target_file)
  }

  # Create DESCRIPTION file if not already created from example
  desc_path <- file.path(temp_pkg, "DESCRIPTION")
  if (!file.exists(desc_path)) {
    create_example_description(desc_path, description_type)
  }

  # Standard CRAN-prep files so the scenario isolates the single injected
  # issue (the general NEWS/cran-comments checks would otherwise also fire).
  writeLines(c("# examplepackage 0.1.0", "", "* Initial scenario."),
             file.path(temp_pkg, "NEWS.md"))
  writeLines(c("## Test environments", "* local"),
             file.path(temp_pkg, "cran-comments.md"))

  # Show file content if requested
  if (show_content) {
    cat("=== Example file:", basename(example_file), "===\n")
    if (file.exists(target_file)) {
      content <- readLines(target_file)
      cat(content, sep = "\n")
      cat("\n=== End of example ===\n\n")
    }
  }

  if (cleanup) {
    defer_cleanup(temp_pkg, envir = parent.frame())
  }

  # Inform user about temporary package location
  if (show_content) {
    cat("Temporary package created at:", temp_pkg, "\n")
    cat("Example file copied to:", target_file, "\n\n")
  }

  return(temp_pkg)
}

# Helper function to create different types of DESCRIPTION files
create_example_description <- function(desc_path, type = "minimal") {

  desc_content <- switch(type,
                         "minimal" = c(
                           "Package: examplepackage",
                           "Title: Example Package for Diagnostic Testing",
                           "Version: 0.1.0",
                           "Authors@R: person('Test', 'User', email = 'test@example.com', role = c('aut', 'cre'))",
                           "Description: This is a temporary package created for testing checktor",
                           "    diagnostic functions with example code that contains known issues.",
                           "License: MIT",
                           "Encoding: UTF-8",
                           "Depends: R (>= 3.5.0)"
                         ),

                         "bad" = c(
                           "Package: badexample",
                           "Title: example package for testing",  # Issues: not title case
                           "Version: 0.1.0",
                           "Author: Test User <test@example.com>",  # Issue: should use Authors@R
                           "Maintainer: Test User <test@example.com>",
                           "Description: This package works with ggplot2 and provides API access.",  # Issues: no quotes, short
                           "License: MIT + file LICENSE",  # Issue: unnecessary for standard MIT
                           "Encoding: UTF-8",
                           "URL: http://example.com"  # Issue: should be https
                         ),

                         "good" = c(
                           "Package: goodexample",
                           "Title: Example Package for Comprehensive Diagnostic Testing",
                           "Version: 0.1.0",
                           "Authors@R: person('Test', 'User', email = 'test@example.com', role = c('aut', 'cre'))",
                           "Description: This package demonstrates proper formatting for CRAN submission.",
                           "    It works with 'ggplot2' and provides Application Programming Interface (API)",
                           "    access. The package serves as an example of best practices for R package",
                           "    development and CRAN compliance.",
                           "License: MIT",
                           "Encoding: UTF-8",
                           "URL: https://example.com",
                           "BugReports: https://github.com/user/pkg/issues"
                         ),

                         # Default to minimal
                         c(
                           "Package: examplepackage",
                           "Title: Example Package for Diagnostic Testing",
                           "Version: 0.1.0",
                           "Authors@R: person('Test', 'User', email = 'test@example.com', role = c('aut', 'cre'))",
                           "Description: Temporary package for testing diagnostics.",
                           "License: MIT",
                           "Encoding: UTF-8"
                         )
  )

  writeLines(desc_content, desc_path)
}

#' Show Available Example Files
#'
#' Lists all available example files in the `inst/diagnose/` directory that
#' can be used with [example_diagnose_scenario()].
#'
#' @param category Character. Optional category filter. One of "code",
#'   "description", "documentation", "network", "temp", or "all".
#'   Default: "all".
#' @param pattern Character. Optional regex pattern to filter filenames.
#'   Default: `NULL` (no filtering).
#'
#' @return
#' Character vector of relative paths to example files that can be used
#' with [example_diagnose_scenario()].
#'
#' @seealso
#' [example_diagnose_scenario()] to create test scenarios with these files
#'
#' @export
#' @examples
#' # List all available examples
#' show_example_files()
#'
#' # List only code examples
#' show_example_files("code")
#'
#' # List files matching a pattern
#' show_example_files(pattern = "bad")
#'
#' # Use with example_diagnose_scenario
#' examples <- show_example_files("code")
#' pkg_path <- example_diagnose_scenario(examples[1])
show_example_files <- function(category = "all", pattern = NULL) {

  base_path <- system.file("diagnose", package = "checktor")

  if (!dir.exists(base_path)) {
    message("No example files found. Package may not be properly installed.")
    return(character(0))
  }

  # Get all files recursively
  all_files <- list.files(base_path, recursive = TRUE, full.names = FALSE)

  # Filter by category if specified
  if (category != "all") {
    category_pattern <- switch(category,
                               "code" = "^code_examples/",
                               "description" = "^description_examples/",
                               "documentation" = "^documentation_examples/",
                               "network" = "^network_examples/",
                               "temp" = "^temp_examples/",
                               ".*"  # Default: include all
    )
    all_files <- all_files[grepl(category_pattern, all_files)]
  }

  # Filter by pattern if specified
  if (!is.null(pattern)) {
    all_files <- all_files[grepl(pattern, all_files)]
  }

  # Sort for consistent output
  sort(all_files)
}

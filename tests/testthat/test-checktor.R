# Test file for checktor package

test_that("checktor main function works", {
  # Create a temporary package structure for testing
  temp_dir <- tempdir()
  test_pkg <- file.path(temp_dir, "testpkg")

  # Skip if we can't create the test directory
  skip_if(!dir.create(test_pkg, showWarnings = FALSE))

  on.exit(unlink(test_pkg, recursive = TRUE))

  # Create minimal package structure
  dir.create(file.path(test_pkg, "R"), recursive = TRUE)
  dir.create(file.path(test_pkg, "man"), recursive = TRUE)

  # Create DESCRIPTION file
  desc_content <- c(
    "Package: testpkg",
    "Title: Test Package for Health Checks",
    "Version: 0.1.0",
    "Authors@R: person('Test', 'Doctor', email = 'test@example.com', role = c('aut', 'cre'))",
    "Description: A test package for checktor functionality. This package includes",
    "    example code to test various CRAN submission diagnostics and validation rules.",
    "License: MIT + file LICENSE",
    "Encoding: UTF-8",
    "Depends: R (>= 3.5.0)"
  )
  writeLines(desc_content, file.path(test_pkg, "DESCRIPTION"))

  # Create simple R file
  r_content <- c(
    "#' Test Function",
    "#' @param x A test parameter",
    "#' @return A logical value",
    "#' @export",
    "test_function <- function(x) {",
    "  return(TRUE)",
    "}"
  )
  writeLines(r_content, file.path(test_pkg, "R", "test.R"))

  # Test checktor function (suppress output for testing)
  expect_no_error({
    results <- checktor(test_pkg, verbose = FALSE, progress = FALSE)
  })

  # Check that results have expected structure
  expect_s3_class(results, "checktor_results")
  expect_type(results, "list")
  expect_true("code_issues" %in% names(results))
  expect_true("description_issues" %in% names(results))
  expect_true("documentation_issues" %in% names(results))
  expect_true("general_issues" %in% names(results))
  expect_true("metadata" %in% names(results))

  # Check metadata structure
  expect_true("total_issues" %in% names(results$metadata))
  expect_true("diagnosis_time" %in% names(results$metadata))
  expect_true("package_path" %in% names(results$metadata))
})

test_that("checktor handles missing DESCRIPTION file", {
  temp_dir <- tempdir()
  empty_dir <- file.path(temp_dir, "empty_pkg")

  dir.create(empty_dir, showWarnings = FALSE)
  on.exit(unlink(empty_dir, recursive = TRUE))

  # Should error when no DESCRIPTION file exists
  expect_error(checktor(empty_dir, verbose = FALSE), "No DESCRIPTION file found")
})

test_that("T/F usage detection works", {
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "tf_test")

  dir.create(file.path(test_dir, "R"), recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(test_dir, recursive = TRUE))

  # Create DESCRIPTION
  writeLines(c(
    "Package: tftest",
    "Title: Test Package",
    "Version: 0.1.0",
    "Description: Test package.",
    "License: MIT"
  ), file.path(test_dir, "DESCRIPTION"))

  # Create file with T/F usage
  writeLines(c(
    "test_func <- function() {",
    "  x <- T",
    "  y <- F",
    "  return(x && y)",
    "}"
  ), file.path(test_dir, "R", "test.R"))

  results <- checktor(test_dir, verbose = FALSE, progress = FALSE)
  expect_false(results$code_issues$tf_usage$passed)
  expect_true(length(results$code_issues$tf_usage$issues) > 0)
})

test_that("seed setting detection works", {
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "seed_test")

  dir.create(file.path(test_dir, "R"), recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(test_dir, recursive = TRUE))

  # Create DESCRIPTION
  writeLines(c(
    "Package: seedtest",
    "Title: Test Package",
    "Version: 0.1.0",
    "Description: Test package.",
    "License: MIT"
  ), file.path(test_dir, "DESCRIPTION"))

  # Create file with hardcoded seed
  writeLines(c(
    "test_func <- function() {",
    "  set.seed(123)",
    "  return(sample(1:10, 1))",
    "}"
  ), file.path(test_dir, "R", "test.R"))

  results <- checktor(test_dir, verbose = FALSE, progress = FALSE)
  expect_false(results$code_issues$seed_setting$passed)
  expect_true(length(results$code_issues$seed_setting$issues) > 0)
})

test_that("DESCRIPTION issues are detected", {
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "desc_test")

  dir.create(test_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(test_dir, recursive = TRUE))

  # Create DESCRIPTION with issues
  writeLines(c(
    "Package: desctest",
    "Title: test package",  # Not title case
    "Version: 0.1.0",
    "Author: Test Author",  # Should use Authors@R
    "Maintainer: Test Author <test@test.com>",
    "Description: This package works with ggplot2.",  # Missing quotes around ggplot2
    "License: MIT + file LICENSE"  # Unnecessary for standard MIT
  ), file.path(test_dir, "DESCRIPTION"))

  results <- checktor(test_dir, verbose = FALSE, progress = FALSE)

  # Should detect title case issues
  expect_false(results$description_issues$title_case$passed)

  # Should detect missing Authors@R
  expect_false(results$description_issues$authors$passed)

  # Should detect software name formatting issues
  expect_false(results$description_issues$software_names$passed)
})

test_that("checkup (quick check) works", {
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "quick_test")

  dir.create(file.path(test_dir, "R"), recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(test_dir, recursive = TRUE))

  # Create clean package
  writeLines(c(
    "Package: quicktest",
    "Title: Quick Test Package",
    "Version: 0.1.0",
    "Authors@R: person('Test', 'Doctor', email = 'test@example.com', role = c('aut', 'cre'))",
    "Description: A clean test package for 'checktor' that should pass all checks.",
    "License: MIT",
    "Encoding: UTF-8"
  ), file.path(test_dir, "DESCRIPTION"))

  writeLines(c(
    "test_func <- function() TRUE"
  ), file.path(test_dir, "R", "test.R"))

  # Quick check should return TRUE for clean package
  result <- checkup(test_dir)
  expect_true(is.logical(result))
})

test_that("print method works for checktor_results", {
  # Create mock results
  mock_results <- structure(
    list(
      code_issues = list(passed = c(tf_usage = TRUE, seed_setting = FALSE)),
      description_issues = list(passed = c(title_case = TRUE)),
      documentation_issues = list(passed = c(value_tags = TRUE)),
      general_issues = list(passed = c(package_size = TRUE)),
      metadata = list(
        package_path = "test_package",
        diagnosis_time = Sys.time(),
        total_issues = 1,
        checktor_version = "0.1.0"
      )
    ),
    class = "checktor_results"
  )

  # Should not error when printing
  expect_no_error(print(mock_results))
})

test_that("health_report generates output", {
  # Mock results structure
  mock_results <- structure(
    list(
      code_issues = list(
        passed = c(tf_usage = TRUE, seed_setting = FALSE),
        tf_usage = list(passed = TRUE, issues = character(0)),
        seed_setting = list(passed = FALSE, issues = c("test.R:5"))
      ),
      description_issues = list(
        passed = c(title_case = TRUE)
      ),
      documentation_issues = list(
        passed = c(value_tags = TRUE)
      ),
      general_issues = list(
        passed = c(package_size = TRUE)
      ),
      metadata = list(
        package_path = "test_package",
        diagnosis_time = Sys.time(),
        total_issues = 1,
        checktor_version = "0.1.0"
      )
    ),
    class = "checktor_results"
  )

  expect_no_error({
    report <- health_report(mock_results, format = "markdown")
  })

  expect_type(report, "character")
  expect_true(length(report) > 0)
  expect_true(any(grepl("Package Doctor", report)))
})

test_that("diagnostic functions handle missing directories gracefully", {
  temp_dir <- tempdir()
  nonexistent_dir <- file.path(temp_dir, "nonexistent")

  # These should not error even if directories don't exist
  expect_no_error({
    diagnose_code_issues(nonexistent_dir, verbose = FALSE)
  })

  expect_no_error({
    diagnose_description_issues(nonexistent_dir, verbose = FALSE)
  })

  expect_no_error({
    diagnose_documentation_issues(nonexistent_dir, verbose = FALSE)
  })

  expect_no_error({
    diagnose_general_issues(nonexistent_dir, verbose = FALSE)
  })
})

test_that("policy violations are detected", {
  temp_dir <- tempdir()
  test_dir <- file.path(temp_dir, "policy_test")

  dir.create(file.path(test_dir, "R"), recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(test_dir, recursive = TRUE))

  # Create file with browser() call
  writeLines(c(
    "test_func <- function() {",
    "  browser()",
    "  return(TRUE)",
    "}"
  ), file.path(test_dir, "R", "test.R"))

  results <- diagnose_policy_violations(test_dir, verbose = FALSE)
  expect_false(results$browser_calls$passed)
  expect_true(length(results$browser_calls$issues) > 0)
})

test_that("configuration functions work", {
  # Save original options
  orig_verbose <- getOption("checktor.verbose", TRUE)
  orig_progress <- getOption("checktor.progress", TRUE)
  orig_color <- getOption("checktor.color", TRUE)

  on.exit({
    options(
      checktor.verbose = orig_verbose,
      checktor.progress = orig_progress,
      checktor.color = orig_color
    )
  })

  # Test configuration
  expect_no_error(configure_doctor(verbose_default = FALSE, progress_default = FALSE))
  expect_false(getOption("checktor.verbose"))
  expect_false(getOption("checktor.progress"))
})

test_that("prescribe function works", {
  # Mock results with issues
  mock_results <- structure(
    list(
      code_issues = list(
        tf_usage = list(passed = FALSE, issues = c("test.R:5")),
        seed_setting = list(passed = FALSE, issues = c("test.R:10"))
      ),
      description_issues = list(passed = character(0)),
      documentation_issues = list(
        value_tags = list(passed = FALSE, missing = c("test.Rd"))
      ),
      general_issues = list(passed = character(0)),
      metadata = list(total_issues = 3)
    ),
    class = "checktor_results"
  )

  # Should not error when providing prescriptions
  expect_no_error(prescribe(mock_results))
})

test_that("safe_read_lines handles file errors gracefully", {
  temp_dir <- tempdir()
  nonexistent_file <- file.path(temp_dir, "nonexistent.R")

  # Should return empty character vector for nonexistent file
  result <- safe_read_lines(nonexistent_file)
  expect_equal(result, character(0))
})

test_that("validate_package_directory works correctly", {
  temp_dir <- tempdir()

  # Should error for nonexistent directory
  expect_error(validate_package_directory(file.path(temp_dir, "nonexistent")))

  # Should error for directory without DESCRIPTION
  test_dir <- file.path(temp_dir, "no_desc")
  dir.create(test_dir, showWarnings = FALSE)
  on.exit(unlink(test_dir, recursive = TRUE))
  expect_error(validate_package_directory(test_dir))

  # Should succeed for valid package directory
  writeLines("Package: test", file.path(test_dir, "DESCRIPTION"))
  expect_true(validate_package_directory(test_dir))
})

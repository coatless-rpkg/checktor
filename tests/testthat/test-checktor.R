test_that("checktor returns a checktor_results object with all categories", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  results <- checktor(pkg, verbose = FALSE, progress = FALSE)

  expect_s3_class(results, "checktor_results")
  for (cat in c("code_issues", "description_issues", "documentation_issues",
                "general_issues", "policy_issues", "metadata")) {
    expect_true(cat %in% names(results), info = cat)
  }
  expect_true(all(c("total_issues", "failed_checks", "diagnosis_time",
                    "package_path", "checktor_version") %in%
                    names(results$metadata)))
})

test_that("a clean package has zero issues", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  expect_true(checkup(pkg))
  results <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_equal(results$metadata$total_issues, 0L)
  expect_equal(results$metadata$failed_checks, 0L)
})

test_that("total_issues counts every individual issue, not failed checks", {
  pkg <- make_temp_dir()
  # Three distinct T/F issues on three lines plus one hardcoded seed
  r_code <- c(
    "f1 <- function() T",
    "f2 <- function() F",
    "f3 <- function() T",
    "f4 <- function() { set.seed(42); runif(1) }"
  )
  write_pkg(pkg, r_code = r_code)

  results <- checktor(pkg, verbose = FALSE, progress = FALSE)

  # 3 T/F + 1 seed = 4 issues across 2 failing checks (at minimum).
  expect_gte(results$metadata$total_issues, 4L)
  expect_gte(results$metadata$failed_checks, 2L)
  expect_lt(results$metadata$failed_checks,
            results$metadata$total_issues)
})

test_that("policy violations are part of the main run", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c("f <- function() { browser(); 1 }"))

  results <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_true("policy_issues" %in% names(results))
  expect_false(results$policy_issues$browser_calls$passed)
})

test_that("checktor errors clearly on a non-package directory", {
  empty <- make_temp_dir()
  expect_error(checktor(empty, verbose = FALSE),
               "No DESCRIPTION file found")
})

test_that("diagnose_* functions tolerate missing R/man directories", {
  empty <- make_temp_dir()
  expect_no_error(diagnose_code_issues(empty, verbose = FALSE))
  expect_no_error(diagnose_documentation_issues(empty, verbose = FALSE))
  expect_no_error(diagnose_general_issues(empty, verbose = FALSE))
  expect_no_error(diagnose_policy_violations(empty, verbose = FALSE))
})

test_that("a check whose function errors surfaces as a failure", {
  # Stub a diagnostic that always throws; check that the orchestrator records
  # it as a failure with a non-empty message rather than silently dropping it.
  with_mocked_bindings(
    diagnose_tf_usage = function(path, verbose = TRUE, parsed = NULL) {
      stop("synthetic")
    },
    code = {
      pkg <- make_temp_dir()
      write_pkg(pkg)
      res <- diagnose_code_issues(pkg, verbose = FALSE)
      expect_false(res$tf_usage$passed)
      expect_true(grepl("synthetic", res$tf_usage$issues))
    }
  )
})

test_that("print.checktor_results runs without error", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  results <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_no_error(print(results))
})

test_that("configure_doctor changes the defaults consumed by checktor", {
  orig <- options(checktor.verbose = NULL, checktor.progress = NULL)
  on.exit(options(orig), add = TRUE)

  configure_doctor(verbose_default = FALSE, progress_default = FALSE)
  expect_false(getOption("checktor.verbose"))
  expect_false(getOption("checktor.progress"))

  # Default args of checktor() should now resolve to FALSE
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_no_error(checktor(pkg))     # would print/progress if defaults ignored
})

test_that("validate_package_directory enforces DESCRIPTION presence", {
  empty <- make_temp_dir()
  expect_error(validate_package_directory(empty), "DESCRIPTION")

  writeLines("Package: stub", file.path(empty, "DESCRIPTION"))
  expect_true(validate_package_directory(empty))
})

test_that("safe_read_lines handles missing files", {
  expect_equal(safe_read_lines(file.path(tempdir(), "definitely-missing.R")),
               character(0))
})

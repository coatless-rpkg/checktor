# Test checktor() ----

test_that("checktor(): returns a checktor_results object with all categories", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  results <- checktor(pkg, verbose = FALSE, progress = FALSE)

  expect_s3_class(results, "checktor_results")
  for (cat in c(
    "code_issues",
    "description_issues",
    "documentation_issues",
    "general_issues",
    "policy_issues",
    "metadata"
  )) {
    expect_true(cat %in% names(results), info = cat)
  }
  expect_true(all(
    c(
      "total_issues",
      "failed_checks",
      "diagnosis_time",
      "package_path",
      "checktor_version"
    ) %in%
      names(results$metadata)
  ))
})

test_that("checktor(): a clean package has zero issues", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  expect_true(checkup(pkg))
  results <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_equal(results$metadata$total_issues, 0L)
  expect_equal(results$metadata$failed_checks, 0L)
})

test_that("checktor(): total_issues counts every issue, not failed checks", {
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
  expect_lt(results$metadata$failed_checks, results$metadata$total_issues)
})

test_that("checktor(): policy violations are part of the main run", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c("f <- function() { browser(); 1 }"))

  results <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_true("policy_issues" %in% names(results))
  expect_false(results$policy_issues$browser_calls$passed)
})

test_that("checktor(): errors clearly on a non-package directory", {
  empty <- make_temp_dir()
  expect_error(checktor(empty, verbose = FALSE), "No DESCRIPTION file found")
})

# Test diagnose_code_issues() ----

test_that("diagnose_code_issues(): tolerates missing R/ and man/", {
  empty <- make_temp_dir()
  expect_no_error(diagnose_code_issues(empty, verbose = FALSE))
  expect_no_error(diagnose_documentation_issues(empty, verbose = FALSE))
  expect_no_error(diagnose_general_issues(empty, verbose = FALSE))
  expect_no_error(diagnose_policy_violations(empty, verbose = FALSE))
})

test_that("diagnose_code_issues(): a check that errors surfaces as a failure", {
  # Stub a diagnostic that always throws; check that the orchestrator records
  # it as a failure with a non-empty message rather than silently dropping it.
  with_mocked_bindings(
    lab_tf_usage = function(path, verbose = TRUE, parsed = NULL) {
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

# Test print.checktor_results() ----

test_that("print.checktor_results(): runs without error", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  results <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_no_error(cli::cli_fmt(print(results)))
})

# Test print.checktor_check_result() ----

test_that("print.checktor_check_result(): prints issue text literally", {
  res <- checktor_check_result(
    FALSE,
    "Title: Tools for {stop('evaluated')} Users",
    "Title case check"
  )
  out <- NULL
  expect_no_error(out <- cli::cli_fmt(print(res)))
  expect_match(
    paste(out, collapse = "\n"),
    "Tools for {stop('evaluated')} Users",
    fixed = TRUE
  )
})

test_that("print.checktor_check_result(): shows a skipped check as skipped (#15)", {
  res <- checktor_skipped_result("URL liveness check", "runs at the console")
  out <- paste(cli::cli_fmt(print(res)), collapse = "\n")
  expect_match(out, "URL liveness check: SKIPPED (runs at the console)", fixed = TRUE)
  expect_false(grepl("PASSED", out, fixed = TRUE))
})

# Test print.checktor_category_result() ----

test_that("print.checktor_category_result(): a skipped check is not a pass (#15)", {
  cat_res <- checktor_category_result(
    url_liveness = checktor_skipped_result("URL liveness check", "offline"),
    tf_usage = checktor_check_result(TRUE, character(0), "T/F usage check")
  )
  out <- paste(cli::cli_fmt(print(cat_res)), collapse = "\n")
  expect_false(grepl("All 2 checks passed", out, fixed = TRUE))
  expect_match(out, "1 of 2 checks passed", fixed = TRUE)
  expect_match(out, "1 check did not run: \"url_liveness\"", fixed = TRUE)
})

test_that("print.checktor_category_result(): names skipped checks beside failures", {
  cat_res <- checktor_category_result(
    url_liveness = checktor_skipped_result("URL liveness check", "offline"),
    tf_usage = checktor_check_result(FALSE, "a.R:1", "T/F usage check")
  )
  out <- paste(cli::cli_fmt(print(cat_res)), collapse = "\n")
  expect_match(out, "1 of 2 checks failed", fixed = TRUE)
  expect_match(out, "tf_usage: 1 issue", fixed = TRUE)
  expect_false(grepl("url_liveness: 0 issues", out, fixed = TRUE))
  expect_match(out, "1 check did not run: \"url_liveness\"", fixed = TRUE)
})

test_that("print.checktor_category_result(): keeps an early return's verdict", {
  # A category that stops before running anything, such as one without a
  # DESCRIPTION, carries only its own verdict.
  early <- structure(
    list(passed = FALSE, message = "DESCRIPTION file not found"),
    class = "checktor_category_result"
  )
  out <- paste(cli::cli_fmt(print(early)), collapse = "\n")
  expect_match(out, "1 of 1 checks failed", fixed = TRUE)
  expect_false(grepl("NA:", out, fixed = TRUE))
})

test_that("print.checktor_category_result(): no tick when nothing ran", {
  cat_res <- checktor_category_result(
    url_liveness = checktor_skipped_result("URL liveness check", "offline")
  )
  line <- grep("0 of 1 checks passed", cli::cli_fmt(print(cat_res)), value = TRUE)
  expect_length(line, 1L)
  expect_false(grepl("^(v|\u2714) ", line))
})

test_that("print.checktor_check_result(): a failure marked skipped is a failure", {
  # A check registered with register_check() can set skipped by hand. Whatever it
  # claims, a failed check is a failure, as the verdict already counts it.
  res <- checktor_check_result(FALSE, "z.R:1", "House rule", skipped = TRUE)
  out <- paste(cli::cli_fmt(print(res)), collapse = "\n")
  expect_match(out, "House rule: FAILED", fixed = TRUE)
  expect_match(out, "z.R:1", fixed = TRUE)
})

# Test configure_doctor() ----

test_that("configure_doctor(): changes the defaults consumed by checktor", {
  # configure_doctor() also sets cli.num_colors, so that is restored too.
  withr::local_options(
    checktor.verbose = NULL,
    checktor.progress = NULL,
    cli.num_colors = getOption("cli.num_colors")
  )

  expect_message(
    configure_doctor(verbose_default = FALSE, progress_default = FALSE),
    "configuration updated"
  )
  expect_false(getOption("checktor.verbose"))
  expect_false(getOption("checktor.progress"))

  # Default args of checktor() should now resolve to FALSE. cli output is a
  # message, not an error, so expect_no_error() would stay green through a run
  # that printed all of its diagnostics. Silence is the only proof.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_length(cli::cli_fmt(checktor(pkg)), 0L)
})

# Test validate_package_directory() ----

test_that("validate_package_directory(): enforces DESCRIPTION presence", {
  empty <- make_temp_dir()
  expect_error(validate_package_directory(empty), "DESCRIPTION")

  writeLines("Package: stub", file.path(empty, "DESCRIPTION"))
  expect_true(validate_package_directory(empty))
})

# Test safe_read_lines() ----

test_that("safe_read_lines(): handles missing files", {
  expect_equal(
    safe_read_lines(file.path(tempdir(), "definitely-missing.R")),
    character(0)
  )
})

# Test prescribe() ----

test_that("prescribe(): surfaces failed checks with no curated treatment", {
  # A package whose only defect is a missing NEWS file. The news_file check has
  # no entry in the curated `treatments` list, so before the fix prescribe()
  # printed only its header and stayed silent about the actual problem (#4).
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)

  res <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false(res$general_issues$passed[["news_file"]]) # sanity

  out <- cli::cli_fmt(prescribe(res))
  txt <- paste(out, collapse = "\n")
  # Match the ISSUE, not the heading: "NEWS" alone is satisfied by the
  # "NEWS file check" header that #4 was filed about.
  expect_match(txt, "No NEWS file found", fixed = TRUE)
})

test_that("prescribe(): prints uncurated issue text literally", {
  # The fallback lists the check's own issues, which quote the package. news_file
  # has no curated treatment, so its failure takes that path.
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  res <- checktor(pkg, verbose = FALSE, progress = FALSE)
  res$general_issues$news_file$issues <- "NEWS.md mentions {stop('evaluated')}"

  out <- NULL
  expect_no_error(out <- cli::cli_fmt(prescribe(res)))
  expect_match(
    paste(out, collapse = "\n"),
    "NEWS.md mentions {stop('evaluated')}",
    fixed = TRUE
  )
})

test_that("prescribe(): prints an uncurated check's heading literally", {
  # The heading is the check's message. A check added with register_check() may
  # build it from the package, e.g. naming the Title a house rule rejected.
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  res <- checktor(pkg, verbose = FALSE, progress = FALSE)
  res$general_issues$news_file$message <- "House rule for {stop('evaluated')}"

  out <- NULL
  expect_no_error(out <- cli::cli_fmt(prescribe(res)))
  expect_match(
    paste(out, collapse = "\n"),
    "House rule for {stop('evaluated')}",
    fixed = TRUE
  )
})

test_that("prescribe(): still emits curated treatments for known checks", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "bad <- function() T")

  res <- checktor(pkg, verbose = FALSE, progress = FALSE)
  out <- cli::cli_fmt(prescribe(res))
  txt <- paste(out, collapse = "\n")
  expect_match(txt, "T/F Usage Issues")
})

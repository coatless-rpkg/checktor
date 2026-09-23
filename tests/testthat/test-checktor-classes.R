# The result classes and their print methods, the output a user actually reads.

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

test_that("print.checktor_check_result(): a failure marked skipped is a failure", {
  # A check registered with register_check() can set skipped by hand. Whatever it
  # claims, a failed check is a failure, as the verdict already counts it.
  res <- checktor_check_result(FALSE, "z.R:1", "House rule", skipped = TRUE)
  out <- paste(cli::cli_fmt(print(res)), collapse = "\n")
  expect_match(out, "House rule: FAILED", fixed = TRUE)
  expect_match(out, "z.R:1", fixed = TRUE)
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

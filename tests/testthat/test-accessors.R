test_that("category objects are classed checktor_category_result", {
  pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_s3_class(r$code_issues, "checktor_category_result")
  expect_s3_class(diagnose_code_issues(pkg, verbose = FALSE), "checktor_category_result")
  # nested access still works
  expect_false(r$code_issues$tf_usage$passed)
  expect_type(r$code_issues$passed, "logical")
})

test_that("issues() returns a tidy per-issue frame at each level", {
  pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  di <- issues(r)
  expect_s3_class(di, "data.frame")
  expect_identical(names(di), c("category","check","file","line","location","message"))
  expect_equal(nrow(di), 10L)                       # total_issues
  expect_equal(sum(di$check == "tf_usage"), 7L)
  expect_type(di$line, "integer")

  ci <- issues(r$code_issues)
  expect_identical(names(ci), c("check","file","line","location","message"))
  expect_equal(nrow(ci), 7L)

  one <- issues(r$code_issues$tf_usage)
  expect_identical(names(one), c("file","line","location","message"))
  expect_equal(nrow(one), 7L)
  expect_equal(one$file[1], "tf_usage_bad.R")
  expect_equal(one$line[1], 8L)
})

test_that("issues() on a healthy package is a 0-row typed frame", {
  pkg <- make_temp_dir(); write_pkg(pkg)             # clean fixture (0 issues)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  di <- issues(r)
  expect_equal(nrow(di), 0L)
  expect_identical(names(di), c("category","check","file","line","location","message"))
  expect_type(di$line, "integer")
})

test_that("predicates report status without sublist navigation", {
  pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  expect_false(is_healthy(r))
  expect_equal(n_issues(r), 10L)
  expect_equal(n_failed_checks(r), 4L)

  expect_true("code.tf_usage" %in% failed_checks(r))
  expect_type(failed_checks(r), "character")

  pc <- passed(r$code_issues)
  expect_type(pc, "logical"); expect_false(pc[["tf_usage"]]); expect_true(pc[["seed_setting"]])
  expect_false(passed(r$code_issues$tf_usage))
  expect_equal(n_issues(r$code_issues$tf_usage), 7L)

  cp <- make_temp_dir(); write_pkg(cp)
  clean <- checktor(cp, verbose = FALSE, progress = FALSE)
  expect_true(is_healthy(clean)); expect_equal(n_issues(clean), 0L)
})

test_that("tidy() is per-check and summary() is per-category", {
  pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  td <- tidy(r)
  expect_identical(names(td), c("category","check","passed","n_issues","message"))
  expect_equal(nrow(td), 39L)                        # all checks
  expect_equal(td$n_issues[td$check == "tf_usage"], 7L)
  expect_identical(as.data.frame(r), td)             # as.data.frame == tidy

  s <- summary(r)
  expect_identical(names(s), c("category","checks","passed","failed","issues"))
  expect_equal(nrow(s), 5L)
  expect_equal(s$issues[s$category == "code"], 7L)
  expect_equal(s$failed[s$category == "description"], 3L)
})

test_that("accessors are robust to early-return categories (no R/ dir)", {
  d <- make_temp_dir()
  writeLines(c("Package: x", "Title: T", "Version: 0.0.1",
    "Description: A minimal package used to exercise accessor robustness here.",
    "License: GPL-3"), file.path(d, "DESCRIPTION"))
  r <- checktor(d, verbose = FALSE, progress = FALSE)
  expect_no_error(summary(r))
  expect_equal(nrow(summary(r)), 5L)
  expect_no_error(issues(r))
  expect_no_error(tidy(r))
  expect_no_error(n_issues(r$code_issues))
  expect_equal(n_issues(r$code_issues), 0L)
})

test_that("summary check counts agree with tidy for early-return categories", {
  d <- make_temp_dir()
  writeLines(c("Package: x", "Title: T", "Version: 0.0.1",
    "Description: A minimal package used to pin summary/tidy agreement here.",
    "License: GPL-3"), file.path(d, "DESCRIPTION"))
  r <- checktor(d, verbose = FALSE, progress = FALSE)
  s <- summary(r)
  td <- tidy(r)
  # the code category has no R/ dir -> zero checks ran
  expect_equal(s$checks[s$category == "code"], 0L)
  expect_equal(s$passed[s$category == "code"], 0L)
  # per-category check counts in summary must equal tidy's row counts
  tcounts <- as.integer(table(factor(td$category, levels = s$category)))
  expect_equal(s$checks, tcounts)
  expect_equal(n_failed_checks(r$code_issues), 0L)
})

test_that("print footer points to accessors and Patient shows package name", {
  pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  out <- cli::cli_fmt(print(r))
  txt <- paste(out, collapse = "\n")
  expect_match(txt, "summary\\(\\)")
  expect_match(txt, "issues\\(\\)")
  expect_false(grepl("Run `checktor\\(\\)` for detailed diagnosis", txt))
  # Patient line shows a short package name, not the wrapped temp path
  expect_false(grepl("/var/folders|/tmp/|Rtmp", txt))
})

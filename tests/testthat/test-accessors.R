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

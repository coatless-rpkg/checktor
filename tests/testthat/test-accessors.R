test_that("category objects are classed checktor_category_result", {
  pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_s3_class(r$code_issues, "checktor_category_result")
  expect_s3_class(diagnose_code_issues(pkg, verbose = FALSE), "checktor_category_result")
  # nested access still works
  expect_false(r$code_issues$tf_usage$passed)
  expect_type(r$code_issues$passed, "logical")
})

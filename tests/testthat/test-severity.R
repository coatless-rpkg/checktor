# Severity tiers: policy / robustness / opinion.
#
# A test that names a CRAN package reproduces a false positive or a missed
# finding from that package's real sources, so a regression fails here first.

# Test check_severity() ----

test_that("check_severity(): every check that runs has a valid tier", {
  expect_true(all(CHECK_SEVERITY %in% SEVERITY_LEVELS))
  # A check that runs but has no tier would silently fall back to `robustness`
  # and quietly join the verdict. Catch that here rather than in someone's CI.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  ran <- tidy(checktor(pkg, verbose = FALSE, progress = FALSE))$check
  expect_true(all(ran %in% names(CHECK_SEVERITY)))
})

test_that("check_severity(): falls back to robustness, not to silence", {
  # An unregistered check is a real finding until someone says otherwise. Failing
  # safe here means a new check cannot be accidentally invisible.
  expect_equal(check_severity("no_such_check"), "robustness")
  expect_equal(check_severity("tf_usage"), "robustness")
  expect_equal(check_severity("core_usage"), "policy")
  expect_equal(check_severity("missing_examples"), "opinion")
})

# The registry in R/severity.R says what tier each check sits in and when it runs.
# Both used to be spread across unrelated places, so these tests hold the table to
# what the package actually does.

test_that("check_severity(): every check that runs has a severity entry", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  ran <- tidy(checktor(pkg, verbose = FALSE, progress = FALSE))$check
  expect_true(all(ran %in% names(CHECK_SEVERITY)))
  expect_true(all(CHECK_SEVERITY %in% SEVERITY_LEVELS))
})

test_that("check_severity(): each check has a lab_ function named after it", {
  # The rename exists so `tidy()$check` and the function you call line up. A new
  # check that breaks that pairing should fail here.
  exported <- getNamespaceExports("checktor")
  for (nm in names(CHECK_SEVERITY)) {
    expect_true(paste0("lab_", nm) %in% exported, info = nm)
  }
})

test_that("check_severity(): `urls` is advice, not policy", {
  # It flags any http:// link. CRAN's NOTE is for URLs that are INVALID or that
  # REDIRECT, which R determines by FETCHING them; checktor is offline and cannot
  # know whether a host even offers https. testthat, stringr, rlang, curl,
  # jsonlite, digest and zoo all ship http:// links and are on CRAN today.
  expect_equal(check_severity("urls"), "opinion")
})

# Test check_when() ----

test_that("check_when(): agrees with what a default run actually does", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  ran <- tidy(checktor(pkg, verbose = FALSE, progress = FALSE))$check

  # A check marked "request" is only there when you call it yourself.
  on_request <- names(CHECK_WHEN)[CHECK_WHEN == "request"]
  expect_false(any(on_request %in% ran), info = paste(on_request, collapse = ", "))

  # Everything else in the severity table is part of the run.
  expected <- setdiff(names(CHECK_SEVERITY), on_request)
  expect_setequal(ran, expected)
})

test_that("check_when(): defaults to always for anything unlisted", {
  expect_equal(check_when("tf_usage"), "always")
  expect_equal(check_when("a_check_that_does_not_exist"), "always")
  expect_equal(check_when("url_liveness"), "console")
  expect_equal(check_when("spelling"), "backend")
  expect_equal(check_when("cran_comments_file"), "request")
})

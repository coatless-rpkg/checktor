# The registry in R/severity.R says what tier each check sits in and when it runs.
# Both used to be spread across unrelated places, so these tests hold the table to
# what the package actually does.

test_that("every check that runs has a severity entry", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  ran <- tidy(checktor(pkg, verbose = FALSE, progress = FALSE))$check
  expect_true(all(ran %in% names(CHECK_SEVERITY)))
  expect_true(all(CHECK_SEVERITY %in% SEVERITY_LEVELS))
})

test_that("CHECK_WHEN agrees with what a default run actually does", {
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

test_that("an on-request check is discoverable without being a skip or a penalty", {
  # Two different things that a single "did not run" line would blur. A skipped
  # check wanted to run and could not. An on-request check was never asked for,
  # so naming it is only so you can find out it is there.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  on_request <- r$metadata$on_request_checks
  expect_setequal(on_request, names(CHECK_WHEN)[CHECK_WHEN == "request"])
  # It is not reported as a skip, and it never reaches the verdict.
  expect_false(any(on_request %in% r$metadata$skipped_checks))
  expect_false(any(on_request %in% tidy(r)$check))
  # Being opinion tier, none of them could change a default verdict even if run.
  expect_true(all(vapply(on_request, function(n) CHECK_SEVERITY[[n]], character(1)) ==
                    "opinion"))
  expect_false(any(DEFAULT_SEVERITY == "opinion"))

  # The verbose summary names them, distinctly from the skipped line.
  txt <- paste(
    cli::cli_fmt(checktor(pkg, verbose = TRUE, progress = FALSE)),
    collapse = " "
  )
  expect_match(txt, "available on request")
  expect_match(txt, on_request[[1]], fixed = TRUE)
})

test_that("check_when defaults to always for anything unlisted", {
  expect_equal(check_when("tf_usage"), "always")
  expect_equal(check_when("a_check_that_does_not_exist"), "always")
  expect_equal(check_when("url_liveness"), "console")
  expect_equal(check_when("spelling"), "backend")
  expect_equal(check_when("cran_comments_file"), "request")
})

test_that("a check that did not run is reported as skipped, not as passing", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # setup.R turns both gated checks off, which is the same state as a CI run.
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  td <- tidy(r)

  expect_true("skipped" %in% names(td))
  expect_true(any(td$skipped))
  expect_true("url_liveness" %in% td$check[td$skipped])

  # It carries a reason a reader can act on, and never counts against the verdict.
  res <- r$general_issues$url_liveness
  expect_true(isTRUE(res$skipped))
  expect_match(res$skip_reason, "console")
  expect_true(res$passed)
  expect_equal(n_issues(r), 0L)

  # The names travel with the results so a caller can see what was not examined.
  expect_true("url_liveness" %in% r$metadata$skipped_checks)
})

test_that("a check that ran is not marked skipped", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  old <- options(checktor.url_check = TRUE)
  on.exit(options(old), add = TRUE)
  testthat::local_mocked_bindings(fetch_url_db = function(path) data.frame())

  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false(isTRUE(r$general_issues$url_liveness$skipped))
  expect_false("url_liveness" %in% r$metadata$skipped_checks)
})

test_that("Config/checktor accepts the name of a registered check", {
  # The typo guard used to know only the built-ins, so naming a custom check in
  # Config/checktor warned that a real, working name was unknown.
  lab_custom <- function(path, verbose = TRUE, parsed = NULL) {
    checktor_check_result(FALSE, "a finding", "custom check")
  }
  register_check("custom_thing", lab_custom, category = "code", severity = "opinion")
  on.exit(unregister_check("custom_thing"), add = TRUE)

  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "Config/checktor/allow: custom_thing")

  expect_no_warning(r <- checktor(pkg, verbose = FALSE, progress = FALSE))
  expect_equal(r$metadata$suppressed, 1L)
  expect_true("custom_thing" %in% all_check_names())
})

test_that("each check has a lab_ function named after it", {
  # The rename exists so `tidy()$check` and the function you call line up. A new
  # check that breaks that pairing should fail here.
  exported <- getNamespaceExports("checktor")
  for (nm in names(CHECK_SEVERITY)) {
    expect_true(paste0("lab_", nm) %in% exported, info = nm)
  }
})

test_that("url_liveness stays quiet when no host could be reached", {
  # Every row failing to resolve says the machine has no connection, not that the
  # package's links are broken, and the help page promises a quiet pass.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  old <- options(checktor.url_check = TRUE)
  on.exit(options(old), add = TRUE)
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) {
      data.frame(
        URL = c("https://a.example", "https://b.example"),
        From = "DESCRIPTION",
        Status = c("Error", "Error"),
        Message = "Could not resolve host",
        New = "",
        stringsAsFactors = FALSE
      )
    }
  )
  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_length(res$issues, 0L)
  expect_true(isTRUE(res$skipped))
})

test_that("url_liveness still reports one dead host among reachable ones", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  old <- options(checktor.url_check = TRUE)
  on.exit(options(old), add = TRUE)
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) {
      data.frame(
        URL = c("https://a.example", "https://b.example"),
        From = "DESCRIPTION",
        Status = c("404", "Error"),
        Message = c("Not Found", "Could not resolve host"),
        New = "",
        stringsAsFactors = FALSE
      )
    }
  )
  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_length(res$issues, 2L)
})

test_that("software_names does not match plain English through a dotted name", {
  # data.table is a regular expression unless escaped, where the dot would match
  # the space in "data table".
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Stores rows in a data table for later use here.")
  expect_true(lab_software_names(pkg, verbose = FALSE)$passed)

  named <- make_temp_dir()
  write_pkg(named, description = "Builds on data.table for fast grouped joins.")
  expect_false(lab_software_names(named, verbose = FALSE)$passed)
})

test_that("a treatment line renders its markup instead of printing braces", {
  # The fixture has to FAIL the check: a passing one emits the success alert and
  # never reaches the treatment line, so the markup assertion would be checked
  # against the wrong message. `f` returns a value, so its print() is a leak
  # rather than an exempt console reporter.
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c("a.R" = "f <- function(x) {\n  print(x)\n  x + 1\n}"))
  expect_false(lab_print_cat_usage(pkg, verbose = FALSE)$passed)

  out <- cli::cli_fmt(lab_print_cat_usage(pkg, verbose = TRUE))
  txt <- paste(out, collapse = "\n")
  expect_match(txt, "Treatment: Use `message()`", fixed = TRUE)
  expect_false(grepl("{.code", txt, fixed = TRUE))
})

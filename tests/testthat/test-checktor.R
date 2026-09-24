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

test_that("checktor(): a DESCRIPTION R cannot read counts against the verdict", {
  r <- checktor(unparseable_pkg(), verbose = FALSE, progress = FALSE)
  expect_equal(r$metadata$total_issues, 1L)
  expect_equal(r$metadata$failed_checks, 1L)
  expect_false(is_healthy(r))

  di <- issues(r)
  expect_identical(di$category, "description")
  expect_identical(di$check, "description_file")
  expect_identical(di$severity, "policy")
  expect_match(di$location, "^DESCRIPTION does not parse: ")

  td <- tidy(r)
  expect_identical(td$check[!td$passed & !td$skipped], "description_file")
  expect_identical(failed_checks(r), "description.description_file")
})

test_that("checktor(): names the DESCRIPTION checks that could not run", {
  r <- checktor(unparseable_pkg(), verbose = FALSE, progress = FALSE)
  td <- tidy(r)
  desc_rows <- td[td$category == "description", ]
  sat_out <- desc_rows$check[desc_rows$skipped]
  expect_true(all(c("software_names", "authors", "license") %in% sat_out))
  expect_false(any(c("description_file", "license_year") %in% sat_out))
  expect_true(all(sat_out %in% r$metadata$skipped_checks))
})

test_that("checktor(): a DESCRIPTION R cannot open prints no warning", {
  expect_no_warning(
    r <- checktor(unopenable_pkg("directory"), verbose = FALSE, progress = FALSE)
  )
  expect_identical(failed_checks(r), "description.description_file")
  expect_identical(
    r$description_issues$description_file$issues,
    "DESCRIPTION is a directory, not a file"
  )

  skip_on_os("windows") # a mode-000 file is not portable
  pkg <- unopenable_pkg("no_permission")
  skip_if(
    file.access(file.path(pkg, "DESCRIPTION"), 4L) == 0L,
    "this user can read a file with no read permission"
  )
  expect_no_warning(r <- checktor(pkg, verbose = FALSE, progress = FALSE))
  expect_identical(failed_checks(r), "description.description_file")
})

test_that("checktor(): policy violations are part of the main run", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c("f <- function() { browser(); 1 }"))

  results <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_true("policy_issues" %in% names(results))
  expect_false(results$policy_issues$browser_calls$passed)
})

test_that("checktor(): reads the code when keep.parse.data is off", {
  # sys.source() and some IDE tooling turn the option off, and getParseData() is
  # then empty for every parse. Each parse-tree check saw a blank file, so a
  # package full of bare T came back healthy.
  withr::local_options(keep.parse.data = FALSE)
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() T")

  results <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_equal(results$code_issues$tf_usage$issues, "test.R:1")
  expect_false(is_healthy(results))
  # The caller's setting is theirs, and is back once the run ends.
  expect_false(getOption("keep.parse.data"))
})

test_that("checktor(): errors clearly on a non-package directory", {
  empty <- make_temp_dir()
  expect_error(checktor(empty, verbose = FALSE), "No DESCRIPTION file found")
})

test_that("checktor(): category objects are classed checktor_category_result", {
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_s3_class(r$code_issues, "checktor_category_result")
  expect_s3_class(
    diagnose_code_issues(pkg, verbose = FALSE),
    "checktor_category_result"
  )
  # nested access still works
  expect_false(r$code_issues$tf_usage$passed)
  expect_type(r$code_issues$passed, "logical")
})

test_that("checktor(): from a subdirectory matches a run from the root", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  from_root <- checktor(pkg, verbose = FALSE, progress = FALSE)
  from_sub <- checktor(file.path(pkg, "R"), verbose = FALSE, progress = FALSE)

  expect_equal(tidy(from_sub)$check, tidy(from_root)$check)
  expect_equal(tidy(from_sub)$passed, tidy(from_root)$passed)
  expect_equal(n_issues(from_sub), n_issues(from_root))
})

test_that("checktor(): resolves the package from the working directory", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  # withr undoes in reverse order, so the working directory is restored before
  # make_temp_dir() removes the package. Windows refuses to remove a directory
  # that is a process's working directory.
  withr::local_dir(file.path(pkg, "R"))
  res <- checktor(verbose = FALSE, progress = FALSE) # path defaults to "."
  expect_s3_class(res, "checktor_results")
  expect_true(is_healthy(res))
})

test_that("checktor(): a directory outside any package still errors clearly", {
  skip_if_tempdir_in_package()
  bare <- make_temp_dir()
  expect_error(
    checktor(bare, verbose = FALSE, progress = FALSE),
    "any directory above it"
  )
})

test_that("checktor(): an on-request check is discoverable, not a skip", {
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

test_that("checktor(): a check that did not run is skipped, not passing", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # setup.R turns both gated checks off, which is the same state as a CI run.
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  td <- tidy(r)

  expect_true("skipped" %in% names(td))
  expect_true(any(td$skipped))
  expect_true("url_liveness" %in% td$check[td$skipped])
  expect_false(td$passed[td$check == "url_liveness"])

  # It carries a reason a reader can act on, and never counts against the verdict.
  res <- r$general_issues$url_liveness
  expect_true(isTRUE(res$skipped))
  expect_match(res$skip_reason, "console")
  expect_true(res$passed)
  expect_equal(n_issues(r), 0L)

  # The names travel with the results so a caller can see what was not examined.
  expect_true("url_liveness" %in% r$metadata$skipped_checks)
})

test_that("checktor(): a check that ran is not marked skipped", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  withr::local_options(checktor.url_check = TRUE)
  testthat::local_mocked_bindings(fetch_url_db = function(path) data.frame())

  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false(isTRUE(r$general_issues$url_liveness$skipped))
  expect_false("url_liveness" %in% r$metadata$skipped_checks)
})

test_that("checktor(): counts only the tiers the verdict is about", {
  # The fixture trips tf_usage (robustness, 7 issues) and, without its NEWS.md,
  # news_file (opinion, 1). By default the opinion finding is REPORTED but does
  # not count against a clean bill of health.
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  unlink(file.path(pkg, "NEWS.md"))
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  expect_equal(n_issues(r), 7L) # verdict
  expect_equal(nrow(issues(r)), 8L) # everything, still visible
  expect_equal(r$metadata$advisory_issues, 1L)
  expect_true("opinion" %in% issues(r)$severity)
})

test_that("checktor(): asking for all tiers folds opinion into the verdict", {
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  unlink(file.path(pkg, "NEWS.md")) # an opinion finding: news_file
  r <- checktor(
    pkg,
    verbose = FALSE,
    progress = FALSE,
    severity = SEVERITY_LEVELS
  )
  expect_equal(n_issues(r), 8L)
  expect_equal(r$metadata$advisory_issues, 0L)
})

test_that("checktor(): a policy-only run ignores robustness findings", {
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  unlink(file.path(pkg, "NEWS.md")) # an opinion finding: news_file
  r <- checktor(pkg, verbose = FALSE, progress = FALSE, severity = "policy")
  expect_equal(n_issues(r), 0L) # tf_usage is robustness, not policy
  expect_true(is_healthy(r))
  expect_equal(r$metadata$advisory_issues, 8L)
})

test_that("checktor(): severity is validated", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_error(
    checktor(pkg, verbose = FALSE, progress = FALSE, severity = "nonsense")
  )
})

# Test print.checktor_results() ----

test_that("print.checktor_results(): runs without error", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  results <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_no_error(cli::cli_fmt(print(results)))
})

test_that("print.checktor_results(): a DESCRIPTION R cannot read needs attention", {
  r <- checktor(unparseable_pkg(), verbose = FALSE, progress = FALSE)
  out <- cli::cli_fmt(print(r))
  expect_match(out, "DESCRIPTION ISSUES: 1 failing check", fixed = TRUE, all = FALSE)
  expect_match(
    out,
    "Overall health: NEEDS ATTENTION (1 issue)",
    fixed = TRUE,
    all = FALSE
  )
  expect_no_match(out, "EXCELLENT", fixed = TRUE)
})

test_that("print.checktor_results(): footer points to accessors", {
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  out <- cli::cli_fmt(print(r))
  txt <- paste(out, collapse = "\n")
  expect_match(txt, "summary\\(\\)")
  expect_match(txt, "issues\\(\\)")
  expect_false(grepl("Run `checktor\\(\\)` for detailed diagnosis", txt))
  # Patient line shows a short package name, not the wrapped temp path
  expect_false(grepl("/var/folders|/tmp/|Rtmp", txt))
})

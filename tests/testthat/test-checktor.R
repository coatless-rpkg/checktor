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

  # The checks that read DESCRIPTION sit out, and the run names them.
  sat_out <- td$check[td$category == "description" & td$skipped]
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

test_that("checktor(): errors clearly on a directory outside any package", {
  skip_if_tempdir_in_package()
  bare <- make_temp_dir()
  err <- expect_error(
    checktor(bare, verbose = FALSE, progress = FALSE),
    "No DESCRIPTION file found"
  )
  expect_match(conditionMessage(err), "any directory above it")
})

test_that("checktor(): resolves the package from a subdirectory or the working directory", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  from_root <- checktor(pkg, verbose = FALSE, progress = FALSE)
  from_sub <- checktor(file.path(pkg, "R"), verbose = FALSE, progress = FALSE)

  expect_equal(tidy(from_sub)$check, tidy(from_root)$check)
  expect_equal(tidy(from_sub)$passed, tidy(from_root)$passed)
  expect_equal(n_issues(from_sub), n_issues(from_root))

  # withr undoes in reverse order, so the working directory is restored before
  # make_temp_dir() removes the package. Windows refuses to remove a directory
  # that is a process's working directory.
  withr::local_dir(file.path(pkg, "R"))
  res <- checktor(verbose = FALSE, progress = FALSE) # path defaults to "."
  expect_s3_class(res, "checktor_results")
  expect_true(is_healthy(res))
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

test_that("checktor(): severity is validated and decides which tiers count against the verdict", {
  # The fixture trips tf_usage (robustness, 7 issues) and, without its NEWS.md,
  # news_file (opinion, 1). By default the opinion finding is REPORTED but does
  # not count against a clean bill of health.
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  unlink(file.path(pkg, "NEWS.md"))

  r_default <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_equal(n_issues(r_default), 7L) # verdict
  expect_equal(nrow(issues(r_default)), 8L) # everything, still visible
  expect_equal(r_default$metadata$advisory_issues, 1L)
  expect_true("opinion" %in% issues(r_default)$severity)

  # Asking for all tiers folds opinion into the verdict.
  r_all <- checktor(
    pkg,
    verbose = FALSE,
    progress = FALSE,
    severity = SEVERITY_LEVELS
  )
  expect_equal(n_issues(r_all), 8L)
  expect_equal(r_all$metadata$advisory_issues, 0L)
  expect_equal(r_all$metadata$failed_checks, 2L)

  # A policy-only run ignores robustness findings.
  r_policy <- checktor(pkg, verbose = FALSE, progress = FALSE, severity = "policy")
  expect_equal(n_issues(r_policy), 0L) # tf_usage is robustness, not policy
  expect_true(is_healthy(r_policy))
  expect_equal(r_policy$metadata$advisory_issues, 8L)

  # An unknown tier is refused before anything runs.
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

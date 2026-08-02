# Severity tiers: policy / robustness / opinion.

test_that("every registered check has a severity, and every severity is valid", {
  expect_true(all(CHECK_SEVERITY %in% SEVERITY_LEVELS))
  # A check that runs but has no tier would silently fall back to `robustness`
  # and quietly join the verdict. Catch that here rather than in someone's CI.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  ran <- tidy(checktor(pkg, verbose = FALSE, progress = FALSE))$check
  expect_true(all(ran %in% names(CHECK_SEVERITY)))
})

test_that("check_severity falls back to robustness, not to silence", {
  # An unregistered check is a real finding until someone says otherwise. Failing
  # safe here means a new check cannot be accidentally invisible.
  expect_equal(check_severity("no_such_check"), "robustness")
  expect_equal(check_severity("tf_usage"), "robustness")
  expect_equal(check_severity("core_usage"), "policy")
  expect_equal(check_severity("missing_examples"), "opinion")
})

test_that("issues() and tidy() carry the tier", {
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE
  )
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_true("severity" %in% names(issues(r)))
  expect_true("severity" %in% names(tidy(r)))
  expect_true(all(issues(r)$severity %in% SEVERITY_LEVELS))
})

test_that("the verdict counts only the tiers it is a verdict about", {
  # The fixture trips tf_usage (robustness, 7 issues) and cph_role (opinion, 1).
  # By default the opinion finding is REPORTED but does not count against a clean
  # bill of health.
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE
  )
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  expect_equal(n_issues(r), 7L) # verdict
  expect_equal(nrow(issues(r)), 8L) # everything, still visible
  expect_equal(r$metadata$advisory_issues, 1L)
  expect_true("opinion" %in% issues(r)$severity)
})

test_that("asking for all three tiers folds opinion back into the verdict", {
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE
  )
  r <- checktor(
    pkg,
    verbose = FALSE,
    progress = FALSE,
    severity = SEVERITY_LEVELS
  )
  expect_equal(n_issues(r), 8L)
  expect_equal(r$metadata$advisory_issues, 0L)
})

test_that("a policy-only run ignores robustness findings", {
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE
  )
  r <- checktor(pkg, verbose = FALSE, progress = FALSE, severity = "policy")
  expect_equal(n_issues(r), 0L) # tf_usage is robustness, not policy
  expect_true(is_healthy(r))
  expect_equal(r$metadata$advisory_issues, 8L)
})

test_that("severity is validated", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_error(
    checktor(pkg, verbose = FALSE, progress = FALSE, severity = "nonsense")
  )
})

test_that("checkup() follows the verdict, so opinion does not fail CI", {
  # checkup() is the CI wrapper. A convention nobody enforces must not break a
  # build, or the tiers bought us nothing.
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE
  )
  expect_false(checkup(pkg)) # tf_usage is robustness: fails the build

  # A package whose ONLY finding is a convention (no NEWS file) still passes CI.
  clean <- make_temp_dir()
  write_pkg(clean, news = FALSE)
  expect_true(checkup(clean))
  expect_false(checkup(clean, severity = SEVERITY_LEVELS)) # unless you ask for it
})

test_that("prescribe() still offers remedies for advisory-only findings", {
  # The verdict can be clean while advisory findings remain. Prescribing for the
  # verdict alone would withhold the remedy for every one of them.
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE) # clean except: no NEWS file, which is `opinion`
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  expect_true(is_healthy(r)) # nothing CRAN will reject
  expect_gt(r$metadata$advisory_issues, 0L) # but there IS something to say
  txt <- paste(cli::cli_fmt(prescribe(r)), collapse = "\n")
  # The finding itself, not the "NEWS file check" heading: a header-only
  # prescription is exactly the silence this test is here to rule out.
  expect_match(txt, "No NEWS file found", fixed = TRUE)
})

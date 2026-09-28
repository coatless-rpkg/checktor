# Test issues() ----

test_that("issues(): returns a tidy per-issue frame at each level", {
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  unlink(file.path(pkg, "NEWS.md")) # an opinion finding: news_file
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  di <- issues(r)
  expect_s3_class(di, "data.frame")
  expect_identical(
    names(di),
    c("category", "check", "severity", "file", "line", "location", "message")
  )
  expect_equal(nrow(di), 8L) # every finding, all tiers
  expect_equal(sum(di$check == "tf_usage"), 7L)
  expect_type(di$line, "integer")

  ci <- issues(r$code_issues)
  expect_identical(
    names(ci),
    c("check", "severity", "file", "line", "location", "message")
  )
  expect_equal(nrow(ci), 7L)

  one <- issues(r$code_issues$tf_usage)
  expect_identical(names(one), c("file", "line", "location", "message"))
  expect_equal(nrow(one), 7L)
  expect_equal(one$file[1], "tf_usage_bad.R")
  expect_equal(one$line[1], 8L)
})

test_that("issues(): on a healthy package is a 0-row typed frame", {
  pkg <- make_temp_dir()
  write_pkg(pkg) # clean fixture (0 issues)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  di <- issues(r)
  expect_equal(nrow(di), 0L)
  expect_identical(
    names(di),
    c("category", "check", "severity", "file", "line", "location", "message")
  )
  expect_type(di$line, "integer")
})

test_that("issues(): a finding keeps its location whatever label it carries", {
  # The parser used to read only "a.R:2", so a labelled finding lost its location
  # and could not be pointed at.
  r <- checktor(ci_pkg(), verbose = FALSE, progress = FALSE)
  di <- issues(r)
  located <- di[!is.na(di$file), ]
  expect_true("tf_usage" %in% located$check)
  expect_true("internal_ns" %in% located$check) # reported as "a.R:3 (pkg:::fn)"
  expect_equal(located$line[located$check == "internal_ns"], 3L)
})

test_that("issues(): carries the tier, as does tidy()", {
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  unlink(file.path(pkg, "NEWS.md")) # an opinion finding: news_file
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  # The RIGHT tier for each check, not merely a valid one: a tier column that said
  # "policy" for everything would pass a test that only checks the levels.
  di <- issues(r)
  expect_identical(unique(di$severity[di$check == "tf_usage"]), "robustness")
  expect_identical(di$severity[di$check == "news_file"], "opinion")
  td <- tidy(r)
  expect_identical(td$severity[td$check == "tf_usage"], "robustness")
  expect_identical(td$severity[td$check == "news_file"], "opinion")
  expect_identical(td$severity[td$check == "seed_setting"], "policy")
})

# Test is_healthy() ----

test_that("is_healthy(): predicates report status without sublist navigation", {
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  expect_false(is_healthy(r))
  expect_equal(n_issues(r), 7L) # verdict: policy + robustness only
  expect_equal(n_failed_checks(r), 1L)

  expect_true("code.tf_usage" %in% failed_checks(r))
  expect_type(failed_checks(r), "character")

  pc <- passed(r$code_issues)
  expect_type(pc, "logical")
  expect_false(pc[["tf_usage"]])
  expect_true(pc[["seed_setting"]])
  expect_false(passed(r$code_issues$tf_usage))
  expect_equal(n_issues(r$code_issues$tf_usage), 7L)
})

# Test passed() ----

test_that("passed(): a skipped check did not fail, though tidy() does not pass it", {
  cat_res <- checktor_category_result(
    url_liveness = checktor_skipped_result("URL liveness check", "offline"),
    tf_usage = checktor_check_result(TRUE, character(0), "T/F usage check")
  )

  # passed() and the verdict ask whether a check failed, and a skip did not.
  expect_true(passed(cat_res$url_liveness))
  expect_identical(passed(cat_res), c(url_liveness = TRUE, tf_usage = TRUE))
  expect_true(is_healthy(cat_res$url_liveness))
  expect_true(is_healthy(cat_res))
  expect_identical(failed_checks(cat_res), character(0))
  expect_equal(n_failed_checks(cat_res), 0L)

  # The same split holds for a whole run, where url_liveness sits out in tests.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_true(passed(r)[["general"]])
  expect_true(passed(r$general_issues)[["url_liveness"]])
  # tidy() gives each check one state, so the same check is skipped, not passed.
  rt <- tidy(r)
  expect_false(rt$passed[rt$check == "url_liveness"])
  expect_true(rt$skipped[rt$check == "url_liveness"])
})

# Test tidy() ----

test_that("tidy(): is per-check and summary() is per-category", {
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  unlink(file.path(pkg, "NEWS.md")) # an opinion finding: news_file
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  td <- tidy(r)
  expect_identical(
    names(td),
    c(
      "category",
      "check",
      "severity",
      "passed",
      "skipped",
      "n_issues",
      "message"
    )
  )
  # Every check that runs by default, which is every check not on request, once.
  by_default <- setdiff(names(CHECK_SEVERITY), on_request_checks())
  expect_setequal(td$check, by_default)
  expect_equal(nrow(td), length(by_default))
  expect_equal(td$n_issues[td$check == "tf_usage"], 7L)
  # Each check reports under the category the registry gives it.
  expect_identical(
    td$category,
    BUILTIN_CHECKS$category[match(td$check, BUILTIN_CHECKS$name)]
  )
  expect_identical(as.data.frame(r), td) # as.data.frame == tidy

  s <- summary(r)
  expect_identical(
    names(s),
    c("category", "checks", "passed", "failed", "skipped", "issues")
  )
  expect_equal(nrow(s), 5L)
  expect_equal(s$issues[s$category == "code"], 7L)
  expect_equal(s$failed[s$category == "general"], 1L)
})

test_that("tidy(): a check that did not run is skipped, never passed (#15)", {
  cat_res <- checktor_category_result(
    url_liveness = checktor_skipped_result("URL liveness check", "offline"),
    tf_usage = checktor_check_result(TRUE, character(0), "T/F usage check"),
    seed_setting = checktor_check_result(FALSE, "a.R:1", "Seed setting check"),
    # A registered check can set both. A failure wins, as it does in summary().
    house_rule = checktor_check_result(FALSE, "z.R:1", "House rule", skipped = TRUE)
  )
  td <- tidy(cat_res)
  expect_identical(td$check, c("url_liveness", "tf_usage", "seed_setting", "house_rule"))
  expect_identical(td$passed, c(FALSE, TRUE, FALSE, FALSE))
  expect_identical(td$skipped, c(TRUE, FALSE, FALSE, FALSE))
})

# Test summary() ----

test_that("summary(): counts a skipped check as skipped, and a failure marked skipped as failed (#15)", {
  cat_res <- checktor_category_result(
    url_liveness = checktor_skipped_result("URL liveness check", "offline"),
    tf_usage = checktor_check_result(TRUE, character(0), "T/F usage check"),
    seed_setting = checktor_check_result(FALSE, "a.R:1", "Seed setting check")
  )
  s <- summary(cat_res)
  expect_equal(s$checks, 3L)
  expect_equal(s$passed, 1L)
  expect_equal(s$failed, 1L)
  expect_equal(s$skipped, 1L)

  both <- checktor_category_result(
    # A registered check can set both. A failure wins.
    house_rule = checktor_check_result(FALSE, "z.R:1", "House rule", skipped = TRUE)
  )
  s <- summary(both)
  expect_equal(s$failed, 1L)
  expect_equal(s$skipped, 0L)
})

test_that("summary(): passed, failed and skipped add up to checks and agree with tidy()", {
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE) # news_file fails, so every state occurs
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  td <- tidy(r)
  s <- summary(r)
  failed <- !td$passed & !td$skipped

  expect_gt(sum(td$skipped), 0L) # url_liveness and spelling are off in tests
  expect_identical(td$check[failed], "news_file")
  # One state per check, so the three columns count what summary() counts.
  expect_false(any(td$passed & td$skipped))
  expect_equal(sum(td$passed), sum(s$passed))
  expect_equal(sum(failed), sum(s$failed))
  expect_equal(sum(td$skipped), sum(s$skipped))
  expect_equal(s$passed + s$failed + s$skipped, s$checks)
})

test_that("summary(): an early-return category (no R/ dir) summarises cleanly and agrees with tidy()", {
  d <- make_temp_dir()
  writeLines(
    c(
      "Package: x",
      "Title: T",
      "Version: 0.0.1",
      "Description: A minimal package used to exercise accessor robustness here.",
      "License: GPL-3"
    ),
    file.path(d, "DESCRIPTION")
  )
  r <- checktor(d, verbose = FALSE, progress = FALSE)
  s <- summary(r)
  td <- tidy(r)
  expect_equal(nrow(s), 5L)
  expect_no_error(issues(r))
  expect_equal(n_issues(r$code_issues), 0L)
  expect_equal(n_failed_checks(r$code_issues), 0L)
  # the code category has no R/ dir -> zero checks ran
  expect_equal(s$checks[s$category == "code"], 0L)
  expect_equal(s$passed[s$category == "code"], 0L)
  # per-category check counts in summary must equal tidy's row counts
  tcounts <- as.integer(table(factor(td$category, levels = s$category)))
  expect_equal(s$checks, tcounts)
})

# Test result_checks() ----

test_that("result_checks(): flattens every check in report order", {
  results <- list(
    policy_issues = .mk_cat(list(browser_calls = .mk_check(TRUE, character(0)))),
    code_issues = .mk_cat(list(
      tf_usage = .mk_check(FALSE, "a.R:1"),
      seed_setting = .mk_check(TRUE, character(0))
    )),
    metadata = list(total_issues = 1L)
  )
  flat <- result_checks(results)
  expect_identical(
    vapply(flat, `[[`, character(1), "category"),
    c("code", "code", "policy")
  )
  expect_identical(
    vapply(flat, `[[`, character(1), "name"),
    c("tf_usage", "seed_setting", "browser_calls")
  )
  expect_identical(flat[[1]]$check, results$code_issues$tf_usage)
  # A category that ended early carries no checks.
  early <- structure(
    list(passed = TRUE, message = "No R directory found"),
    class = "checktor_category_result"
  )
  expect_length(result_checks(list(code_issues = early)), 0L)
  expect_named(present_categories(results), c("code", "policy"))
})

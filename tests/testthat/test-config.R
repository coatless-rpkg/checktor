test_that("checktor_config reads Config/checktor/* fields, comma-split and trimmed", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = c(
      "Config/checktor/software_names: brms, cmdstanr",
      "Config/checktor/acronyms: MCMC,GLMM",
      "Config/checktor/disable: news_file",
      "Config/checktor/allow: urls:README.md, temp_cleanup"
    )
  )
  cfg <- checktor_config(pkg)
  expect_equal(cfg$software_names, c("brms", "cmdstanr"))
  expect_equal(cfg$acronyms, c("MCMC", "GLMM"))
  expect_equal(cfg$disable, "news_file")
  expect_equal(cfg$allow, c("urls:README.md", "temp_cleanup"))
})

test_that("checktor_config returns empty vectors when fields or DESCRIPTION are absent", {
  pkg <- make_temp_dir()
  write_pkg(pkg) # no Config/checktor/* fields
  cfg <- checktor_config(pkg)
  expect_equal(cfg$software_names, character(0))
  expect_equal(cfg$allow, character(0))

  bare <- make_temp_dir() # no DESCRIPTION at all
  dir.create(bare, showWarnings = FALSE, recursive = TRUE)
  cfg2 <- checktor_config(bare)
  expect_equal(cfg2$disable, character(0))
})

test_that("Config/checktor/software_names makes an extra name flagged when unquoted", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = "Wraps brms models for the user. It does several helpful things here.",
    extra = "Config/checktor/software_names: brms"
  )
  res <- diagnose_software_names_formatting(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_true(any(grepl("brms", res$issues)))
})

test_that("without config, the extra name is NOT flagged", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = "Wraps brms models for the user. It does several helpful things here."
  )
  expect_true(diagnose_software_names_formatting(pkg, verbose = FALSE)$passed)
})

test_that("Config software_names also reaches the double-quote check", {
  # The two-list trap: the include list (software_names) and SOFTWARE_NAMES must
  # both honour the config, or one check obeys it and the other ignores it.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = 'Wraps "brms" models for the user. It does helpful things here.',
    extra = "Config/checktor/software_names: brms"
  )
  expect_false(diagnose_description_quoted_quotes(pkg, verbose = FALSE)$passed)
})

test_that("Config/checktor/acronyms suppresses an acronym finding", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = "Runs MCMC over models for the analysis of tabular data here.",
    extra = "Config/checktor/acronyms: MCMC"
  )
  expect_false(
    "MCMC" %in% diagnose_acronym_explanation(pkg, verbose = FALSE)$issues
  )
})

# small synthetic category result for precise unit tests
.mk_check <- function(passed, issues) {
  checktor_check_result(passed, issues, "m")
}
.mk_cat <- function(checks) {
  cat <- checks
  cat$passed <- vapply(checks, function(c) isTRUE(c$passed), logical(1))
  class(cat) <- "checktor_category_result"
  cat
}

test_that("apply_suppressions: disable removes a check and its passed entry", {
  results <- list(
    code_issues = .mk_cat(list(
      tf_usage = .mk_check(FALSE, c("a.R:1", "a.R:2")),
      news_file = .mk_check(FALSE, "no NEWS")
    ))
  )
  out <- apply_suppressions(
    results,
    list(disable = "news_file", allow = character(0))
  )
  cat <- out$results$code_issues
  expect_false("news_file" %in% names(cat))
  expect_false("news_file" %in% names(cat$passed))
  expect_true("tf_usage" %in% names(cat)) # untouched
})

test_that("apply_suppressions: allow with a substring mutes only matching findings", {
  results <- list(
    g = .mk_cat(list(
      urls = .mk_check(
        FALSE,
        c("README.md: http://x", "vignette.Rmd: http://y")
      )
    ))
  )
  out <- apply_suppressions(
    results,
    list(disable = character(0), allow = "urls:README.md")
  )
  urls <- out$results$g$urls
  expect_equal(urls$issues, "vignette.Rmd: http://y") # only the README one muted
  expect_false(urls$passed) # still has a finding
  expect_equal(out$suppressed, 1L)
})

test_that("apply_suppressions: allow on a whole check flips it to passed", {
  results <- list(
    g = .mk_cat(list(
      temp_cleanup = .mk_check(FALSE, c("t.R:1", "t.R:2"))
    ))
  )
  out <- apply_suppressions(
    results,
    list(disable = character(0), allow = "temp_cleanup")
  )
  tc <- out$results$g$temp_cleanup
  expect_equal(tc$issues, character(0))
  expect_true(tc$passed)
  expect_true(out$results$g$passed[["temp_cleanup"]])
  expect_equal(out$suppressed, 2L)
})

test_that("checktor() honours disable and allow end to end", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = "f <- function() mean(x, na.rm = T)", # 1 tf_usage finding
    extra = "Config/checktor/allow: tf_usage"
  )
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_equal(sum(issues(r)$check == "tf_usage"), 0L)
  expect_gte(r$metadata$suppressed, 1L)

  pkg2 <- make_temp_dir()
  write_pkg(pkg2, news = FALSE, extra = "Config/checktor/disable: news_file")
  r2 <- checktor(pkg2, verbose = FALSE, progress = FALSE)
  expect_false("news_file" %in% tidy(r2)$check)
})

test_that("suppression reaches a DESCRIPTION-category check", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    title = "a lowercase title that is not title case",
    extra = "Config/checktor/disable: title_case"
  )
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false("title_case" %in% tidy(r)$check)
})

test_that("an unknown check name in allow/disable warns", {
  results <- list(g = .mk_cat(list(tf_usage = .mk_check(TRUE, character(0)))))
  expect_warning(
    apply_suppressions(
      results,
      list(disable = "no_such_check", allow = character(0))
    ),
    "no_such_check"
  )
})

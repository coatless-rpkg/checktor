# Test checktor_config() ----

test_that("checktor_config(): splits and trims Config/checktor/* fields", {
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

test_that("checktor_config(): returns empty vectors when nothing is set", {
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

# Test apply_suppressions() ----

test_that("apply_suppressions(): disable drops a check and its passed entry", {
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

test_that("apply_suppressions(): an allow substring mutes matching findings", {
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

test_that("apply_suppressions(): allow on a whole check flips it to passed", {
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

test_that("apply_suppressions(): warns on an unknown name in allow/disable", {
  results <- list(g = .mk_cat(list(tf_usage = .mk_check(TRUE, character(0)))))
  expect_warning(
    apply_suppressions(
      results,
      list(disable = "no_such_check", allow = character(0))
    ),
    "no_such_check"
  )
})

# Test checktor() ----

test_that("checktor(): honours disable and allow end to end", {
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

test_that("checktor(): suppression reaches a DESCRIPTION-category check", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    title = "a lowercase title that is not title case",
    extra = "Config/checktor/disable: title_case"
  )
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false("title_case" %in% tidy(r)$check)
})

test_that("checktor(): a disabled check does not run or print", {
  # The docs promise a disabled check does not run. It used to run, print its
  # finding in the live output, and only then be removed from the results.
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE, extra = "Config/checktor/disable: news_file")
  out <- paste(
    cli::cli_fmt(checktor(pkg, verbose = TRUE, progress = FALSE)),
    collapse = "\n"
  )
  expect_false(grepl("No NEWS file found", out, fixed = TRUE))
})

test_that("checktor(): options(checktor.disable) turns a check off (#17)", {
  # For a check you never want, in every package, without adding a field to each
  # DESCRIPTION: set it once, e.g. in ~/.Rprofile.
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  withr::local_options(checktor.disable = "news_file")

  out <- paste(
    cli::cli_fmt(r <- checktor(pkg, verbose = TRUE, progress = FALSE)),
    collapse = "\n"
  )
  expect_false("news_file" %in% tidy(r)$check)
  expect_false(grepl("No NEWS file found", out, fixed = TRUE))
})

test_that("checktor(): an unknown name in options(checktor.disable) warns", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  withr::local_options(checktor.disable = "news_fiel")
  expect_warning(
    checktor(pkg, verbose = FALSE, progress = FALSE),
    "news_fiel"
  )
})

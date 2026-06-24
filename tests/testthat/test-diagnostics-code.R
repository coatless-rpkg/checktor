# ---- T/F usage ---------------------------------------------------------------

test_that("diagnose_tf_usage flags bare T/F (including leading position)", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "T",                              # leading T - missed by old regex
    "  F",
    "x <- T",
    "fn <- function() F"
  ))
  res <- diagnose_tf_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 4L)
})

test_that("diagnose_tf_usage ignores T/F inside strings and comments", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "x <- 'T cells and F-stats'",
    "# T - reminder",
    "# F-statistic",
    'msg <- "T"',
    "y <- TRUE"
  ))
  res <- diagnose_tf_usage(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("diagnose_tf_usage ignores TRUE/FALSE and other words containing T or F", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "x <- TRUE",
    "y <- FALSE",
    "transform <- function() NULL",
    "field <- 1"
  ))
  res <- diagnose_tf_usage(pkg, verbose = FALSE)
  expect_true(res$passed)
})

# ---- seed setting ------------------------------------------------------------

test_that("diagnose_seed_setting flags hardcoded set.seed and ignores parameterised seeds", {
  pkg_bad <- make_temp_dir()
  write_pkg(pkg_bad, r_code = "f <- function() { set.seed(1); 1 }")
  expect_false(diagnose_seed_setting(pkg_bad, verbose = FALSE)$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, r_code = c(
    "f <- function(seed = NULL) {",
    "  if (!is.null(seed)) set.seed(seed)",
    "  runif(1)",
    "}"
  ))
  expect_true(diagnose_seed_setting(pkg_ok, verbose = FALSE)$passed)
})

# ---- print/cat ---------------------------------------------------------------

test_that("diagnose_print_cat_usage ignores cat in strings and conditional cat", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "msg <- 'cat(...)'",                # cat inside string
    "f <- function(v) if (v) cat('x')", # guarded
    "g <- function(v) { if (v) cat('y'); invisible() }"
  ))
  expect_true(diagnose_print_cat_usage(pkg, verbose = FALSE)$passed)

  pkg2 <- make_temp_dir()
  write_pkg(pkg2, r_code = "f <- function() cat('always')")
  expect_false(diagnose_print_cat_usage(pkg2, verbose = FALSE)$passed)
})

# ---- option changes ----------------------------------------------------------

test_that("diagnose_option_changes recognises on.exit and withr::local_*", {
  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, r_code = c(
    "f <- function() {",
    "  op <- options(warn = 2)",
    "  on.exit(options(op))",
    "  invisible()",
    "}",
    "g <- function() {",
    "  withr::local_options(scipen = 999)",
    "  invisible()",
    "}"
  ))
  expect_true(diagnose_option_changes(pkg_ok, verbose = FALSE)$passed)

  pkg_bad <- make_temp_dir()
  write_pkg(pkg_bad, r_code = "f <- function() options(scipen = 999)")
  expect_false(diagnose_option_changes(pkg_bad, verbose = FALSE)$passed)
})

# ---- home writing ------------------------------------------------------------

test_that("diagnose_home_writing does NOT flag formula tildes", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "fit <- function(d) lm(y ~ x, data = d)",
    "f <- function(d) update(fit, . ~ . + z)",
    "g <- function() y ~ a + b"
  ))
  expect_true(diagnose_home_writing(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_home_writing flags explicit ~ paths and HOME env", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "f <- function() file.path('~', 'data.csv')",
    "g <- function() Sys.getenv('HOME')",
    "h <- function() path.expand('~/notes')"
  ))
  res <- diagnose_home_writing(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gte(length(res$issues), 3L)
})

# ---- temp cleanup ------------------------------------------------------------

test_that("diagnose_temp_cleanup is per-tempfile and requires nearby cleanup", {
  pkg <- make_temp_dir()
  # One example with cleanup, one without. The check now requires cleanup near
  # the tempfile() call, not anywhere in the file.
  dir.create(file.path(pkg, "tests"), recursive = TRUE, showWarnings = FALSE)
  writeLines(c(
    "t1 <- tempfile()",
    "writeLines('a', t1)",
    "unlink(t1)",
    "",
    "t2 <- tempfile()",
    "writeLines('b', t2)",
    "# (no cleanup for t2)"
  ), file.path(pkg, "tests", "stuff.R"))
  write_pkg(pkg)

  res <- diagnose_temp_cleanup(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)   # only t2 should be flagged
})

test_that("diagnose_temp_cleanup ignores .Rd files (they are not R)", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("foo.Rd" = c(
    "\\name{foo}",
    "\\title{foo}",
    "\\examples{",
    "  t <- tempfile()",
    "  writeLines('x', t)",
    "}"
  )))
  # No tests/ directory ⇒ nothing to inspect ⇒ passes.
  expect_true(diagnose_temp_cleanup(pkg, verbose = FALSE)$passed)
})

# ---- globalenv modification --------------------------------------------------

test_that("diagnose_globalenv_modification flags <<- and .GlobalEnv assigns", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "x <<- 1",
    "assign('y', 1, envir = .GlobalEnv)"
  ))
  res <- diagnose_globalenv_modification(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gte(length(res$issues), 2L)
})

# ---- installed.packages ------------------------------------------------------

test_that("diagnose_installed_packages_usage flags the call but not the word", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "x <- 'installed.packages mentioned'",   # in string ⇒ ignored
    "f <- function() installed.packages()"
  ))
  res <- diagnose_installed_packages_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

# ---- warn = -1 ---------------------------------------------------------------

test_that("diagnose_warn_option finds warn = -1 in multi-arg and withr forms", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "f <- function() options(scipen = 0, warn = -1)",
    "g <- function() withr::local_options(warn = -1)",
    "h <- function() options(",
    "  scipen = 999,",
    "  warn = -1",
    ")"
  ))
  res <- diagnose_warn_option(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gte(length(res$issues), 3L)
})

# ---- software installation ---------------------------------------------------

test_that("diagnose_software_installation flags install.packages/devtools::install_*", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "f <- function() install.packages('foo')",
    "g <- function() devtools::install_github('a/b')",
    "h <- function() remotes::install_local('.')",
    "fine <- function() requireNamespace('utils')"
  ))
  res <- diagnose_software_installation(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gte(length(res$issues), 3L)
})

# ---- core usage --------------------------------------------------------------

test_that("diagnose_core_usage requires same-call core limit, not file-wide", {
  # Old check exempted a file as long as ANY `2` appeared; verify that's gone.
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "x <- 2",                                  # bare 2 elsewhere - irrelevant
    "f <- function() parallel::mclapply(1:10, fn)"  # not bounded
  ))
  res <- diagnose_core_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gte(length(res$issues), 1L)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, r_code = c(
    "f <- function() parallel::mclapply(1:10, fn, mc.cores = 2L)"
  ))
  expect_true(diagnose_core_usage(pkg_ok, verbose = FALSE)$passed)
})

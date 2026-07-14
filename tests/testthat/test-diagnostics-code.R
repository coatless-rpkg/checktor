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

test_that("diagnose_print_cat_usage ignores cat in strings and verbosity-gated cat", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "msg <- 'cat(...)'",                            # cat inside a string
    "f <- function(verbose) if (verbose) cat('x')", # gated on verbosity
    "g <- function(quiet) { if (!quiet) cat('y'); invisible() }"
  ))
  expect_true(diagnose_print_cat_usage(pkg, verbose = FALSE)$passed)

  pkg2 <- make_temp_dir()
  write_pkg(pkg2, r_code = "f <- function() cat('always')")
  expect_false(diagnose_print_cat_usage(pkg2, verbose = FALSE)$passed)
})

test_that("diagnose_print_cat_usage exempts cat/print in S3 print/format methods (#6)", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "print.myclass <- function(x, ...) {",
    "  cat(\"Object of class 'myclass'\\n\")",
    "  cat(\"Value:\", x$value, \"\\n\")",
    "  invisible(x)",
    "}",
    "format.myclass <- function(x, ...) {",
    "  cat(format(x$value))",
    "  invisible(x)",
    "}"
  ))
  expect_true(diagnose_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_print_cat_usage still flags cat in ordinary functions alongside a method", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "print.myclass <- function(x, ...) cat('exempt')",
    "analyze <- function(data) cat('always flagged')"
  ))
  res <- diagnose_print_cat_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)   # only the ordinary function's cat
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

test_that("diagnose_home_writing flags WRITES into the home directory", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    'f <- function(x) writeLines(x, "~/leaked.txt")',
    'g <- function(x) saveRDS(x, "~/.myapp/cache.rds")',
    'h <- function(x) write.csv(x, file = file.path(Sys.getenv("HOME"), "o.csv"))'
  ))
  res <- diagnose_home_writing(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 3L)
})

test_that("diagnose_home_writing does not flag reads of the home path", {
  # The old check inspected only path.expand/normalizePath/file.path/Sys.getenv,
  # which are all reads: it flagged these while MISSING the writes above.
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "f <- function() path.expand('~')",
    "g <- function() Sys.getenv('HOME')",
    "h <- function() normalizePath('~')",
    "i <- function() file.path('~', 'data.csv')"
  ))
  expect_true(diagnose_home_writing(pkg, verbose = FALSE)$passed)
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

test_that("diagnose_globalenv_modification flags a <<- that binds nowhere", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "leaky <- function() {",
    "  undeclared_global <<- 1",
    "  invisible(NULL)",
    "}"
  ))
  res <- diagnose_globalenv_modification(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

test_that("diagnose_globalenv_modification exempts closures and package-level caches", {
  # `<<-` walks the enclosing environments and assigns in the first frame where
  # the name is already bound; it only reaches .GlobalEnv when the name is bound
  # nowhere else. Flagging every `<<-` false-positives on both correct idioms.
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    ".cache <- NULL",
    "memoise <- function(x) { .cache <<- x; .cache }",   # package-level cache
    "validate <- function(d) {",
    "  results <- list(errors = character(0))",
    "  add_error <- function(msg) results$errors <<- c(results$errors, msg)",
    "  add_error('boom')",
    "  results",
    "}",
    "reader <- function(nm) exists(nm, envir = globalenv())"  # a pure READ
  ))
  expect_true(diagnose_globalenv_modification(pkg, verbose = FALSE)$passed)
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

test_that("option_changes exempts a setter that captures and returns the old value", {
  # options()/par()/setwd() return the previous value, so capturing it and
  # handing it back is the base R setter contract, not a leak.
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "cfg <- function(x) {",
    "  old <- options(digits = x)",
    "  invisible(old)",
    "}"
  ))
  expect_true(diagnose_option_changes(pkg, verbose = FALSE)$passed)
})

test_that("option_changes still flags a bare options() whose old value is discarded", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "leak <- function(x) {",
    "  options(digits = x)",
    "  invisible(NULL)",
    "}"
  ))
  res <- diagnose_option_changes(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

# ---- core usage (redesigned) --------------------------------------------------

test_that("diagnose_core_usage flags an unbounded worker count across frameworks", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "a <- function(x) parallel::mclapply(x, f, mc.cores = parallel::detectCores())",
    "b <- function(x) parallel::makeCluster(8)",
    "c1 <- function(x) doParallel::registerDoParallel(cores = detectCores())",
    "d <- function() future::plan(future::multisession, workers = 12)",
    "e <- function() mirai::daemons(6)",
    "f1 <- function() RcppParallel::setThreadOptions(numThreads = detectCores())",
    "g <- function() data.table::setDTthreads(16)",
    "h <- function() BiocParallel::MulticoreParam(workers = detectCores())",
    "i1 <- function() doMC::registerDoMC(cores = 8)"
  ))
  res <- diagnose_core_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 9L)
})

test_that("diagnose_core_usage exempts a CRAN-guarded worker count", {
  # This is logitr's and cbcTools' real guard, and it is byte-for-byte R's own
  # parallel:::.check_ncores predicate. The old check flagged it anyway, because
  # it demanded an `mc.cores` argument on the detectCores() call itself, which
  # detectCores() can never carry.
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "set_num_cores <- function(n) {",
    "  chk <- tolower(Sys.getenv('_R_CHECK_LIMIT_CORES_', ''))",
    "  if (nzchar(chk) && (chk != 'false')) return(2L)",
    "  cores <- parallel::detectCores()",
    "  parallel::makeCluster(cores - 1)",
    "}"
  ))
  expect_true(diagnose_core_usage(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_core_usage exempts availableCores, a <=2 literal, and defaults", {
  # Measured under _R_CHECK_LIMIT_CORES_=TRUE: detectCores() returns 12 while
  # parallelly/future availableCores() return 2, so availableCores() is the safe idiom.
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "a <- function() future::plan(future::multisession, workers = parallelly::availableCores())",
    "b <- function(x) parallel::makeCluster(2L)",
    "c1 <- function(x) parallel::mclapply(x, f, mc.cores = 2L)",
    "d <- function(x) parallel::mclapply(x, f)",          # default mc.cores is 2L
    "e <- function() parallel::makeCluster(cl_spec)"      # unresolvable: do not guess
  ))
  expect_true(diagnose_core_usage(pkg, verbose = FALSE)$passed)
})

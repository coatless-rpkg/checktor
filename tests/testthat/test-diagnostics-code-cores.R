# Test lab_core_usage() ----

test_that("lab_core_usage(): flags unbounded worker counts across frameworks", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function(x) parallel::mclapply(x, f, mc.cores = parallel::detectCores())",
      "b <- function(x) parallel::makeCluster(8)",
      "c1 <- function(x) doParallel::registerDoParallel(cores = detectCores())",
      "d <- function() future::plan(future::multisession, workers = 12)",
      "e <- function() mirai::daemons(6)",
      "f1 <- function() RcppParallel::setThreadOptions(numThreads = detectCores())",
      "g <- function() data.table::setDTthreads(16)",
      "h <- function() BiocParallel::MulticoreParam(workers = detectCores())",
      "i1 <- function() doMC::registerDoMC(cores = 8)"
    )
  )
  res <- lab_core_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 9L)
})

test_that("lab_core_usage(): exempts a CRAN-guarded worker count", {
  # This is logitr's and cbcTools' real guard, and it is byte-for-byte R's own
  # parallel:::.check_ncores predicate. The old check flagged it anyway, because
  # it demanded an `mc.cores` argument on the detectCores() call itself, which
  # detectCores() can never carry.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "set_num_cores <- function(n) {",
      "  chk <- tolower(Sys.getenv('_R_CHECK_LIMIT_CORES_', ''))",
      "  if (nzchar(chk) && (chk != 'false')) return(2L)",
      "  cores <- parallel::detectCores()",
      "  parallel::makeCluster(cores - 1)",
      "}"
    )
  )
  expect_true(lab_core_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_core_usage(): exempts availableCores, <=2 literals, defaults", {
  # Measured under _R_CHECK_LIMIT_CORES_=TRUE: detectCores() returns 12 while
  # parallelly/future availableCores() return 2, so availableCores() is the safe idiom.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function() future::plan(future::multisession, workers = parallelly::availableCores())",
      "b <- function(x) parallel::makeCluster(2L)",
      "c1 <- function(x) parallel::mclapply(x, f, mc.cores = 2L)",
      "d <- function(x) parallel::mclapply(x, f)", # default mc.cores is 2L
      "e <- function() parallel::makeCluster(cl_spec)" # unresolvable: do not guess
    )
  )
  expect_true(lab_core_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_core_usage(): draws the line at two, not a larger number", {
  # CRAN's ceiling is a hard two ("it must never use more than two
  # simultaneously"), so 3 is a breach even though it is modest. Every other
  # fixture in this file sits at 8 or above, which leaves 3..5 untested and the
  # threshold free to drift upward unnoticed.
  pkg_bad <- make_temp_dir()
  write_pkg(pkg_bad, r_code = "f <- function() parallel::makeCluster(3L)")
  res <- lab_core_usage(pkg_bad, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, r_code = "f <- function() parallel::makeCluster(2L)")
  expect_true(lab_core_usage(pkg_ok, verbose = FALSE)$passed)
})

test_that("lab_core_usage(): makeCluster(2L) is CRAN-compliant, not a violation", {
  # cbcTools/R/design.R. The old rule demanded an mc.cores argument, which
  # makeCluster() does not take, so a compliant call was flagged 100% of the time.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "setup <- function() {",
      "  cl <- parallel::makeCluster(2L)",
      "  on.exit(parallel::stopCluster(cl))",
      "  cl",
      "}"
    )
  )
  expect_true(lab_core_usage(pkg, verbose = FALSE)$passed)
})

# Test lab_detect_cores_robustness() ----

test_that("lab_detect_cores_robustness(): flags an unguarded detectCores()", {
  # logitr and cbcTools both do this. ?detectCores says "An integer, NA if the
  # answer is unknown", and NA - 1 is NA, so the next comparison errors with
  # "missing value where TRUE/FALSE needed".
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "set_num_cores <- function(n) {",
      "  available <- parallel::detectCores()",
      "  max_cores <- available - 1",
      "  if (n > max_cores) n <- max_cores",
      "  n",
      "}"
    )
  )
  res <- lab_detect_cores_robustness(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "may return NA", all = FALSE)
})

test_that("lab_detect_cores_robustness(): accepts an is.na() guard", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "set_num_cores <- function(n) {",
      "  available <- parallel::detectCores()",
      "  if (is.na(available)) available <- 1L",
      "  min(n, available)",
      "}"
    )
  )
  expect_true(lab_detect_cores_robustness(pkg, verbose = FALSE)$passed)
})

test_that("lab_detect_cores_robustness(): is silent when it is never called", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() parallelly::availableCores()")
  expect_true(lab_detect_cores_robustness(pkg, verbose = FALSE)$passed)
})

test_that("lab_detect_cores_robustness(): an unguarded detectCores() is caught", {
  # logitr/R/modelInputs.R setNumCores(), cbcTools/R/util.R. ?detectCores: "An
  # integer, NA if the answer is unknown". NA - 1 is NA, and the comparison below
  # then errors with "missing value where TRUE/FALSE needed" -- reproduced live.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "setNumCores <- function(numCores) {",
      "  coresAvailable <- parallel::detectCores()",
      "  maxCores <- coresAvailable - 1",
      "  if (numCores > maxCores) numCores <- maxCores",
      "  numCores",
      "}"
    )
  )
  expect_false(lab_detect_cores_robustness(pkg, verbose = FALSE)$passed)
})

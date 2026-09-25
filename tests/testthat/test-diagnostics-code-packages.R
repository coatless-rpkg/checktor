# Test lab_installed_packages() ----

test_that("lab_installed_packages(): flags the call but not the word", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "x <- 'installed.packages mentioned'", # in string ⇒ ignored
      "f <- function() installed.packages()"
    )
  )
  res <- lab_installed_packages(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

test_that("lab_installed_packages(): is quiet on the recommended idioms", {
  # The treatment line names requireNamespace() and find.package(); a package that
  # already took that advice must come back clean.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() requireNamespace('utils', quietly = TRUE)",
      "g <- function() find.package('utils')",
      "h <- function() utils::available.packages()"
    )
  )
  expect_true(lab_installed_packages(pkg, verbose = FALSE)$passed)
})

# Test lab_software_install() ----

test_that("lab_software_install(): flags install.packages and install_*", {
  # `fine()` is the control: requireNamespace() is the conditional-Suggests idiom
  # Writing R Extensions prescribes, and it installs nothing. The count is exact so
  # that treating it as an install shows up here.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() install.packages('foo')",
      "g <- function() devtools::install_github('a/b')",
      "h <- function() remotes::install_local('.')",
      "fine <- function() requireNamespace('utils')"
    )
  )
  res <- lab_software_install(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 3L)
})

test_that("lab_software_install(): an install behind a consent prompt is consent", {
  # CRAN's objection is installing WITHOUT ASKING. rlang, devtools and usethis all
  # prompt first, which is the only way an install helper can exist at all.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "maybe_install <- function(pkg) {",
      "  if (yesno(paste('Install', pkg, '?'))) {",
      "    install.packages(pkg)",
      "  }",
      "}"
    )
  )
  expect_true(lab_software_install(pkg, verbose = FALSE)$passed)

  bad <- make_temp_dir()
  write_pkg(bad, r_code = "f <- function() install.packages('dplyr')")
  expect_false(lab_software_install(bad, verbose = FALSE)$passed)
})

# Test lab_library_in_pkg() ----

test_that("lab_library_in_pkg(): exempts library() sent to a parallel worker", {
  # A daemon starts with an empty search path, so library() there sets up the
  # WORKER's path, not the user's. logitr does this via mirai::everywhere().
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "run <- function(cl) {",
      "  mirai::everywhere({ library(logitr) }, .compute = 'logitr')",
      "  parallel::clusterEvalQ(cl, library(stats))",
      "}"
    )
  )
  expect_true(lab_library_in_pkg(pkg, verbose = FALSE)$passed)
})

test_that("lab_library_in_pkg(): still flags library() in ordinary code", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() { library(dplyr); mutate(x) }")
  expect_false(lab_library_in_pkg(pkg, verbose = FALSE)$passed)
})

test_that("lab_library_in_pkg(): does not read $library() as base::library()", {
  # `api$library(...)` is a member of whatever `api` is, and nothing to do with
  # attaching a package. The check carries NOT_MEMBER_ACCESS for exactly this.
  pkg_ok <- make_temp_dir()
  write_pkg(
    pkg_ok,
    r_code = "run <- function(api) { api$library('x'); api$require('y') }"
  )
  expect_true(lab_library_in_pkg(pkg_ok, verbose = FALSE)$passed)

  # ...and the genuine call in the same shape of file is still reported, so the
  # exemption cannot be widened into a blanket one.
  pkg_bad <- make_temp_dir()
  write_pkg(
    pkg_bad,
    r_code = c(
      "run <- function(api) { api$library('x'); api$require('y') }",
      "go <- function() { library(stats); median(1:3) }"
    )
  )
  res <- lab_library_in_pkg(pkg_bad, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

test_that("lab_library_in_pkg(): flags library()/require() but not pkg::fn", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() {",
      "  library(stats)",
      "  require(stats)",
      "  utils::head(1:5)",
      "}"
    )
  )
  res <- lab_library_in_pkg(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)
})

test_that("lab_library_in_pkg(): library() sent to a parallel daemon is not a search-path change", {
  # logitr/R/optimLoop.R. A daemon starts with an empty search path.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "run_multistart <- function(mi) {",
      "  mirai::everywhere(",
      "    { library(logitr); RcppParallel::setThreadOptions(numThreads = nThreads) },",
      "    .args = list(nThreads = 1L), .compute = 'logitr'",
      "  )",
      "}"
    )
  )
  expect_true(lab_library_in_pkg(pkg, verbose = FALSE)$passed)
})

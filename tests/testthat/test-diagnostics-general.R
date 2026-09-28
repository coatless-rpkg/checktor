# A test that names a CRAN package reproduces a false positive or a missed
# finding from that package's real sources, so a regression fails here first.

# Test lab_package_size() ----

test_that("lab_package_size(): excludes a large .Rbuildignore'd docs/ tree", {
  # The pkgdown case: an untracked docs/ excluded by a bare `^docs$` must not
  # count. 6 MB of incompressible bytes would blow the 5 MB limit if counted.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(c("^docs$"), file.path(pkg, ".Rbuildignore"))
  dir.create(file.path(pkg, "docs", "reference"), recursive = TRUE)
  withr::local_seed(1)
  writeBin(
    as.raw(sample(0:255, 6 * 1024 * 1024, replace = TRUE)),
    file.path(pkg, "docs", "reference", "big.bin")
  )
  res <- lab_package_size(pkg, verbose = FALSE)
  expect_lt(res$size_mb, 1)
  expect_true(res$passed)
})

test_that("lab_package_size(): still flags genuinely large packages", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # 6 MB of INCOMPRESSIBLE bytes in inst/. The size check measures the gzipped
  # size, as CRAN's limit does, so this fixture must not be compressible: a file
  # of 6 MB of zeroes gzips down to a few kilobytes and is under the limit, which
  # is the correct answer.
  dir.create(file.path(pkg, "inst"), recursive = TRUE)
  withr::local_seed(1)
  writeBin(
    as.raw(sample(0:255, 6 * 1024 * 1024, replace = TRUE)),
    file.path(pkg, "inst", "bigdata.bin")
  )
  res <- lab_package_size(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gt(res$size_mb, 5)
})

test_that("lab_package_size(): measures the COMPRESSED size CRAN limits", {
  # CRAN's 5 MB limit is on the gzipped tarball. billboarder is 6.3 MB on disk and
  # 2.93 MB as a tarball; every package_size finding in the audit was this mistake.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "inst"), showWarnings = FALSE)
  # 8 MB of highly compressible text: over the limit raw, far under it compressed.
  writeLines(
    rep(paste(rep("a", 100), collapse = ""), 80000),
    file.path(pkg, "inst", "big.csv")
  )
  res <- lab_package_size(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_lt(res$size_mb, 5)
})

# Test lab_news_file() ----

test_that("lab_news_file(): flags a missing NEWS, accepts one present", {
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  expect_false(lab_news_file(pkg, verbose = FALSE)$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok) # NEWS.md created by default
  expect_true(lab_news_file(pkg_ok, verbose = FALSE)$passed)
})

test_that("lab_news_file(): accepts NEWS under inst/", {
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  dir.create(file.path(pkg, "inst"))
  writeLines("# pkg 0.1.0", file.path(pkg, "inst", "NEWS.md"))
  expect_true(lab_news_file(pkg, verbose = FALSE)$passed)
})

# Test lab_cran_comments_file() ----

test_that("lab_cran_comments_file(): flags absence, accepts presence", {
  pkg <- make_temp_dir()
  write_pkg(pkg, cran_comments = FALSE)
  expect_false(lab_cran_comments_file(pkg, verbose = FALSE)$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok) # cran-comments.md created by default
  expect_true(lab_cran_comments_file(pkg_ok, verbose = FALSE)$passed)
})

# Test lab_code_exercised() ----

test_that("lab_code_exercised(): flags exports with no examples, tests or vignettes", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(test_fn)", file.path(pkg, "NAMESPACE"))
  res <- lab_code_exercised(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_length(res$issues, 1L)
  expect_match(res$issues, "no examples, no tests and no vignettes")
})

test_that("lab_code_exercised(): any one of the three is enough", {
  exported <- function() {
    pkg <- make_temp_dir(envir = parent.frame())
    write_pkg(pkg)
    writeLines("export(test_fn)", file.path(pkg, "NAMESPACE"))
    pkg
  }

  # An example, even one R CMD check never runs: Rd2ex still writes it out.
  with_example <- exported()
  writeLines(
    c(
      "\\name{f}",
      "\\alias{f}",
      "\\title{F}",
      "\\description{d}",
      "\\examples{\\dontrun{test_fn()}}"
    ),
    file.path(with_example, "man", "f.Rd")
  )
  expect_true(lab_code_exercised(with_example, verbose = FALSE)$passed)

  with_test <- exported()
  dir.create(file.path(with_test, "tests"))
  writeLines("library(testthat)", file.path(with_test, "tests", "testthat.R"))
  expect_true(lab_code_exercised(with_test, verbose = FALSE)$passed)

  with_vignette <- exported()
  dir.create(file.path(with_vignette, "vignettes"))
  writeLines("text", file.path(with_vignette, "vignettes", "intro.qmd"))
  expect_true(lab_code_exercised(with_vignette, verbose = FALSE)$passed)
})

test_that("lab_code_exercised(): judges what the tarball includes", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(test_fn)", file.path(pkg, "NAMESPACE"))
  dir.create(file.path(pkg, "tests"))
  writeLines("stopifnot(TRUE)", file.path(pkg, "tests", "local.R"))
  dir.create(file.path(pkg, "vignettes"))
  writeLines("text", file.path(pkg, "vignettes", "draft.Rmd"))
  writeLines(
    c("^tests$", "^vignettes/draft\\.Rmd$"),
    file.path(pkg, ".Rbuildignore")
  )
  expect_false(lab_code_exercised(pkg, verbose = FALSE)$passed)
})

test_that("lab_code_exercised(): tests R CMD check never runs do not count", {
  # R CMD check runs tests/*.R. A tests/testthat/ folder with no driver in tests/
  # is never run, so CRAN still sees no tests, and the finding says why.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(test_fn)", file.path(pkg, "NAMESPACE"))
  dir.create(file.path(pkg, "tests", "testthat"), recursive = TRUE)
  writeLines(
    "test_that('x', expect_true(TRUE))",
    file.path(pkg, "tests", "testthat", "test-x.R")
  )
  res <- lab_code_exercised(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "tests/testthat.R", fixed = TRUE)
})

test_that("lab_code_exercised(): stays quiet when nothing is exported", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("importFrom(stats, sd)", file.path(pkg, "NAMESPACE"))
  expect_true(lab_code_exercised(pkg, verbose = FALSE)$passed)

  # S3 methods and export patterns count as exports, as they do for R.
  writeLines("S3method(print, foo)", file.path(pkg, "NAMESPACE"))
  expect_false(lab_code_exercised(pkg, verbose = FALSE)$passed)
  writeLines("exportPattern('^[[:alpha:]]+')", file.path(pkg, "NAMESPACE"))
  expect_false(lab_code_exercised(pkg, verbose = FALSE)$passed)
})

test_that("lab_code_exercised(): does not guess without a NAMESPACE or R/", {
  # No NAMESPACE, or one R cannot parse: the exports are unknown, so no finding.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_code_exercised(pkg, verbose = FALSE)$passed)
  writeLines("export(", file.path(pkg, "NAMESPACE"))
  expect_true(lab_code_exercised(pkg, verbose = FALSE)$passed)

  # A data-only package has no R/ to exercise; R skips the check too.
  data_only <- make_temp_dir()
  write_pkg(data_only, r_code = NULL)
  unlink(file.path(data_only, "R"), recursive = TRUE)
  writeLines("exportPattern('.')", file.path(data_only, "NAMESPACE"))
  expect_true(lab_code_exercised(data_only, verbose = FALSE)$passed)
})

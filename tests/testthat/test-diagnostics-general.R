# ---- package size ------------------------------------------------------------

test_that("lab_package_size excludes .Rbuildignore'd directories", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  # Add a faux .git directory that would inflate size if included.
  big_dir <- file.path(pkg, ".git")
  dir.create(big_dir, recursive = TRUE)
  writeLines(rep("x", 1e5), file.path(big_dir, "huge.txt"))

  # Add it to .Rbuildignore so the matcher excludes it (also matched by
  # the always-skip set).
  writeLines(c("^\\.git$"), file.path(pkg, ".Rbuildignore"))

  res <- lab_package_size(pkg, verbose = FALSE)
  # The fake huge file is ~ 200 KB but checked exclusion should keep us well
  # under the 5 MB threshold.
  expect_lt(res$size_mb, 1)
  expect_true(res$passed)
})

test_that("lab_package_size excludes a large .Rbuildignore'd docs/ tree", {
  # The pkgdown case: an untracked docs/ excluded by a bare `^docs$` must not
  # count. 6 MB of incompressible bytes would blow the 5 MB limit if counted.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(c("^docs$"), file.path(pkg, ".Rbuildignore"))
  dir.create(file.path(pkg, "docs", "reference"), recursive = TRUE)
  set.seed(1)
  writeBin(
    as.raw(sample(0:255, 6 * 1024 * 1024, replace = TRUE)),
    file.path(pkg, "docs", "reference", "big.bin")
  )
  res <- lab_package_size(pkg, verbose = FALSE)
  expect_lt(res$size_mb, 1)
  expect_true(res$passed)
})

test_that("lab_package_size still flags genuinely large packages", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # 6 MB of INCOMPRESSIBLE bytes in inst/. The size check measures the gzipped
  # size, as CRAN's limit does, so this fixture must not be compressible: a file
  # of 6 MB of zeroes gzips down to a few kilobytes and is under the limit, which
  # is the correct answer.
  dir.create(file.path(pkg, "inst"), recursive = TRUE)
  set.seed(1)
  writeBin(
    as.raw(sample(0:255, 6 * 1024 * 1024, replace = TRUE)),
    file.path(pkg, "inst", "bigdata.bin")
  )
  res <- lab_package_size(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gt(res$size_mb, 5)
})

# ---- URLs --------------------------------------------------------------------

# ---- NEWS file ---------------------------------------------------------------

test_that("lab_news_file flags a missing NEWS, accepts one present", {
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  expect_false(lab_news_file(pkg, verbose = FALSE)$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok) # NEWS.md created by default
  expect_true(lab_news_file(pkg_ok, verbose = FALSE)$passed)
})

test_that("lab_news_file accepts NEWS under inst/", {
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  dir.create(file.path(pkg, "inst"))
  writeLines("# pkg 0.1.0", file.path(pkg, "inst", "NEWS.md"))
  expect_true(lab_news_file(pkg, verbose = FALSE)$passed)
})

# ---- cran-comments.md --------------------------------------------------------

test_that("lab_cran_comments_file flags absence, accepts presence", {
  pkg <- make_temp_dir()
  write_pkg(pkg, cran_comments = FALSE)
  expect_false(lab_cran_comments_file(pkg, verbose = FALSE)$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok) # cran-comments.md created by default
  expect_true(lab_cran_comments_file(pkg_ok, verbose = FALSE)$passed)
})

# ---- README relative links ---------------------------------------------------

test_that("lab_readme_links flags a link to a missing file", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    "See [the guide](docs/guide.md) for details.",
    file.path(pkg, "README.md")
  )
  res <- lab_readme_links(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("lab_readme_links flags links to .Rbuildignore'd files", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    "See the [code of conduct](CODE_OF_CONDUCT.md).",
    file.path(pkg, "README.md")
  )
  writeLines("Our pledge ...", file.path(pkg, "CODE_OF_CONDUCT.md"))
  writeLines("^CODE_OF_CONDUCT\\.md$", file.path(pkg, ".Rbuildignore"))
  res <- lab_readme_links(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("lab_readme_links accepts absolute URLs and shipped files", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "man", "figures"), recursive = TRUE)
  writeLines("x", file.path(pkg, "man", "figures", "logo.png"))
  writeLines(
    c(
      "Full link: [site](https://example.com).",
      "Anchor: [top](#intro).",
      "Shipped image: ![logo](man/figures/logo.png)."
    ),
    file.path(pkg, "README.md")
  )
  res <- lab_readme_links(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("lab_readme_links passes when there is no README", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_readme_links(pkg, verbose = FALSE)$passed)
})

# --- urls (restored, improved) ---------------------------------------------

test_that("lab_urls flags an insecure http:// and names the URL", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c("# Pkg", "See <http://example.com/docs> for details."),
    file.path(pkg, "README.md")
  )

  res <- lab_urls(pkg, verbose = FALSE)
  expect_false(res$passed)
  # The finding must name the URL, not just the file, or it is not actionable.
  expect_match(res$issues, "http://example.com/docs", fixed = TRUE, all = FALSE)
})

test_that("lab_urls ignores an http:// inside a fenced code block", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "# Pkg",
      "```r",
      "# a literal string, not a link",
      "download.file(\"http://example.com/data.csv\", tmp)",
      "```"
    ),
    file.path(pkg, "README.md")
  )

  expect_true(lab_urls(pkg, verbose = FALSE)$passed)
})

test_that("lab_urls ignores an http:// inside an Rd \\verb or \\code span", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "man"), showWarnings = FALSE)
  writeLines(
    c(
      "\\name{f}",
      "\\alias{f}",
      "\\title{F}",
      "\\description{Matches \\verb{http://example.com} literally.}",
      "\\value{NULL}"
    ),
    file.path(pkg, "man", "f.Rd")
  )

  expect_true(lab_urls(pkg, verbose = FALSE)$passed)
})

test_that("lab_urls still flags a real Rd link outside a literal span", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "man"), showWarnings = FALSE)
  writeLines(
    c(
      "\\name{f}",
      "\\alias{f}",
      "\\title{F}",
      "\\description{See \\url{http://example.com} for more.}",
      "\\value{NULL}"
    ),
    file.path(pkg, "man", "f.Rd")
  )

  res <- lab_urls(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("lab_url_liveness does not reach the network outside the console", {
  # The default is interactive(), so a script, a CI run and R CMD check all leave
  # it off. That is what keeps examples and tests from needing a network.
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "URL: https://nonexistent-host.checktor.invalid/")

  fetched <- FALSE
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) {
      fetched <<- TRUE
      data.frame()
    }
  )
  old <- options(checktor.url_check = NULL) # unset: fall back to the default
  on.exit(options(old), add = TRUE)

  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_false(fetched)
  expect_true(res$passed)
  expect_length(res$issues, 0L)
})

test_that("lab_url_liveness reaches the network when asked to", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  fetched <- FALSE
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) {
      fetched <<- TRUE
      data.frame()
    }
  )
  old <- options(checktor.url_check = TRUE)
  on.exit(options(old), add = TRUE)

  expect_true(lab_url_liveness(pkg, verbose = FALSE)$passed)
  expect_true(fetched)
})

test_that("lab_url_liveness surfaces the broken URLs the fetch reports", {
  # Stub the network fetch so the test is deterministic and never leaves the
  # machine. The real fetch is base R's tools::check_package_urls(), whose
  # behaviour is environment-dependent (and absent without a network).
  pkg <- make_temp_dir()
  write_pkg(pkg)
  old <- options(checktor.url_check = TRUE)
  on.exit(options(old), add = TRUE)

  fake_db <- data.frame(
    URL = "https://example.com/missing",
    From = "DESCRIPTION",
    Status = "404",
    Message = "Not Found",
    New = "",
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(fetch_url_db = function(path) fake_db)
  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "example.com/missing", all = FALSE)
  expect_match(res$issues, "404", all = FALSE)
})

test_that("lab_url_liveness passes when the fetch reports nothing", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  old <- options(checktor.url_check = TRUE)
  on.exit(options(old), add = TRUE)
  testthat::local_mocked_bindings(fetch_url_db = function(path) data.frame())
  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_length(res$issues, 0L)
  # Nothing to check is a genuine pass, not a skip: there is nothing to be wrong.
  expect_false(isTRUE(res$skipped))
})

test_that("lab_url_liveness reports a failed fetch as not checked, not as a pass", {
  # Being offline -- or a change under the fetch -- used to read exactly like a
  # package whose every URL resolved, which is the one thing a skip exists to
  # prevent.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  old <- options(checktor.url_check = TRUE)
  on.exit(options(old), add = TRUE)
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) stop("fetch did not complete")
  )
  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_true(res$skipped)
})

test_that("fetch_url_db really calls base R and returns the columns we read", {
  # Every other liveness test mocks fetch_url_db, and lab_url_liveness turns a
  # failed fetch into a *passing* result -- so a broken tools:: call would leave
  # every URL unchecked with the suite still green. This pins the seam itself.
  # A package with no URLs needs no network: check_package_urls() has nothing to
  # fetch and returns an empty db immediately, so this runs everywhere.
  pkg <- make_temp_dir()
  write_pkg(pkg) # no URL: field, so there is nothing to fetch

  db <- suppressWarnings(suppressMessages(fetch_url_db(pkg)))
  expect_s3_class(db, "data.frame")
  expect_equal(nrow(db), 0L)
  # lab_url_liveness reads these five columns by name when building issues.
  expect_true(all(c("URL", "From", "Status", "Message", "New") %in% names(db)))
})

test_that("lab_url_liveness passes a reachable URL end to end", {
  skip_on_cran() # CRAN policy: tests must not require network access
  # A real run against tools::check_package_urls(), no mock. A reachable URL must
  # not be flagged. This direction is robust to a network-less runner: with no
  # network the fetch reports nothing and the check still passes, so the only way
  # it fails is if the URL genuinely breaks. CRAN's own site is the most stable
  # choice and never rate-limits R's URL checker.
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "URL: https://cran.r-project.org/")
  old <- options(checktor.url_check = TRUE)
  on.exit(options(old), add = TRUE)
  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_length(res$issues, 0L)
})

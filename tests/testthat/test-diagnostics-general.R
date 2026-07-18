# ---- package size ------------------------------------------------------------

test_that("diagnose_package_size excludes .Rbuildignore'd directories", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  # Add a faux .git directory that would inflate size if included.
  big_dir <- file.path(pkg, ".git")
  dir.create(big_dir, recursive = TRUE)
  writeLines(rep("x", 1e5), file.path(big_dir, "huge.txt"))

  # Add it to .Rbuildignore so the matcher excludes it (also matched by
  # the always-skip set).
  writeLines(c("^\\.git$"), file.path(pkg, ".Rbuildignore"))

  res <- diagnose_package_size(pkg, verbose = FALSE)
  # The fake huge file is ~ 200 KB but checked exclusion should keep us well
  # under the 5 MB threshold.
  expect_lt(res$size_mb, 1)
  expect_true(res$passed)
})

test_that("diagnose_package_size excludes a large .Rbuildignore'd docs/ tree", {
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
  res <- diagnose_package_size(pkg, verbose = FALSE)
  expect_lt(res$size_mb, 1)
  expect_true(res$passed)
})

test_that("diagnose_package_size still flags genuinely large packages", {
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
  res <- diagnose_package_size(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gt(res$size_mb, 5)
})

# ---- URLs --------------------------------------------------------------------

# ---- NEWS file ---------------------------------------------------------------

test_that("diagnose_news_file flags a missing NEWS, accepts one present", {
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  expect_false(diagnose_news_file(pkg, verbose = FALSE)$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok) # NEWS.md created by default
  expect_true(diagnose_news_file(pkg_ok, verbose = FALSE)$passed)
})

test_that("diagnose_news_file accepts NEWS under inst/", {
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  dir.create(file.path(pkg, "inst"))
  writeLines("# pkg 0.1.0", file.path(pkg, "inst", "NEWS.md"))
  expect_true(diagnose_news_file(pkg, verbose = FALSE)$passed)
})

# ---- cran-comments.md --------------------------------------------------------

test_that("diagnose_cran_comments_file flags absence, accepts presence", {
  pkg <- make_temp_dir()
  write_pkg(pkg, cran_comments = FALSE)
  expect_false(diagnose_cran_comments_file(pkg, verbose = FALSE)$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok) # cran-comments.md created by default
  expect_true(diagnose_cran_comments_file(pkg_ok, verbose = FALSE)$passed)
})

# ---- README relative links ---------------------------------------------------

test_that("diagnose_readme_relative_links flags a link to a missing file", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    "See [the guide](docs/guide.md) for details.",
    file.path(pkg, "README.md")
  )
  res <- diagnose_readme_relative_links(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("diagnose_readme_relative_links flags links to .Rbuildignore'd files", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    "See the [code of conduct](CODE_OF_CONDUCT.md).",
    file.path(pkg, "README.md")
  )
  writeLines("Our pledge ...", file.path(pkg, "CODE_OF_CONDUCT.md"))
  writeLines("^CODE_OF_CONDUCT\\.md$", file.path(pkg, ".Rbuildignore"))
  res <- diagnose_readme_relative_links(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("diagnose_readme_relative_links accepts absolute URLs and shipped files", {
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
  res <- diagnose_readme_relative_links(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("diagnose_readme_relative_links passes when there is no README", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(diagnose_readme_relative_links(pkg, verbose = FALSE)$passed)
})

# --- urls (restored, improved) ---------------------------------------------

test_that("diagnose_urls flags an insecure http:// and names the URL", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c("# Pkg", "See <http://example.com/docs> for details."),
    file.path(pkg, "README.md")
  )

  res <- diagnose_urls(pkg, verbose = FALSE)
  expect_false(res$passed)
  # The finding must name the URL, not just the file, or it is not actionable.
  expect_match(res$issues, "http://example.com/docs", fixed = TRUE, all = FALSE)
})

test_that("diagnose_urls ignores an http:// inside a fenced code block", {
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

  expect_true(diagnose_urls(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_urls ignores an http:// inside an Rd \\verb or \\code span", {
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

  expect_true(diagnose_urls(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_urls still flags a real Rd link outside a literal span", {
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

  res <- diagnose_urls(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("diagnose_url_liveness stays offline unless opted in", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "URL: https://nonexistent-host.checktor.invalid/")
  # The option is off (setup.R pins it), so the check must not touch the network.
  res <- diagnose_url_liveness(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_length(res$issues, 0L)
})

test_that("diagnose_url_liveness flags an unresolvable URL when opted in", {
  skip_on_cran() # never fetch over the network on CRAN's machines
  pkg <- make_temp_dir()
  # A reserved .invalid host never resolves, so this fails deterministically
  # (no live-internet dependency) yet exercises the real fetch path.
  write_pkg(pkg, extra = "URL: https://nonexistent-host.checktor.invalid/")
  old <- options(checktor.url_check = TRUE)
  on.exit(options(old), add = TRUE)
  res <- diagnose_url_liveness(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "checktor.invalid", all = FALSE)
})

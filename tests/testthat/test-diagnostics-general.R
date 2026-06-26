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

test_that("diagnose_package_size still flags genuinely large packages", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # Write a 6 MB file in inst/ that is NOT ignored.
  dir.create(file.path(pkg, "inst"), recursive = TRUE)
  writeBin(raw(6 * 1024 * 1024), file.path(pkg, "inst", "bigdata.bin"))
  res <- diagnose_package_size(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gt(res$size_mb, 5)
})

# ---- URLs --------------------------------------------------------------------

test_that("diagnose_urls flags http:// in DESCRIPTION URL field", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = c("URL: http://example.com"))
  res <- diagnose_urls(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("diagnose_urls accepts https://", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = c("URL: https://example.com"))
  res <- diagnose_urls(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("diagnose_urls ignores http:// localhost", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # Local references in a README:
  writeLines(c("Run http://localhost:8000 to test."),
             file.path(pkg, "README.md"))
  res <- diagnose_urls(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("diagnose_urls flags known URL shorteners", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("See https://bit.ly/abcdef for details.",
             file.path(pkg, "README.md"))
  res <- diagnose_urls(pkg, verbose = FALSE)
  expect_false(res$passed)
})

# ---- NEWS file ---------------------------------------------------------------

test_that("diagnose_news_file flags a missing NEWS, accepts one present", {
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  expect_false(diagnose_news_file(pkg, verbose = FALSE)$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok)                     # NEWS.md created by default
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
  write_pkg(pkg_ok)                     # cran-comments.md created by default
  expect_true(diagnose_cran_comments_file(pkg_ok, verbose = FALSE)$passed)
})

# ---- README relative links ---------------------------------------------------

test_that("diagnose_readme_relative_links flags a link to a missing file", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("See [the guide](docs/guide.md) for details.",
             file.path(pkg, "README.md"))
  res <- diagnose_readme_relative_links(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("diagnose_readme_relative_links flags links to .Rbuildignore'd files", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("See the [code of conduct](CODE_OF_CONDUCT.md).",
             file.path(pkg, "README.md"))
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
  writeLines(c("Full link: [site](https://example.com).",
               "Anchor: [top](#intro).",
               "Shipped image: ![logo](man/figures/logo.png)."),
             file.path(pkg, "README.md"))
  res <- diagnose_readme_relative_links(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("diagnose_readme_relative_links passes when there is no README", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(diagnose_readme_relative_links(pkg, verbose = FALSE)$passed)
})

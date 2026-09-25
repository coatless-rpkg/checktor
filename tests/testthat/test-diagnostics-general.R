# A test that names a CRAN package reproduces a false positive or a missed
# finding from that package's real sources, so a regression fails here first.

# Test lab_package_size() ----

test_that("lab_package_size(): excludes .Rbuildignore'd directories", {
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

# Test lab_readme_links() ----

test_that("lab_readme_links(): flags a link to a missing file", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    "See [the guide](docs/guide.md) for details.",
    file.path(pkg, "README.md")
  )
  res <- lab_readme_links(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("lab_readme_links(): flags links to .Rbuildignore'd files", {
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

test_that("lab_readme_links(): accepts absolute URLs and shipped files", {
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

test_that("lab_readme_links(): passes when there is no README", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_readme_links(pkg, verbose = FALSE)$passed)
})

test_that("lab_readme_links(): does not read R code in a chunk as a link", {
  # `knitr::opts_chunk[["set"]](...)` contains `](` and a closing paren, so a
  # regex over the raw file reported the chunk's arguments as a missing file.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "---",
      "output: github_document",
      "---",
      "",
      "```{r parameters, include = FALSE}",
      'knitr::opts_chunk[["set"]](',
      "    collapse = TRUE,",
      '    comment = "#>"',
      ")",
      "```",
      "",
      "# my_pkg"
    ),
    file.path(pkg, "README.Rmd")
  )
  expect_true(lab_readme_links(pkg, verbose = FALSE)$passed)
})

test_that("lab_readme_links(): reads code fences the way a renderer does", {
  # A ````-fence quoting a ```-fence is how a README shows markdown, and the
  # inner fence must not be read as closing the outer one.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "````md",
      "```r",
      'x[["a"]](1)',
      "```",
      "[quoted](never/written.md)",
      "````",
      "",
      "~~~",
      'y[["b"]](2)',
      "~~~",
      "",
      "Also `[inline](nope.md)` and <!-- [commented](gone.md) --> prose."
    ),
    file.path(pkg, "README.md")
  )
  expect_true(lab_readme_links(pkg, verbose = FALSE)$passed)
})

test_that("lab_readme_links(): still sees the links around the code", {
  # The guard against blanking too much: a badge block sits between two
  # comments rather than inside one, and the real link must survive.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "<!-- badges: start -->",
      "[![cov](man/figures/cov.svg)](missing/target.md)",
      "<!-- badges: end -->",
      "",
      "```r",
      'opts[["set"]](a = 1)',
      "```",
      "",
      "See [the guide](docs/guide.md)."
    ),
    file.path(pkg, "README.md")
  )
  res <- lab_readme_links(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_setequal(
    res$issues,
    paste0(
      "README.md: relative link to missing file '",
      c("man/figures/cov.svg", "missing/target.md", "docs/guide.md"),
      "'"
    )
  )
})

test_that("lab_readme_links(): accepts a destination in pointy brackets", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("x", file.path(pkg, "a file.md"))
  writeLines("See [it](<a file.md>).", file.path(pkg, "README.md"))
  expect_true(lab_readme_links(pkg, verbose = FALSE)$passed)
})

test_that("lab_readme_links(): knows a knitr chunk header from a code span", {
  # A chunk may set an option from inline R, so its header carries backticks of
  # its own. CommonMark would call that a code span rather than a fence; knitr
  # calls it a chunk, and the body must not be read as prose either way.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "```{r, eval = `r ok`}",
      'opts[["set"]](a = 1)',
      "```",
      "",
      "Use `` `x` `` for code, then see [the guide](docs/guide.md)."
    ),
    file.path(pkg, "README.Rmd")
  )
  res <- lab_readme_links(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(
    res$issues,
    "README.Rmd: relative link to missing file 'docs/guide.md'"
  )
})

test_that("lab_readme_links(): does not let one stray backtick hide a link", {
  # Pairing code spans across the whole file would match the quote character in
  # the first line to the one in the last and blank the broken link between them.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "Use ` as a quote character.",
      "",
      "See [the guide](docs/guide.md).",
      "",
      "And a closing ` here."
    ),
    file.path(pkg, "README.md")
  )
  expect_false(lab_readme_links(pkg, verbose = FALSE)$passed)
})

test_that("lab_readme_links(): skips a comment that runs over several lines", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c("<!--", "[the old guide](docs/gone.md)", "-->", "", "# pkg"),
    file.path(pkg, "README.md")
  )
  expect_true(lab_readme_links(pkg, verbose = FALSE)$passed)
})

# Test lab_urls() ----

test_that("lab_urls(): flags an insecure http:// and names the URL", {
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

test_that("lab_urls(): ignores an http:// inside a fenced code block", {
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

test_that("lab_urls(): ignores an http:// inside an Rd \\verb or \\code span", {
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

test_that("lab_urls(): still flags a real Rd link outside a literal span", {
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

test_that("lab_urls(): skips tilde-fenced and nested code blocks too", {
  # The URL check counted ``` fences off in pairs, which a README quoting
  # markdown inside a ````-fence puts out of step, and it never knew ~~~ at all.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "~~~",
      "http://tilde.example/",
      "~~~",
      "",
      "````md",
      "```r",
      'download.file("http://nested.example/")',
      "```",
      "````",
      "",
      "# pkg"
    ),
    file.path(pkg, "README.md")
  )
  expect_true(lab_urls(pkg, verbose = FALSE)$passed)
})

test_that("lab_urls(): names the URL without the backtick that quoted it", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("Use `http://example.com/docs` here.", file.path(pkg, "README.md"))
  res <- lab_urls(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(
    res$issues,
    "README.md: http://example.com/docs (use https://)"
  )
})

# Test lab_url_liveness() ----

test_that("lab_url_liveness(): never reaches the network outside the console", {
  # The default is interactive(), so a script, a CI run and R CMD check all leave
  # it off. That is what keeps examples and tests from needing a network.
  skip_if(interactive(), "tests the non-interactive default")
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "URL: https://nonexistent-host.checktor.invalid/")

  fetched <- FALSE
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) {
      fetched <<- TRUE
      data.frame()
    }
  )
  withr::local_options(checktor.url_check = NULL) # unset: fall back to the default

  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_false(fetched)
  expect_true(res$passed)
  expect_length(res$issues, 0L)
})

test_that("lab_url_liveness(): reaches the network when asked to", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  fetched <- FALSE
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) {
      fetched <<- TRUE
      data.frame()
    }
  )
  withr::local_options(checktor.url_check = TRUE)

  expect_true(lab_url_liveness(pkg, verbose = FALSE)$passed)
  expect_true(fetched)
})

test_that("lab_url_liveness(): surfaces the broken URLs the fetch reports", {
  # Stub the network fetch so the test is deterministic and never leaves the
  # machine. The real fetch is base R's tools::check_package_urls(), whose
  # behaviour is environment-dependent (and absent without a network).
  pkg <- make_temp_dir()
  write_pkg(pkg)
  withr::local_options(checktor.url_check = TRUE)

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

test_that("lab_url_liveness(): passes when the fetch reports nothing", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  withr::local_options(checktor.url_check = TRUE)
  testthat::local_mocked_bindings(fetch_url_db = function(path) data.frame())
  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_length(res$issues, 0L)
  # Nothing to check is a genuine pass, not a skip: there is nothing to be wrong.
  expect_false(isTRUE(res$skipped))
})

test_that("lab_url_liveness(): a failed fetch is not checked, not a pass", {
  # Being offline -- or a change under the fetch -- used to read exactly like a
  # package whose every URL resolved, which is the one thing a skip exists to
  # prevent.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  withr::local_options(checktor.url_check = TRUE)
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) stop("fetch did not complete")
  )
  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_true(res$skipped)
})

test_that("lab_url_liveness(): passes a reachable URL end to end", {
  skip_on_cran() # CRAN policy: tests must not require network access
  # A real run against tools::check_package_urls(), no mock. A reachable URL must
  # not be flagged. This direction is robust to a network-less runner: with no
  # network the fetch reports nothing and the check still passes, so the only way
  # it fails is if the URL genuinely breaks. CRAN's own site is the most stable
  # choice and never rate-limits R's URL checker.
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "URL: https://cran.r-project.org/")
  withr::local_options(checktor.url_check = TRUE)
  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_length(res$issues, 0L)
})

test_that("lab_url_liveness(): stays quiet when no host could be reached", {
  # Every row failing to resolve says the machine has no connection, not that the
  # package's links are broken, so the check reports that it did not run.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  withr::local_options(checktor.url_check = TRUE)
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) {
      data.frame(
        URL = c("https://a.example", "https://b.example"),
        From = "DESCRIPTION",
        Status = c("Error", "Error"),
        Message = "Could not resolve host",
        New = "",
        stringsAsFactors = FALSE
      )
    }
  )
  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_length(res$issues, 0L)
  expect_true(isTRUE(res$skipped))
})

test_that("lab_url_liveness(): reports one dead host among reachable ones", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  withr::local_options(checktor.url_check = TRUE)
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) {
      data.frame(
        URL = c("https://a.example", "https://b.example"),
        From = "DESCRIPTION",
        Status = c("404", "Error"),
        Message = c("Not Found", "Could not resolve host"),
        New = "",
        stringsAsFactors = FALSE
      )
    }
  )
  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_length(res$issues, 2L)
})

# Test fetch_url_db() ----

test_that("fetch_url_db(): really calls base R and returns the columns read", {
  # Every other liveness test mocks fetch_url_db, so a broken tools:: call would
  # leave every URL unchecked with the suite still green. This pins the seam.
  #
  # check_package_urls() always calls check_url_db(parallel = TRUE), and that
  # branch opens a curl::new_pool() before it looks at whether there is anything
  # to fetch. So it needs curl even for a package with no URLs at all.
  skip_if_not_installed("curl")
  pkg <- make_temp_dir()
  write_pkg(pkg) # no URL: field, so there is nothing to fetch

  db <- suppressWarnings(suppressMessages(fetch_url_db(pkg)))
  expect_s3_class(db, "data.frame")
  expect_equal(nrow(db), 0L)
  # lab_url_liveness reads these five columns by name when building issues.
  expect_true(all(c("URL", "From", "Status", "Message", "New") %in% names(db)))
})

# Test extract_link_targets() ----

test_that("extract_link_targets(): finds markdown and HTML targets", {
  expect_setequal(
    extract_link_targets('[a](docs/a.md) <img src="man/figures/l.png">'),
    c("docs/a.md", "man/figures/l.png")
  )
})

test_that("extract_link_targets(): strips an optional link title", {
  expect_identical(
    extract_link_targets('[a](docs/a.md "The Guide")'),
    "docs/a.md"
  )
})

test_that("extract_link_targets(): unwraps a pointy-bracketed destination", {
  expect_identical(extract_link_targets("[a](<a file.md>)"), "a file.md")
})

test_that("extract_link_targets(): rejects a bare target containing a space", {
  # `knitr::opts_chunk[["set"]](` ends in `](`, so its arguments read as a
  # destination unless one that could not be a destination is thrown out.
  expect_identical(
    extract_link_targets('x[["set"]](\n  collapse = TRUE\n)'),
    character(0)
  )
})

test_that("extract_link_targets(): finds nothing in text with no links", {
  expect_identical(extract_link_targets("plain prose"), character(0))
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

# Test lab_citation_file() ----

test_that("lab_citation_file(): flags the old-style citEntry() and personList()", {
  pkg <- citation_pkg(c(
    "bibentry(",
    "  'Manual',",
    "  title = 'Test',",
    "  author = personList(person('A', 'B'), as.personList('C D')),",
    "  year = '2026'",
    ")",
    "citEntry(entry = 'Manual', title = 'Test', year = '2026')"
  ))
  res <- lab_citation_file(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_length(res$issues, 3L)
  expect_match(res$issues[[1]], "^inst/CITATION:4 .*personList\\(\\).*c\\(\\)")
  expect_match(res$issues[[2]], "^inst/CITATION:4 .*as\\.personList\\(\\)")
  expect_match(
    res$issues[[3]],
    "^inst/CITATION:7 .*citEntry\\(\\).*bibentry\\(\\)"
  )
  # Each finding carries a location issues() can point at.
  expect_identical(.split_issue(res$issues)$line, c(4L, 4L, 7L))
})

test_that("lab_citation_file(): flags calls that assume the package is installed", {
  pkg <- citation_pkg(c(
    "library(utils)",
    "desc <- packageDescription('testpkg')",
    "if (!require(stats)) stop()",
    "bibentry('Manual', title = 'Test', year = desc$Date)"
  ))
  res <- lab_citation_file(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "^inst/CITATION:[123] ")
  expect_match(res$issues[[1]], "library()", fixed = TRUE)
  expect_match(res$issues[[2]], "packageDescription().*meta")
  expect_match(res$issues[[3]], "require()", fixed = TRUE)
})

test_that("lab_citation_file(): exempts R's own `meta` fallback idiom", {
  # digest, mlbench and cluster all do this. R drops a top-level `if` with exactly
  # this condition and no else before looking, so it is not a finding.
  pkg <- citation_pkg(c(
    "if (!exists('meta') || is.null(meta)) meta <- packageDescription('testpkg')",
    "if(!exists(\"meta\")||is.null(meta)) {",
    "  meta <- packageDescription(\"testpkg\")",
    "}",
    "bibentry('Manual', title = 'Test', year = meta$Date)"
  ))
  expect_true(lab_citation_file(pkg, verbose = FALSE)$passed)

  # Only that exact form: another condition, or an else branch, is not exempt.
  other <- citation_pkg(c(
    "if (is.null(meta)) meta <- packageDescription('testpkg')",
    "if (!exists('meta') || is.null(meta)) 1 else library(utils)",
    "if (!exists(meta) || is.null(meta)) require(utils)"
  ))
  res <- lab_citation_file(other, verbose = FALSE)
  expect_match(res$issues, "^inst/CITATION:[123] ")
  expect_length(res$issues, 3L)
})

test_that("lab_citation_file(): reads the parse tree, not the text", {
  pkg <- citation_pkg(c(
    "# citEntry() and personList() are the old style",
    "bibentry('Manual', title = 'Why not citEntry(x) or library(y)', year = '2026',",
    "  textVersion = paste('packageDescription(', 'x)'))"
  ))
  expect_true(lab_citation_file(pkg, verbose = FALSE)$passed)

  # A namespaced call is still the call.
  ns <- citation_pkg(
    "utils::citEntry(entry = 'Manual', title = 'T', year = '2026')"
  )
  expect_match(
    lab_citation_file(ns, verbose = FALSE)$issues,
    "citEntry()",
    fixed = TRUE
  )
})

test_that("lab_citation_file(): reports a CITATION that does not parse", {
  pkg <- citation_pkg(c("bibentry('Manual',", "  title = 'T' year = '2026')"))
  res <- lab_citation_file(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_length(res$issues, 1L)
  expect_match(
    res$issues,
    "^inst/CITATION:2 \\(does not parse: unexpected symbol at column 15\\)$"
  )
})

test_that("lab_citation_file(): passes without a CITATION the tarball ships", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_citation_file(pkg, verbose = FALSE)$passed)

  ignored <- citation_pkg(
    "citEntry(entry = 'Manual', title = 'T', year = '2026')"
  )
  writeLines("^inst/CITATION$", file.path(ignored, ".Rbuildignore"))
  expect_true(lab_citation_file(ignored, verbose = FALSE)$passed)
})

test_that("lab_citation_file(): reads a CITATION in the package's declared encoding", {
  # "Mueller" with a u-umlaut, in latin1: the byte 0xFC is not valid UTF-8.
  name <- rawToChar(as.raw(c(0x4d, 0xfc, 0x6c, 0x6c, 0x65, 0x72)))
  pkg <- citation_pkg(
    paste0(
      "bibentry('Manual', title = 'T', author = person('A', '",
      name,
      "'), year = '2026')"
    )
  )
  desc <- file.path(pkg, "DESCRIPTION")
  writeLines(sub("^Encoding: .*", "Encoding: latin1", readLines(desc)), desc)
  expect_true(lab_citation_file(pkg, verbose = FALSE)$passed)
})

# Test lab_readme_links() ----

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

test_that("lab_readme_links(): accepts absolute URLs, anchors, shipped files and pointy-bracketed destinations", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "man", "figures"), recursive = TRUE)
  writeLines("x", file.path(pkg, "man", "figures", "logo.png"))
  writeLines("x", file.path(pkg, "a file.md"))
  writeLines(
    c(
      "Full link: [site](https://example.com).",
      "Anchor: [top](#intro).",
      "Shipped image: ![logo](man/figures/logo.png).",
      "Pointy: [it](<a file.md>)."
    ),
    file.path(pkg, "README.md")
  )
  res <- lab_readme_links(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_identical(res$issues, character(0))
})

test_that("lab_readme_links(): passes when there is no README", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_readme_links(pkg, verbose = FALSE)$passed)
})

test_that("lab_readme_links(): reads a knitr chunk as code, not as links", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "---",
      "output: github_document",
      "---",
      "",
      # `knitr::opts_chunk[["set"]](...)` contains `](` and a closing paren, so a
      # regex over the raw file reported the chunk's arguments as a missing file.
      "```{r parameters, include = FALSE}",
      'knitr::opts_chunk[["set"]](',
      "    collapse = TRUE,",
      '    comment = "#>"',
      ")",
      "```",
      "",
      # A chunk may set an option from inline R, so its header carries backticks
      # of its own. CommonMark would call that a code span rather than a fence;
      # knitr calls it a chunk, and the body must not be read as prose either
      # way. This chunk must be the last fence before the guide link: if its
      # closing ``` were misread as opening a fence, that fence would run to the
      # end of the file and swallow the link below.
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
  # Exactly the guide link: the opts_chunk arguments add no issue of their own.
  expect_identical(
    res$issues,
    "README.Rmd: relative link to missing file 'docs/guide.md'"
  )
})

test_that("lab_readme_links(): reads code fences and comments the way a renderer does", {
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
      "Also `[inline](nope.md)` and <!-- [commented](gone.md) --> prose.",
      "",
      # A comment that runs over several lines.
      "<!--",
      "[the old guide](docs/gone.md)",
      "-->",
      "",
      "# pkg"
    ),
    file.path(pkg, "README.md")
  )
  res <- lab_readme_links(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_identical(res$issues, character(0))
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
      # Pairing code spans across the whole file would match the quote character
      # on this line to the one after the link and blank the broken link between.
      "Use ` as a quote character.",
      "",
      "See [the guide](docs/guide.md).",
      "",
      "And a closing ` here."
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

# Test lab_urls() ----

test_that("lab_urls(): flags an insecure http:// and names the bare URL", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "# Pkg",
      "See <http://example.com/docs> for details.",
      "Use `http://example.com/code` here."
    ),
    file.path(pkg, "README.md")
  )

  res <- lab_urls(pkg, verbose = FALSE)
  expect_false(res$passed)
  # The finding must name the URL, not just the file, or it is not actionable.
  # It names it without the > or backtick that quoted it.
  expect_identical(
    res$issues,
    c(
      "README.md: http://example.com/docs (use https://)",
      "README.md: http://example.com/code (use https://)"
    )
  )
})

test_that("lab_urls(): reads a Sweave vignette and stops a URL at its brace", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "vignettes"), showWarnings = FALSE)
  writeLines(
    c(
      "\\documentclass{article}",
      "\\begin{document}",
      "See \\url{http://example.org/~me/}.",
      "\\end{document}"
    ),
    file.path(pkg, "vignettes", "intro.Rnw")
  )
  expect_equal(
    lab_urls(pkg, verbose = FALSE)$issues,
    "intro.Rnw: http://example.org/~me/ (use https://)"
  )
})

test_that("lab_urls(): ignores an http:// inside any fenced code block", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "# Pkg",
      "```r",
      "# a literal string, not a link",
      "download.file(\"http://example.com/data.csv\", tmp)",
      "```",
      "",
      # The URL check counted ``` fences off in pairs, which a README quoting
      # markdown inside a ````-fence puts out of step, and it never knew ~~~ at
      # all.
      "~~~",
      "http://tilde.example/",
      "~~~",
      "",
      "````md",
      "```r",
      'download.file("http://nested.example/")',
      "```",
      "````"
    ),
    file.path(pkg, "README.md")
  )

  res <- lab_urls(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_identical(res$issues, character(0))
})

test_that("lab_urls(): skips an http:// in an Rd \\verb span but flags a real \\url", {
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
    file.path(pkg, "man", "literal.Rd")
  )
  writeLines(
    c(
      "\\name{f}",
      "\\alias{f}",
      "\\title{F}",
      "\\description{See \\url{http://example.org} for more.}",
      "\\value{NULL}"
    ),
    file.path(pkg, "man", "link.Rd")
  )

  res <- lab_urls(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(res$issues, "link.Rd: http://example.org (use https://)")
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

test_that("lab_url_liveness(): fetches when asked to, and nothing reported is a pass", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  withr::local_options(checktor.url_check = TRUE)
  fetched <- FALSE
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) {
      fetched <<- TRUE
      data.frame()
    }
  )

  res <- lab_url_liveness(pkg, verbose = FALSE)
  expect_true(fetched)
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

test_that("lab_url_liveness(): reports each broken URL, a dead host among reachable ones included", {
  # Stub the network fetch so the test is deterministic and never leaves the
  # machine. The real fetch is base R's tools::check_package_urls(), whose
  # behaviour is environment-dependent (and absent without a network).
  # The 404 row shows a host answered, so the unresolved host is a real finding,
  # not an offline machine (contrast "stays quiet when no host could be reached").
  pkg <- make_temp_dir()
  write_pkg(pkg)
  withr::local_options(checktor.url_check = TRUE)
  testthat::local_mocked_bindings(
    fetch_url_db = function(path) {
      data.frame(
        URL = c("https://example.com/missing", "https://b.example"),
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
  expect_match(res$issues, "example.com/missing", all = FALSE)
  expect_match(res$issues, "404", all = FALSE)
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

test_that("extract_link_targets(): pulls each link destination out as a renderer would", {
  cases <- list(
    "markdown and HTML" = list(
      input = '[a](docs/a.md) <img src="man/figures/l.png">',
      expected = c("docs/a.md", "man/figures/l.png")
    ),
    "link title" = list(
      input = '[a](docs/a.md "The Guide")',
      expected = "docs/a.md"
    ),
    "pointy brackets" = list(
      input = "[a](<a file.md>)",
      expected = "a file.md"
    ),
    # `knitr::opts_chunk[["set"]](` ends in `](`, so its arguments read as a
    # destination unless one that could not be a destination is thrown out.
    "bare target with a space" = list(
      input = 'x[["set"]](\n  collapse = TRUE\n)',
      expected = character(0)
    ),
    "no links" = list(input = "plain prose", expected = character(0))
  )
  for (case in names(cases)) {
    expect_identical(
      extract_link_targets(cases[[case]]$input),
      cases[[case]]$expected,
      info = case
    )
  }
})

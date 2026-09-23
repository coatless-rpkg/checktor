# prescribe() turns the checks that failed into treatments.

# Test prescribe() ----

test_that("prescribe(): surfaces failed checks with no curated treatment", {
  # A package whose only defect is a missing NEWS file. The news_file check has
  # no entry in the curated `treatments` list, so before the fix prescribe()
  # printed only its header and stayed silent about the actual problem (#4).
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)

  res <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false(res$general_issues$passed[["news_file"]]) # sanity

  out <- cli::cli_fmt(prescribe(res))
  txt <- paste(out, collapse = "\n")
  # Match the ISSUE, not the heading: "NEWS" alone is satisfied by the
  # "NEWS file check" header that #4 was filed about.
  expect_match(txt, "No NEWS file found", fixed = TRUE)
})

test_that("prescribe(): prints uncurated issue text literally", {
  # The fallback lists the check's own issues, which quote the package. news_file
  # has no curated treatment, so its failure takes that path.
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  res <- checktor(pkg, verbose = FALSE, progress = FALSE)
  res$general_issues$news_file$issues <- "NEWS.md mentions {stop('evaluated')}"

  out <- NULL
  expect_no_error(out <- cli::cli_fmt(prescribe(res)))
  expect_match(
    paste(out, collapse = "\n"),
    "NEWS.md mentions {stop('evaluated')}",
    fixed = TRUE
  )
})

test_that("prescribe(): prints an uncurated check's heading literally", {
  # The heading is the check's message. A check added with register_check() may
  # build it from the package, e.g. naming the Title a house rule rejected.
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE)
  res <- checktor(pkg, verbose = FALSE, progress = FALSE)
  res$general_issues$news_file$message <- "House rule for {stop('evaluated')}"

  out <- NULL
  expect_no_error(out <- cli::cli_fmt(prescribe(res)))
  expect_match(
    paste(out, collapse = "\n"),
    "House rule for {stop('evaluated')}",
    fixed = TRUE
  )
})

test_that("prescribe(): still emits curated treatments for known checks", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "bad <- function() T")

  res <- checktor(pkg, verbose = FALSE, progress = FALSE)
  out <- cli::cli_fmt(prescribe(res))
  txt <- paste(out, collapse = "\n")
  expect_match(txt, "T/F Usage Issues")
})

test_that("prescribe(): still offers remedies for advisory-only findings", {
  # The verdict can be clean while advisory findings remain. Prescribing for the
  # verdict alone would withhold the remedy for every one of them.
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE) # clean except: no NEWS file, which is `opinion`
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  expect_true(is_healthy(r)) # nothing CRAN will reject
  expect_gt(r$metadata$advisory_issues, 0L) # but there IS something to say
  txt <- paste(cli::cli_fmt(prescribe(r)), collapse = "\n")
  # The finding itself, not the "NEWS file check" heading: a header-only
  # prescription is exactly the silence this test is here to rule out.
  expect_match(txt, "No NEWS file found", fixed = TRUE)
})

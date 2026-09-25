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

test_that("prescribe(): gives a DESCRIPTION R cannot read its own treatment", {
  r <- checktor(unparseable_pkg(), verbose = FALSE, progress = FALSE)
  txt <- paste(cli::cli_fmt(prescribe(r)), collapse = "\n")
  expect_match(txt, "DESCRIPTION R Cannot Read", fixed = TRUE)
  expect_match(txt, "indented by a space or tab", fixed = TRUE)
  # The finding itself, which quotes the line R stopped at.
  expect_match(txt, "this line is not a f", fixed = TRUE)
  expect_no_match(txt, "Review the detailed diagnosis above", fixed = TRUE)

  # That line is the package's text, so it prints as written.
  r$description_issues$description_file$issues <-
    "DESCRIPTION does not parse: Line starting '{stop('evaluated')} ...' is malformed!"
  out <- NULL
  expect_no_error(out <- cli::cli_fmt(prescribe(r)))
  expect_match(paste(out, collapse = "\n"), "{stop('evaluated')}", fixed = TRUE)
})

test_that("prescribe(): fits the DESCRIPTION example to why R cannot read it", {
  # The reflowed Description line is the fix for a malformed line only. A file
  # that is missing or cannot be opened needs a fix of its own.
  r <- checktor(unopenable_pkg("directory"), verbose = FALSE, progress = FALSE)
  shown <- function(issue) {
    r$description_issues$description_file$issues <- issue
    paste(cli::cli_fmt(prescribe(r)), collapse = "\n")
  }

  txt <- shown(r$description_issues$description_file$issues)
  expect_match(txt, "# DESCRIPTION is a directory, not a file", fixed = TRUE)
  expect_match(txt, "has to be a file", fixed = TRUE)
  expect_no_match(txt, "reflowed", fixed = TRUE)

  txt <- shown("DESCRIPTION file not found")
  expect_match(txt, "usethis::use_description()", fixed = TRUE)
  expect_no_match(txt, "reflowed", fixed = TRUE)

  txt <- shown("DESCRIPTION cannot be read (permission denied)")
  expect_match(txt, "Sys.chmod(\"DESCRIPTION\", \"644\")", fixed = TRUE)
  expect_no_match(txt, "reflowed", fixed = TRUE)

  # Every one of them ends by reading the file the way R CMD build does.
  expect_match(txt, "read.dcf(\"DESCRIPTION\")", fixed = TRUE)
  txt <- shown(paste(
    "DESCRIPTION contains a blank line, which splits it into more than one",
    "record"
  ))
  expect_match(txt, "reflowed", fixed = TRUE)
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

test_that("prescribe(): every curated treatment names a built-in check", {
  # Treatments are looked up by check name alone, so a misspelt one would never
  # be shown.
  checks <- vapply(treatments, function(rx) rx$check, character(1))
  expect_true(all(checks %in% BUILTIN_CHECKS$name), info = paste(checks, collapse = ", "))
  expect_identical(anyDuplicated(checks), 0L)
})

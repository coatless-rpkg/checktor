# Test lab_references() ----

test_that("lab_references(): passes the forms CRAN asks for", {
  d <- list(Description = paste(
    "Implements the method of Smith (2020) <doi:10.1000/xyz123>, described at",
    "<https://example.org/method>, and the preprint",
    "<doi:10.48550/arXiv.1509.03700>."
  ))
  res <- lab_references(make_temp_dir(), verbose = FALSE, desc = d)
  expect_true(res$passed)
  expect_identical(res$issues, character(0))
  expect_true(
    lab_references(make_temp_dir(), verbose = FALSE, desc = list(Package = "x"))$passed
  )
})

test_that("lab_references(): flags a URL outside angle brackets, once for all of them", {
  d <- list(Description = paste(
    "See https://example.org/a for the method and (https://example.org/b)",
    "for the data."
  ))
  res <- lab_references(make_temp_dir(), verbose = FALSE, desc = d)
  expect_false(res$passed)
  expect_identical(
    res$issues,
    paste0(
      "URL not enclosed in angle brackets (<...>): ",
      "https://example.org/a, (https://example.org/b)"
    )
  )
})

test_that("lab_references(): flags each DOI form CRAN rejects", {
  bad <- c(
    "a doi.org link <https://doi.org/10.1000/xyz123>." = "<https://doi.org/10.1000/xyz123>",
    "a bare doi:10.1000/xyz123 here." = "doi:10.1000/xyz123",
    "a colonless <doi10.1000/xyz123>." = "<doi10.1000/xyz123>",
    "a bare prefix <10.1000/xyz123>." = "<10.1000/xyz123>"
  )
  for (text in names(bad)) {
    d <- list(Description = paste("The method follows", text))
    res <- lab_references(make_temp_dir(), verbose = FALSE, desc = d)
    expect_identical(
      res$issues,
      paste0("DOI not written as <doi:prefix/suffix>: ", bad[[text]]),
      info = text
    )
  }
})

test_that("lab_references(): asks for DOI markup in place of a publisher link", {
  d <- list(Description = paste(
    "The method follows <https://onlinelibrary.wiley.com/doi/10.1002/sim.1234>."
  ))
  res <- lab_references(make_temp_dir(), verbose = FALSE, desc = d)
  expect_identical(
    res$issues,
    paste0(
      "Publisher link to a DOI, which CRAN asks to see as <doi:prefix/suffix>: ",
      "<https://onlinelibrary.wiley.com/doi/10.1002/sim.1234>"
    )
  )
  # R reports the publisher link only when no DOI is already malformed, since
  # the fix for the malformed one comes first.
  d$Description <- paste(d$Description, "See also doi:10.1000/xyz.")
  res <- lab_references(make_temp_dir(), verbose = FALSE, desc = d)
  expect_length(res$issues, 1L)
  expect_match(res$issues, "^DOI not written as")
})

test_that("lab_references(): asks for an arXiv DOI in place of an arXiv id or link", {
  d <- list(Description = paste(
    "Colour maps from Kovesi (2015) <arXiv:1509.03700> and",
    "<https://arxiv.org/abs/2101.00001v2>."
  ))
  res <- lab_references(make_temp_dir(), verbose = FALSE, desc = d)
  expect_identical(
    res$issues,
    paste0(
      "arXiv reference, which CRAN asks to see as its arXiv DOI: ",
      "<arXiv:1509.03700> (write <doi:10.48550/arXiv.1509.03700>), ",
      "<https://arxiv.org/abs/2101.00001v2> ",
      "(write <doi:10.48550/arXiv.2101.00001>)"
    )
  )
})

test_that("lab_references(): flags an unclosed reference, not a space after the colon", {
  # R does not NOTE the space, and CRAN's page links <doi: 10.1000/xyz> anyway.
  d <- list(Description = "The method <doi: 10.1000/xyz123> is fast.")
  expect_true(lab_references(make_temp_dir(), verbose = FALSE, desc = d)$passed)

  d <- list(Description = "The method <doi:10.1000/xyz123 is fast.")
  res <- lab_references(make_temp_dir(), verbose = FALSE, desc = d)
  expect_identical(res$issues, "Reference with no closing '>': <doi:10.1000/xyz123")
  # A SICI DOI carries angle brackets of its own, and is closed all the same.
  d <- list(Description = paste(
    "Following <doi:10.1002/(SICI)1097-0258(19980430)17:8<857::AID-SIM777>3.0.CO;2-E>."
  ))
  expect_true(lab_references(make_temp_dir(), verbose = FALSE, desc = d)$passed)
})

test_that("lab_references(): reads a reference wrapped across lines", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = paste(
    "Implements the estimator of Smith and Jones, see",
    "    https://example.org/estimator for the details of the method.",
    sep = "\n"
  ))
  res <- lab_references(pkg, verbose = FALSE)
  expect_match(res$issues, "https://example.org/estimator", fixed = TRUE)
})

test_that("lab_references(): prints each finding with the fix", {
  d <- list(Description = "See https://example.org/a for the method.")
  out <- paste(
    cli::cli_fmt(lab_references(make_temp_dir(), desc = d)),
    collapse = " "
  )
  expect_match(out, "https://example.org/a", fixed = TRUE)
  expect_match(out, "Treatment", fixed = TRUE)
})

test_that("lab_references(): uses the patterns R's incoming check uses", {
  # The rules are copied from tools:::.check_package_CRAN_incoming rather than
  # called through `:::`, so this holds the copy to R's source. A change in R
  # fails here first.
  skip_if(getRversion() < "4.6.0", "the arXiv rule arrived in R 4.6.0")
  strings <- character(0)
  walk <- function(e) {
    if (is.character(e)) {
      strings <<- c(strings, e)
    } else if (is.call(e) || is.pairlist(e) || is.expression(e)) {
      for (x in as.list(e)) if (!missing(x)) walk(x)
    }
  }
  walk(body(tools:::.check_package_CRAN_incoming))
  for (rule in DESCRIPTION_REFERENCE_RULES) {
    expect_true(all(rule$r_patterns %in% strings), info = rule$label)
  }
})

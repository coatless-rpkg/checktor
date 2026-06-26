# Regression tests for the DESCRIPTION-file diagnostics, especially that
# multi-line fields (Description, Title) are read in full via read.dcf.

test_that("description_length reads continuation lines, not just the first line", {
  pkg <- make_temp_dir()
  long_desc <- paste(
    "First sentence with enough words to fool nobody.",
    "    Second continuation sentence with even more words.",
    "    Third line continuing to make sure word counting picks it up.",
    sep = "\n"
  )
  write_pkg(pkg, description = long_desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$description_length$passed)
  expect_gte(res$description_length$words, 20L)
  expect_gte(res$description_length$sentences, 2L)
})

test_that("description_length still flags genuinely short descriptions", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Short.")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$description_length$passed)
})

test_that("software_names_formatting inspects continuation lines of Description", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Provides utilities.",
    "    Builds on ggplot2 (without quotes) and dplyr too.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$software_names$passed)
  expect_true(any(grepl("ggplot2", res$software_names$issues)))
})

test_that("software_names_formatting accepts properly quoted names", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Wraps 'ggplot2' and 'dplyr' for convenience.")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$software_names$passed)
})

test_that("software_names_formatting does NOT flag the bare letter R", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "A package for R users that integrates with 'ggplot2'.")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$software_names$passed)
})

test_that("license_formatting requires + file LICENSE for MIT", {
  pkg_bad <- make_temp_dir()
  write_pkg(pkg_bad, license = "MIT")
  res_bad <- diagnose_description_issues(pkg_bad, verbose = FALSE)
  expect_false(res_bad$license$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, license = "MIT + file LICENSE")
  writeLines("YEAR: 2026\nCOPYRIGHT HOLDER: tests",
             file.path(pkg_ok, "LICENSE"))
  res_ok <- diagnose_description_issues(pkg_ok, verbose = FALSE)
  expect_true(res_ok$license$passed)
})

test_that("license_formatting accepts GPL-3 without LICENSE file", {
  pkg <- make_temp_dir()
  write_pkg(pkg, license = "GPL-3")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$license$passed)
})

test_that("license_formatting flags GPL-3 with a missing referenced LICENSE", {
  pkg <- make_temp_dir()
  write_pkg(pkg, license = "GPL-3 + file LICENSE")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$license$passed)
})

test_that("title_case allows lowercase small words mid-title", {
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "Tools for the Analysis of Data")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$title_case$passed)
})

test_that("title_case flags lowercase content words", {
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "tools for stuff")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$title_case$passed)
})

test_that("title_case flags over-capitalized small words", {
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "Tools For The Analysis Of Data")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$title_case$passed)

  # A capitalized small word right after a colon (subtitle start) is fine.
  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, title = "Analysis Toolkit: The Next Generation")
  expect_true(diagnose_description_issues(pkg_ok, verbose = FALSE)$title_case$passed)
})

# ---- title_length ------------------------------------------------------------

test_that("title_length flags titles of 65+ characters", {
  pkg <- make_temp_dir()
  write_pkg(pkg, title = paste(rep("Word", 20), collapse = " "))  # > 65 chars
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$title_length$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, title = "Concise Package Title")
  expect_true(diagnose_description_issues(pkg_ok, verbose = FALSE)$title_length$passed)
})

# ---- description_function_quotes ---------------------------------------------

test_that("description_function_quotes flags single-quoted function names", {
  pkg <- make_temp_dir()
  write_pkg(pkg,
            description = paste("Wraps the 'lm()' interface for users.",
                                "It does a number of helpful things here."))
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$description_function_quotes$passed)
})

test_that("description_function_quotes accepts quoted software names", {
  pkg <- make_temp_dir()
  write_pkg(pkg,
            description = paste("Provides an interface to 'ggplot2' graphics.",
                                "It does a number of helpful things here."))
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$description_function_quotes$passed)
})

test_that("authors_field is OK when Authors@R is present, fails otherwise", {
  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok)
  expect_true(diagnose_description_issues(pkg_ok, verbose = FALSE)$authors$passed)

  pkg_legacy <- make_temp_dir()
  write_pkg(pkg_legacy,
            authors_r = NULL,
            author    = "A. Tester",
            maintainer = "A. Tester <a@example.com>")
  expect_false(diagnose_description_issues(pkg_legacy, verbose = FALSE)$authors$passed)
})

test_that("acronym detection knows common abbreviations and reads continuations", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Provides bindings to the OS for HTTP work.",     # OS in unexplained set
    "    Includes XYZ helpers for fun.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  # XYZ should be flagged; OS is in the common-abbreviations list.
  expect_false(res$acronyms$passed)
  expect_true("XYZ" %in% res$acronyms$issues)
  expect_false("OS" %in% res$acronyms$issues)
  expect_false("HTTP" %in% res$acronyms$issues)
})

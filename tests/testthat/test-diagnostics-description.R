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

test_that("acronym check treats 'expansion (ACRONYM)' as explained (#5)", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Calculate and plot r2 coefficients between principal component",
    "    analysis (PCA) components and covariates. The idea is to search",
    "    for components which are explained by the covariates.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$acronyms$passed)
  expect_false("PCA" %in% res$acronyms$issues)
})

test_that("acronym check treats 'ACRONYM (expansion)' as explained", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Runs PCA (principal component analysis) over supplied matrices and",
    "    returns the resulting components for downstream modelling work.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$acronyms$passed)
  expect_false("PCA" %in% res$acronyms$issues)
})

test_that("acronym check still flags genuinely unexplained acronyms", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Provides FOOBAR utilities for the analysis of tabular data and the",
    "    production of summaries across many datasets and output formats.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$acronyms$passed)
  expect_true("FOOBAR" %in% res$acronyms$issues)
})

# ---- authors: template placeholders (the pcaR2 false negative) ----------------

test_that("authors_field flags an unfilled usethis template", {
  # pcaR2 shipped exactly this and checktor's presence-only check passed it, even
  # though it is a hard CRAN rejection. R CMD check says nothing: the field IS
  # present, so it has nothing to complain about.
  pkg <- make_temp_dir()
  write_pkg(pkg, authors_r = paste0(
    "person(\"First\", \"Last\", , \"january.weiner@gmail.com\", ",
    "role = c(\"aut\", \"cre\", \"cph\"))"
  ))
  res <- diagnose_description_issues(pkg, verbose = FALSE)$authors
  expect_false(res$passed)
  expect_true(any(grepl("placeholder", res$issues)))
})

test_that("authors_field flags a placeholder email and Your Name", {
  pkg <- make_temp_dir()
  write_pkg(pkg, authors_r = paste0(
    "person(\"Your Name\", , , \"you@example.com\", role = c(\"aut\", \"cre\"))"
  ))
  expect_false(diagnose_description_issues(pkg, verbose = FALSE)$authors$passed)
})

test_that("authors_field passes a real, filled-in Authors@R", {
  pkg <- make_temp_dir()
  write_pkg(pkg)   # helper default is a real name/email
  expect_true(diagnose_description_issues(pkg, verbose = FALSE)$authors$passed)
})

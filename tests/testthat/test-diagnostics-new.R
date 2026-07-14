# Detection tests for the checks added in the CRAN-readiness expansion.

# ---- description_starts_with -------------------------------------------------

# ---- description_bare_r ------------------------------------------------------

test_that("description_bare_r flags unquoted standalone R", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "A tool for R users to do things.")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$description_bare_r$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok,
            description = paste("A tool for 'R' users.",
                                "Wraps 'ggplot2' and 'dplyr' for plotting."))
  res2 <- diagnose_description_issues(pkg_ok, verbose = FALSE)
  expect_true(res2$description_bare_r$passed)
})

# ---- description_quoted_quotes -----------------------------------------------

test_that("description_quoted_quotes flags a double-quoted SOFTWARE name", {
  # Writing R Extensions: double quotes are for quotations, single quotes for
  # "names of other packages and external software".
  pkg <- make_temp_dir()
  write_pkg(pkg,
            description = paste('Builds dashboards with "shiny" and plots.',
                                "It does things and more things."))
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$description_quoted_quotes$passed)
  expect_true(any(grepl("shiny", res$description_quoted_quotes$issues)))
})

test_that("description_quoted_quotes does not flag scare-quoted jargon", {
  # cbcTools ships "labeled" and "no choice" on CRAN today. Those ARE the
  # quotations that double quotes are reserved for, not software names.
  pkg <- make_temp_dir()
  write_pkg(pkg,
            description = paste('Supports "labeled" designs and a "no choice"',
                                "alternative for conjoint experiments."))
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$description_quoted_quotes$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok,
            description = paste("A package that does helpful things.",
                                "No quoted phrases here at all."))
  res2 <- diagnose_description_issues(pkg_ok, verbose = FALSE)
  expect_true(res2$description_quoted_quotes$passed)
})

# ---- title_starts_with_article -----------------------------------------------

test_that("title_starts_with_article flags leading A/An/The", {
  for (bad in c("A Tool for Stats", "An Implementation of X", "The Thing")) {
    pkg <- make_temp_dir()
    write_pkg(pkg, title = bad)
    res <- diagnose_description_issues(pkg, verbose = FALSE)
    expect_false(res$title_starts_with_article$passed, info = bad)
  }

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, title = "Implements Things")
  expect_true(diagnose_description_issues(pkg_ok, verbose = FALSE)$
              title_starts_with_article$passed)
})

# ---- title_redundant_phrases -------------------------------------------------

test_that("title_redundant_phrases flags 'for R' and 'Tools for' patterns", {
  for (bad in c("Statistical Models for R",
                "A Toolkit for Imaging",
                "Tools for Reproducible Reporting")) {
    pkg <- make_temp_dir()
    write_pkg(pkg, title = bad)
    expect_false(diagnose_description_issues(pkg, verbose = FALSE)$
                 title_redundant_phrases$passed, info = bad)
  }

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, title = "Statistical Modeling")
  expect_true(diagnose_description_issues(pkg_ok, verbose = FALSE)$
              title_redundant_phrases$passed)
})

# ---- cph_role ----------------------------------------------------------------

test_that("cph_role check accepts cph-bearing Authors@R and flags otherwise", {
  pkg <- make_temp_dir()
  write_pkg(pkg,
            authors_r = "person('A','B', role = c('aut','cre'))")
  expect_false(diagnose_description_issues(pkg, verbose = FALSE)$cph_role$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok,
            authors_r = "person('A','B', role = c('aut','cre','cph'))")
  expect_true(diagnose_description_issues(pkg_ok, verbose = FALSE)$cph_role$passed)
})

# ---- license_year ------------------------------------------------------------

# ---- library_in_pkg_code -----------------------------------------------------

test_that("library_in_pkg_code flags library()/require() but not pkg::fn", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "f <- function() {",
    "  library(stats)",
    "  require(stats)",
    "  utils::head(1:5)",
    "}"
  ))
  res <- diagnose_library_in_pkg_code(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)
})

# ---- sys_setenv_no_reset -----------------------------------------------------

test_that("sys_setenv_no_reset flags naked Sys.setenv and accepts cleanup", {
  pkg_bad <- make_temp_dir()
  write_pkg(pkg_bad, r_code = "f <- function() Sys.setenv(FOO = 1)")
  expect_false(diagnose_sys_setenv_no_reset(pkg_bad, verbose = FALSE)$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, r_code = c(
    "f <- function() {",
    "  Sys.setenv(FOO = 1)",
    "  on.exit(Sys.unsetenv('FOO'))",
    "}",
    "g <- function() withr::local_envvar(c(BAR = 1))"
  ))
  expect_true(diagnose_sys_setenv_no_reset(pkg_ok, verbose = FALSE)$passed)
})

# ---- commented_examples ------------------------------------------------------

test_that("commented_examples flags commented-out calls in \\examples", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}",
    "\\title{fn}",
    "\\value{1}",
    "\\examples{",
    "# my_function(x)   # commented-out call",
    "actual_call()",
    "}"
  )))
  res <- diagnose_commented_examples(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("commented_examples accepts explanatory comments", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}",
    "\\title{fn}",
    "\\value{1}",
    "\\examples{",
    "# Prepare data",
    "x <- 1",
    "}"
  )))
  res <- diagnose_commented_examples(pkg, verbose = FALSE)
  expect_true(res$passed)
})

# ---- unexported_example_namespace --------------------------------------------

# ---- donttest_vs_dontrun -----------------------------------------------------

test_that("donttest_vs_dontrun suggests \\donttest{} for slow-only code", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("slow.Rd" = c(
    "\\name{slow}",
    "\\title{slow}",
    "\\value{1}",
    "\\examples{",
    "\\dontrun{",
    "Sys.sleep(60)",
    "}",
    "}"
  )))
  res <- diagnose_donttest_vs_dontrun(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("donttest_vs_dontrun accepts \\dontrun for justified cases", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("net.Rd" = c(
    "\\name{net}",
    "\\title{net}",
    "\\value{1}",
    "\\examples{",
    "\\dontrun{",
    "# Requires API token",
    "download.file('https://example.com/', '/tmp/x')",
    "}",
    "}"
  )))
  res <- diagnose_donttest_vs_dontrun(pkg, verbose = FALSE)
  expect_true(res$passed)
})

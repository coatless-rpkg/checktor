# Detection tests for the checks added in the CRAN-readiness expansion.

# ---- description_starts_with -------------------------------------------------

test_that("description_starts_with flags forbidden lead phrases", {
  for (bad in c("This package does stuff. It is helpful, really.",
                "Functions for doing stuff with stuff stuff stuff.")) {
    pkg <- make_temp_dir()
    write_pkg(pkg, description = bad)
    res <- diagnose_description_issues(pkg, verbose = FALSE)
    expect_false(res$description_starts_with$passed, info = bad)
  }

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok,
            description = paste("Provides utilities for foo.",
                                "Wraps the 'bar' package."))
  res <- diagnose_description_issues(pkg_ok, verbose = FALSE)
  expect_true(res$description_starts_with$passed)
})

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

test_that("description_quoted_quotes flags short double-quoted phrases", {
  pkg <- make_temp_dir()
  write_pkg(pkg,
            description = paste('A package with a "doctor" theme.',
                                "It does things and more things."))
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$description_quoted_quotes$passed)

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

test_that("license_year flags stale LICENSE year, passes when current", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(c("YEAR: 2019",
               "COPYRIGHT HOLDER: Test"),
             file.path(pkg, "LICENSE"))
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$license_year$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok)
  writeLines(c(paste0("YEAR: ", format(Sys.Date(), "%Y")),
               "COPYRIGHT HOLDER: Test"),
             file.path(pkg_ok, "LICENSE"))
  res2 <- diagnose_description_issues(pkg_ok, verbose = FALSE)
  expect_true(res2$license_year$passed)
})

test_that("license_year skips packages without a LICENSE file", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$license_year$passed)
})

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

test_that("unexported_example_namespace flags bare call to unexported", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("internal_fn.Rd" = c(
    "\\name{internal_fn}",
    "\\alias{internal_fn}",
    "\\title{internal_fn}",
    "\\value{1}",
    "\\examples{",
    "internal_fn(1)",
    "}"
  )))
  # Need a NAMESPACE that does NOT export internal_fn but exports something.
  writeLines(c("export(other_fn)"), file.path(pkg, "NAMESPACE"))
  res <- diagnose_unexported_example_namespace(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("unexported_example_namespace accepts exported functions", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("pub_fn.Rd" = c(
    "\\name{pub_fn}",
    "\\alias{pub_fn}",
    "\\title{pub_fn}",
    "\\value{1}",
    "\\examples{",
    "pub_fn(1)",
    "}"
  )))
  writeLines(c("export(pub_fn)"), file.path(pkg, "NAMESPACE"))
  res <- diagnose_unexported_example_namespace(pkg, verbose = FALSE)
  expect_true(res$passed)
})

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

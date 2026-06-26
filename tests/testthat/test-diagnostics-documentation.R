# ---- value tags --------------------------------------------------------------

test_that("diagnose_value_tags flags missing \\value{} in function topics", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}",
    "\\title{fn}",
    "\\usage{fn(x)}",
    "\\description{No value tag here}"
  )))
  res <- diagnose_value_tags(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(res$missing, "fn.Rd")
})

test_that("diagnose_value_tags accepts well-documented topics", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}",
    "\\title{fn}",
    "\\usage{fn(x)}",
    "\\value{A character vector.}"
  )))
  expect_true(diagnose_value_tags(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_value_tags skips data, class, package, and re-export topics", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list(
    "mydata.Rd" = c(
      "\\name{mydata}",
      "\\docType{data}",
      "\\title{mydata}",
      "\\format{A data frame}",
      "\\usage{data(mydata)}"
    ),
    "myclass.Rd" = c(
      "\\name{MyClass-class}",
      "\\docType{class}",
      "\\title{MyClass}"
    ),
    "pkg.Rd" = c(
      "\\name{pkg-package}",
      "\\alias{pkg-package}",
      "\\title{pkg}"
    ),
    "reexp.Rd" = c(
      "\\name{reexports}",
      "\\title{Objects exported from other packages}",
      "\\description{These are re-exports from other packages.}"
    )
  ))
  expect_true(diagnose_value_tags(pkg, verbose = FALSE)$passed)
})

# ---- example structure -------------------------------------------------------

test_that("diagnose_example_structure flags unjustified \\dontrun{}", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}",
    "\\title{fn}",
    "\\value{1}",
    "\\examples{",
    "\\dontrun{",
    "  x <- 1 + 1",
    "}",
    "}"
  )))
  res <- diagnose_example_structure(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("diagnose_example_structure accepts \\dontrun{} with a justifying keyword", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}",
    "\\title{fn}",
    "\\value{1}",
    "\\examples{",
    "\\dontrun{",
    "  # Requires API token",
    "  authenticate(api_key = 'secret')",
    "}",
    "}"
  )))
  expect_true(diagnose_example_structure(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_example_structure extracts only the \\examples{} block", {
  # Verifies the balanced-brace extractor doesn't bleed into other sections.
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}",
    "\\title{fn}",
    "\\value{1}",
    "\\examples{",
    "  x <- 1",       # no \\dontrun here
    "}",
    "\\seealso{",
    "  \\dontrun{not-an-example}",     # outside \\examples - must NOT trigger
    "}"
  )))
  expect_true(diagnose_example_structure(pkg, verbose = FALSE)$passed)
})

# ---- roxygen usage -----------------------------------------------------------

test_that("diagnose_roxygen_usage detects #' comments", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "#' A function",
    "#' @return TRUE",
    "f <- function() TRUE"
  ))
  res <- diagnose_roxygen_usage(pkg, verbose = FALSE)
  expect_true(res$has_roxygen)
})

test_that("diagnose_roxygen_usage reports FALSE when there are no #' lines", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() TRUE")
  res <- diagnose_roxygen_usage(pkg, verbose = FALSE)
  expect_false(res$has_roxygen)
})

# ---- missing examples --------------------------------------------------------

test_that("diagnose_missing_examples flags an exported topic without \\examples", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}",
    "\\alias{fn}",
    "\\title{fn}",
    "\\usage{fn(x)}",
    "\\value{A value.}"
  )))
  writeLines("export(fn)", file.path(pkg, "NAMESPACE"))
  res <- diagnose_missing_examples(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(res$missing, "fn.Rd")
})

test_that("diagnose_missing_examples accepts an exported topic with \\examples", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}",
    "\\alias{fn}",
    "\\title{fn}",
    "\\value{A value.}",
    "\\examples{",
    "fn(1)",
    "}"
  )))
  writeLines("export(fn)", file.path(pkg, "NAMESPACE"))
  expect_true(diagnose_missing_examples(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_missing_examples skips unexported topics and missing NAMESPACE", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}", "\\alias{fn}", "\\title{fn}", "\\value{1}"
  )))
  writeLines("export(other)", file.path(pkg, "NAMESPACE"))
  expect_true(diagnose_missing_examples(pkg, verbose = FALSE)$passed)

  pkg2 <- make_temp_dir()
  write_pkg(pkg2, rd_files = list("fn.Rd" = c(
    "\\name{fn}", "\\alias{fn}", "\\title{fn}", "\\value{1}"
  )))                                  # no NAMESPACE at all
  expect_true(diagnose_missing_examples(pkg2, verbose = FALSE)$passed)
})

# ---- Suggested packages in examples ------------------------------------------

test_that("diagnose_suggested_in_examples flags unguarded Suggested-package use", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "Suggests: dplyr", rd_files = list("fn.Rd" = c(
    "\\name{fn}", "\\title{fn}", "\\value{1}",
    "\\examples{",
    "library(dplyr)",
    "dplyr::filter(x)",
    "}"
  )))
  res <- diagnose_suggested_in_examples(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("diagnose_suggested_in_examples accepts a requireNamespace guard", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "Suggests: dplyr", rd_files = list("fn.Rd" = c(
    "\\name{fn}", "\\title{fn}", "\\value{1}",
    "\\examples{",
    "if (requireNamespace(\"dplyr\", quietly = TRUE)) {",
    "  library(dplyr)",
    "}",
    "}"
  )))
  expect_true(diagnose_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_suggested_in_examples ignores usage inside \\dontrun", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "Suggests: dplyr", rd_files = list("fn.Rd" = c(
    "\\name{fn}", "\\title{fn}", "\\value{1}",
    "\\examples{",
    "\\dontrun{",
    "library(dplyr)",
    "}",
    "}"
  )))
  expect_true(diagnose_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_suggested_in_examples passes when the package has no Suggests", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}", "\\title{fn}", "\\value{1}",
    "\\examples{",
    "library(dplyr)",
    "}"
  )))
  expect_true(diagnose_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

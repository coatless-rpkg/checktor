# R 4.6.0 builds citations and reference lists in .Rd files from a bibliography:
# \bibcitet{} and \bibcitep{} cite, \bibshow{} lists. A key R cannot find is
# dropped from the page with only a build-time warning.

# Test lab_rd_bibliography() ----

test_that("lab_rd_bibliography(): reports a key with no entry, on its line", {
  skip_without_r_bibliography()
  # R CMD check: "Could not find bibentries for the following keys: 'nokey99'"
  pkg <- bib_pkg("See \\bibcitet{smith2020} and \\bibcitep{nokey99}.")
  expect_equal(
    lab_rd_bibliography(pkg, verbose = FALSE)$issues,
    "f.Rd:4: no bibentry for 'nokey99'"
  )
})

test_that("lab_rd_bibliography(): a key in R's own bibliography is found", {
  skip_without_r_bibliography()
  pkg <- bib_pkg("See \\bibcitep{R:Chambers:2008}.", refs = list())
  expect_true(lab_rd_bibliography(pkg, verbose = FALSE)$passed)
})

test_that("lab_rd_bibliography(): reads the key out of a citespec", {
  skip_without_r_bibliography()
  pkg <- bib_pkg("See \\bibcitep{see|smith2020|page 3} and \\bibcitep{e|nokey|}.")
  expect_equal(
    lab_rd_bibliography(pkg, verbose = FALSE)$issues,
    "f.Rd:4: no bibentry for 'nokey'"
  )
})

test_that("lab_rd_bibliography(): reports a key that only \\bibshow{} names", {
  skip_without_r_bibliography()
  pkg <- bib_pkg("Text.", references = "\\bibshow{smith2020, gone2001}")
  expect_equal(
    lab_rd_bibliography(pkg, verbose = FALSE)$issues,
    "f.Rd:6: no bibentry for 'gone2001'"
  )
})

test_that("lab_rd_bibliography(): reads REFERENCES.R without running it", {
  skip_without_r_bibliography()
  pkg <- bib_pkg(
    "See \\bibcitet{jones2019} and \\bibcitet{smith2020}.",
    refs = list("inst/REFERENCES.R" = c(
      "stop('REFERENCES.R was run')",
      "c(bibentry('Book', key = 'jones2019', title = 'B', author = 'J',",
      "  publisher = 'P', year = '2019'))"
    ))
  )
  expect_equal(
    lab_rd_bibliography(pkg, verbose = FALSE)$issues,
    "f.Rd:4: no bibentry for 'smith2020'"
  )
})

test_that("lab_rd_bibliography(): uses the first REFERENCES file R would", {
  skip_without_r_bibliography()
  # R looks in the package root before inst/, and takes .rds, then .R, then
  # .bib, stopping at the first it finds.
  pkg <- bib_pkg(
    "See \\bibcitet{smith2020}.",
    refs = list(
      "REFERENCES.R" = "bibentry('Misc', key = 'other', title = 'O', year = '1')",
      "inst/REFERENCES.bib" = BIB_SMITH
    ),
    extra = "Suggests: bibtex"
  )
  writeLines("^REFERENCES\\.R$", file.path(pkg, ".Rbuildignore"))
  expect_equal(
    lab_rd_bibliography(pkg, verbose = FALSE)$issues,
    "f.Rd:4: no bibentry for 'smith2020'"
  )
})

test_that("lab_rd_bibliography(): does not guess at a bibliography it cannot read", {
  pkg <- bib_pkg(
    "See \\bibcitet{smith2020}.",
    refs = list("inst/REFERENCES.R" = "bibentry('Misc', key = make_key(), year = '1')")
  )
  expect_true(lab_rd_bibliography(pkg, verbose = FALSE)$passed)
})

test_that("lab_rd_bibliography(): reports a REFERENCES file left at the top level", {
  skip_without_r_bibliography()
  # R CMD check --as-cran: "Non-standard file/directory found at top level".
  pkg <- bib_pkg(
    "See \\bibcitet{smith2020}.",
    refs = list("REFERENCES.bib" = BIB_SMITH),
    extra = "Suggests: bibtex"
  )
  expect_equal(
    lab_rd_bibliography(pkg, verbose = FALSE)$issues,
    "REFERENCES.bib: a non-standard file at the top level; move it to inst/"
  )
  writeLines("^REFERENCES\\.bib$", file.path(pkg, ".Rbuildignore"))
  expect_true(lab_rd_bibliography(pkg, verbose = FALSE)$passed)
})

test_that("lab_rd_bibliography(): reports a citation no \\bibshow{} lists", {
  skip_without_r_bibliography()
  # R CMD check: "Bibentries cited but not shown in Rd file 'f.Rd'".
  pkg <- bib_pkg("See \\bibcitet{smith2020}.", references = NULL)
  expect_equal(
    lab_rd_bibliography(pkg, verbose = FALSE)$issues,
    "f.Rd: cited but not shown: 'smith2020'"
  )
})

test_that("lab_rd_bibliography(): an empty \\bibshow{} clears what was cited", {
  pkg <- bib_pkg(
    "See \\bibcitet{smith2020}. \\bibshow{}",
    references = NULL
  )
  expect_true(lab_rd_bibliography(pkg, verbose = FALSE)$passed)
})

test_that("lab_rd_bibliography(): checks pkg::key against an installed dependency", {
  skip_without_r_bibliography()
  dep <- make_temp_dir()
  writeLines(BIB_SMITH, file.path(dep, "REFERENCES.bib"))
  pkg <- bib_pkg(
    "See \\bibcitet{dep::smith2020}, \\bibcitet{dep::gone} and \\bibcitet{other::x}.",
    refs = list(),
    extra = "Imports: dep"
  )
  with_mocked_bindings(
    installed_package_dir = function(name) if (name == "dep") dep else "",
    expect_equal(
      lab_rd_bibliography(pkg, verbose = FALSE)$issues,
      "f.Rd:4: no bibentry for 'dep::gone'"
    )
  )
})

test_that("lab_rd_bibliography(): a dependency with no bibliography has no keys", {
  skip_without_r_bibliography()
  # R installs only inst/, so a package that kept REFERENCES at its top level
  # gives another package nothing to cite.
  dep <- make_temp_dir()
  pkg <- bib_pkg("See \\bibcitet{dep::smith2020}.", refs = list(), extra = "Suggests: dep")
  with_mocked_bindings(
    installed_package_dir = function(name) dep,
    expect_equal(
      lab_rd_bibliography(pkg, verbose = FALSE)$issues,
      "f.Rd:4: no bibentry for 'dep::smith2020'"
    )
  )
})

test_that("lab_rd_bibliography(): is skipped when R's bibliography is missing", {
  pkg <- bib_pkg("See \\bibcitet{smith2020}.")
  res <- with_mocked_bindings(
    r_bibliography_keys = function() NULL,
    lab_rd_bibliography(pkg, verbose = FALSE)
  )
  expect_true(res$skipped)
})

test_that("lab_rd_bibliography(): leaves an Rdpack bibliography alone", {
  # Rdpack keeps inst/REFERENCES.bib too, and cites with \insertRef{}.
  pkg <- bib_pkg(
    "See \\code{smith2020}.",
    references = "Smith (2020).",
    extra = "Imports: Rdpack"
  )
  expect_true(lab_rd_bibliography(pkg, verbose = FALSE)$passed)
  expect_true(lab_rd_bibliography_files(pkg, verbose = FALSE)$passed)
})

# Test lab_rd_bibliography_files() ----

test_that("lab_rd_bibliography_files(): asks for bibtex to read REFERENCES.bib", {
  pkg <- bib_pkg("See \\bibcitet{smith2020}.")
  expect_equal(
    lab_rd_bibliography_files(pkg, verbose = FALSE)$issues,
    "inst/REFERENCES.bib: reading it needs 'bibtex', which is not in Imports or Suggests"
  )
  pkg <- bib_pkg("See \\bibcitet{smith2020}.", extra = "Suggests: bibtex (>= 0.5)")
  expect_true(lab_rd_bibliography_files(pkg, verbose = FALSE)$passed)
})

test_that("lab_rd_bibliography_files(): REFERENCES.R needs no bibtex", {
  pkg <- bib_pkg(
    "See \\bibcitet{a}.",
    refs = list("inst/REFERENCES.R" = "bibentry('Misc', key = 'a', title = 'A', year = '1')")
  )
  expect_true(lab_rd_bibliography_files(pkg, verbose = FALSE)$passed)
})

test_that("lab_rd_bibliography_files(): reports a bibliography that is not installed", {
  # R reads it at build time wherever it is, but installs only inst/, and
  # another package's \bibcitet{pkg::key} looks in the installed package.
  pkg <- bib_pkg(
    "See \\bibcitet{smith2020}.",
    refs = list("REFERENCES.bib" = BIB_SMITH),
    extra = "Suggests: bibtex"
  )
  writeLines("^REFERENCES\\.bib$", file.path(pkg, ".Rbuildignore"))
  expect_equal(
    lab_rd_bibliography_files(pkg, verbose = FALSE)$issues,
    "REFERENCES.bib: not installed, so pkg::key citations cannot reach it; keep it in inst/"
  )
  pkg <- bib_pkg("See \\bibcitet{smith2020}.", extra = "Suggests: bibtex")
  writeLines("^inst/REFERENCES", file.path(pkg, ".Rbuildignore"))
  expect_equal(
    lab_rd_bibliography_files(pkg, verbose = FALSE)$issues,
    "inst/REFERENCES.bib: not installed, so pkg::key citations cannot reach it; keep it in inst/"
  )
})

test_that("lab_rd_bibliography_files(): passes a package that cites nothing", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_rd_bibliography_files(pkg, verbose = FALSE)$passed)
})

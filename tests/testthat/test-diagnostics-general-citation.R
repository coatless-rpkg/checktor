# Test lab_citation_file() ----

test_that("lab_citation_file(): flags the old-style citEntry() and personList()", {
  pkg <- citation_pkg(c(
    "bibentry(",
    "  'Manual',",
    "  title = 'Test',",
    "  author = personList(person('A', 'B'), as.personList('C D')),",
    "  year = '2026'",
    ")",
    "citEntry(entry = 'Manual', title = 'Test', year = '2026')"
  ))
  res <- lab_citation_file(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_length(res$issues, 3L)
  expect_match(res$issues[[1]], "^inst/CITATION:4 .*personList\\(\\).*c\\(\\)")
  expect_match(res$issues[[2]], "^inst/CITATION:4 .*as\\.personList\\(\\)")
  expect_match(
    res$issues[[3]],
    "^inst/CITATION:7 .*citEntry\\(\\).*bibentry\\(\\)"
  )
  # Each finding carries a location issues() can point at.
  expect_identical(.split_issue(res$issues)$line, c(4L, 4L, 7L))
})

test_that("lab_citation_file(): flags calls that assume the package is installed", {
  pkg <- citation_pkg(c(
    "library(utils)",
    "desc <- packageDescription('testpkg')",
    "if (!require(stats)) stop()",
    "bibentry('Manual', title = 'Test', year = desc$Date)"
  ))
  res <- lab_citation_file(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "^inst/CITATION:[123] ")
  expect_match(res$issues[[1]], "library()", fixed = TRUE)
  expect_match(res$issues[[2]], "packageDescription().*meta")
  expect_match(res$issues[[3]], "require()", fixed = TRUE)
})

test_that("lab_citation_file(): exempts R's own `meta` fallback idiom", {
  # digest, mlbench and cluster all do this. R drops a top-level `if` with exactly
  # this condition and no else before looking, so it is not a finding.
  pkg <- citation_pkg(c(
    "if (!exists('meta') || is.null(meta)) meta <- packageDescription('testpkg')",
    "if(!exists(\"meta\")||is.null(meta)) {",
    "  meta <- packageDescription(\"testpkg\")",
    "}",
    "bibentry('Manual', title = 'Test', year = meta$Date)"
  ))
  expect_true(lab_citation_file(pkg, verbose = FALSE)$passed)

  # Only that exact form: another condition, or an else branch, is not exempt.
  other <- citation_pkg(c(
    "if (is.null(meta)) meta <- packageDescription('testpkg')",
    "if (!exists('meta') || is.null(meta)) 1 else library(utils)",
    "if (!exists(meta) || is.null(meta)) require(utils)"
  ))
  res <- lab_citation_file(other, verbose = FALSE)
  expect_match(res$issues, "^inst/CITATION:[123] ")
  expect_length(res$issues, 3L)
})

test_that("lab_citation_file(): reads the parse tree, not the text", {
  pkg <- citation_pkg(c(
    "# citEntry() and personList() are the old style",
    "bibentry('Manual', title = 'Why not citEntry(x) or library(y)', year = '2026',",
    "  textVersion = paste('packageDescription(', 'x)'))"
  ))
  expect_true(lab_citation_file(pkg, verbose = FALSE)$passed)

  # A namespaced call is still the call.
  ns <- citation_pkg(
    "utils::citEntry(entry = 'Manual', title = 'T', year = '2026')"
  )
  expect_match(
    lab_citation_file(ns, verbose = FALSE)$issues,
    "citEntry()",
    fixed = TRUE
  )
})

test_that("lab_citation_file(): reports a CITATION that does not parse", {
  pkg <- citation_pkg(c("bibentry('Manual',", "  title = 'T' year = '2026')"))
  res <- lab_citation_file(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_length(res$issues, 1L)
  expect_match(
    res$issues,
    "^inst/CITATION:2 \\(does not parse: unexpected symbol at column 15\\)$"
  )
})

test_that("lab_citation_file(): passes without a CITATION the tarball ships", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_citation_file(pkg, verbose = FALSE)$passed)

  ignored <- citation_pkg(
    "citEntry(entry = 'Manual', title = 'T', year = '2026')"
  )
  writeLines("^inst/CITATION$", file.path(ignored, ".Rbuildignore"))
  expect_true(lab_citation_file(ignored, verbose = FALSE)$passed)
})

test_that("lab_citation_file(): reads a CITATION in the package's declared encoding", {
  # "Mueller" with a u-umlaut, in latin1: the byte 0xFC is not valid UTF-8.
  name <- rawToChar(as.raw(c(0x4d, 0xfc, 0x6c, 0x6c, 0x65, 0x72)))
  pkg <- citation_pkg(
    paste0(
      "bibentry('Manual', title = 'T', author = person('A', '",
      name,
      "'), year = '2026')"
    )
  )
  desc <- file.path(pkg, "DESCRIPTION")
  writeLines(sub("^Encoding: .*", "Encoding: latin1", readLines(desc)), desc)
  expect_true(lab_citation_file(pkg, verbose = FALSE)$passed)
})

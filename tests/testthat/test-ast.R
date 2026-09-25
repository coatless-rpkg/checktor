# The parse-tree helpers in R/ast.R that every check is built on.

# Test read_r_xml() ----

test_that("read_r_xml(): parses every R/*.R file and reports per-file errors", {
  # A DESCRIPTION, so read_r_xml()'s root search stops here rather than walking
  # up from tempdir().
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = NULL)
  writeLines("f <- function() 1", file.path(pkg, "R", "good.R"))
  writeLines("this is not valid", file.path(pkg, "R", "broken.R"))

  parsed <- read_r_xml(pkg)
  expect_setequal(basename(names(parsed)), c("good.R", "broken.R"))
  ok <- parsed[[file.path(pkg, "R", "good.R")]]
  bad <- parsed[[file.path(pkg, "R", "broken.R")]]
  expect_null(ok$error)
  expect_s3_class(ok$xml, "xml_document")
  expect_equal(xml2::xml_text(xml2::xml_find_all(ok$xml, "//SYMBOL")), "f")
  expect_s3_class(bad$error, "error")
  expect_null(bad$xml)
})

test_that("read_r_xml(): reads the parse tree when keep.parse.data is off", {
  # sys.source() and some IDE tooling set the option to FALSE, and parse() then
  # keeps no parse data, so every file came back with no tree to query.
  withr::local_options(keep.parse.data = FALSE)
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() T")

  parsed <- read_r_xml(pkg)[[1L]]
  expect_null(parsed$error)
  expect_s3_class(parsed$xml, "xml_document")
  expect_equal(
    xml2::xml_attr(xml2::xml_find_all(parsed$xml, "//SYMBOL[text() = 'T']"), "line1"),
    "1"
  )
  expect_false(getOption("keep.parse.data"))
})

# Test parse_text_xml() ----

test_that("parse_text_xml(): reads the parse tree when keep.parse.data is off", {
  withr::local_options(keep.parse.data = FALSE)

  xml <- parse_text_xml("install.packages('somepkg')\nx <- utils:::f(1)")
  expect_s3_class(xml, "xml_document")
  calls <- xml2::xml_find_all(xml, "//SYMBOL_FUNCTION_CALL")
  expect_equal(xml2::xml_text(calls), c("install.packages", "f"))
  expect_equal(xml2::xml_attr(calls, "line1"), c("1", "2"))
  expect_false(getOption("keep.parse.data"))
})

test_that("parse_text_xml(): returns NULL for code that does not parse", {
  expect_null(parse_text_xml("f(<placeholder>)"))
})

# Test undesirable_function_check() ----

test_that("undesirable_function_check(): ignores function names in strings", {
  # A DESCRIPTION, so read_r_xml()'s root search stops here rather than walking
  # up from tempdir().
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = NULL)
  writeLines(
    c(
      "msg <- 'browser() reminder'",
      "f <- function() browser()"
    ),
    file.path(pkg, "R", "f.R")
  )
  parsed <- read_r_xml(pkg)
  hits <- undesirable_function_check(parsed, "browser", label = FALSE)
  expect_equal(length(hits), 1L)
  expect_match(hits, "f\\.R:2")
})

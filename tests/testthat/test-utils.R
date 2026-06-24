test_that("build_ignore_matcher recognises .Rbuildignore entries", {
  pkg <- tempfile()
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  writeLines(c("^foo/", "^bar\\.txt$"), file.path(pkg, ".Rbuildignore"))
  matcher <- build_ignore_matcher(pkg)
  expect_true(matcher("foo/anything.R"))
  expect_true(matcher("bar.txt"))
  expect_false(matcher("baz.R"))
})

test_that("build_ignore_matcher always skips .git and friends", {
  pkg <- tempfile()
  dir.create(pkg)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  matcher <- build_ignore_matcher(pkg)  # no .Rbuildignore present
  expect_true(matcher(".git/HEAD"))
  expect_true(matcher(".Rproj.user/foo"))
  expect_false(matcher("R/code.R"))
})

test_that("read_r_xml parses every R/*.R file and reports per-file errors", {
  pkg <- tempfile()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  writeLines("f <- function() 1", file.path(pkg, "R", "good.R"))
  writeLines("this is not valid", file.path(pkg, "R", "broken.R"))

  parsed <- read_r_xml(pkg)
  expect_equal(length(parsed), 2L)
  ok <- parsed[[file.path(pkg, "R", "good.R")]]
  bad <- parsed[[file.path(pkg, "R", "broken.R")]]
  expect_null(ok$error)
  expect_false(is.null(ok$xml))
  expect_false(is.null(bad$error))
  expect_true(is.null(bad$xml))
})

test_that("undesirable_function_check ignores function names inside strings", {
  pkg <- tempfile()
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  on.exit(unlink(pkg, recursive = TRUE), add = TRUE)
  writeLines(c(
    "msg <- 'browser() reminder'",
    "f <- function() browser()"
  ), file.path(pkg, "R", "f.R"))
  parsed <- read_r_xml(pkg)
  hits <- undesirable_function_check(parsed, "browser", label = FALSE)
  expect_equal(length(hits), 1L)
  expect_match(hits, "f\\.R:2")
})

test_that("extract_rd_section finds a top-level Rd section by tag", {
  rd_file <- tempfile(fileext = ".Rd")
  on.exit(unlink(rd_file), add = TRUE)
  writeLines(c(
    "\\name{x}",
    "\\title{Title}",
    "\\value{a number}"
  ), rd_file)
  rd <- tools::parse_Rd(rd_file)
  val <- extract_rd_section(rd, "\\value")
  expect_false(is.null(val))
  expect_match(collect_rd_text(val), "a number")
  expect_null(extract_rd_section(rd, "\\seealso"))
})

test_that("collect_rd_text honours the skip argument", {
  rd_file <- tempfile(fileext = ".Rd")
  on.exit(unlink(rd_file), add = TRUE)
  writeLines(c(
    "\\name{x}",
    "\\title{Title}",
    "\\value{1}",
    "\\examples{",
    "  visible_part()",
    "  \\dontrun{ hidden_part() }",
    "}"
  ), rd_file)
  rd <- tools::parse_Rd(rd_file)
  ex <- extract_rd_section(rd, "\\examples")
  full <- collect_rd_text(ex)
  expect_match(full, "visible_part")
  expect_match(full, "hidden_part")
  skipped <- collect_rd_text(ex, skip = "\\dontrun")
  expect_match(skipped, "visible_part")
  expect_false(grepl("hidden_part", skipped))
})

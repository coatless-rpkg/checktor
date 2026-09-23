# The parse-tree and Rd helpers in R/ast.R that every check is built on.

# Test write_destination() ----

test_that("write_destination(): resolves each writer's destination argument", {
  # This used to read expect_setequal(WRITE_FUNCTIONS, names(WRITE_DEST_ARG)),
  # which is x == x: WRITE_FUNCTIONS is DEFINED as names(WRITE_DEST_ARG), so no
  # edit to either could ever fail it. The expectations below are written out
  # independently of the map, so a position that moves, or a writer that
  # disappears, fails here. `dir.create()` is why the map exists at all: assuming
  # "the second argument" reads its `showWarnings` flag as a path.
  expected <- c(
    write.csv = "p2", write.table = "p2", writeLines = "p2", saveRDS = "p2",
    write_csv = "p2", fwrite = "p2", write_xlsx = "p2", write_parquet = "p2",
    download.file = "p2",
    save.image = "p1", file.create = "p1", dir.create = "p1", sink = "p1",
    png = "p1", ggsave = "p1"
  )
  for (fn in names(expected)) {
    expect_true(fn %in% WRITE_FUNCTIONS, info = fn)
    xml <- parse_text_xml(sprintf("%s(p1, p2, p3)", fn))
    dest <- write_destination(xml2::xml_find_first(xml, "//SYMBOL_FUNCTION_CALL"))
    expect_false(is.null(dest), info = fn)
    expect_equal(xml2::xml_text(dest), expected[[fn]], info = fn)
  }

  # `save(x, y, file = )` never takes its destination positionally, which is what
  # the NA entries mean. They must find the named argument and nothing else.
  for (fn in c("cat", "save", "capture.output")) {
    expect_true(is.na(WRITE_DEST_ARG[[fn]]), info = fn)
    xml <- parse_text_xml(sprintf("%s(p1, p2, p3)", fn))
    expect_null(
      write_destination(xml2::xml_find_first(xml, "//SYMBOL_FUNCTION_CALL")),
      info = fn
    )
    named <- parse_text_xml(sprintf("%s(p1, file = 'out.txt')", fn))
    expect_equal(
      xml2::xml_text(write_destination(
        xml2::xml_find_first(named, "//SYMBOL_FUNCTION_CALL")
      )),
      "'out.txt'",
      info = fn
    )
  }
})

# Test read_r_xml() ----

test_that("read_r_xml(): parses every R/*.R file and reports per-file errors", {
  # A DESCRIPTION, so read_r_xml()'s root search stops here rather than walking
  # up from tempdir().
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = NULL)
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

# Test extract_rd_section() ----

test_that("extract_rd_section(): finds a top-level Rd section by tag", {
  rd_file <- withr::local_tempfile(fileext = ".Rd")
  writeLines(
    c(
      "\\name{x}",
      "\\title{Title}",
      "\\value{a number}"
    ),
    rd_file
  )
  rd <- tools::parse_Rd(rd_file)
  val <- extract_rd_section(rd, "\\value")
  expect_false(is.null(val))
  expect_match(collect_rd_text(val), "a number")
  expect_null(extract_rd_section(rd, "\\seealso"))
})

# Test collect_rd_text() ----

test_that("collect_rd_text(): honours the skip argument", {
  rd_file <- withr::local_tempfile(fileext = ".Rd")
  writeLines(
    c(
      "\\name{x}",
      "\\title{Title}",
      "\\value{1}",
      "\\examples{",
      "  visible_part()",
      "  \\dontrun{ hidden_part() }",
      "}"
    ),
    rd_file
  )
  rd <- tools::parse_Rd(rd_file)
  ex <- extract_rd_section(rd, "\\examples")
  full <- collect_rd_text(ex)
  expect_match(full, "visible_part")
  expect_match(full, "hidden_part")
  skipped <- collect_rd_text(ex, skip = "\\dontrun")
  expect_match(skipped, "visible_part")
  expect_false(grepl("hidden_part", skipped))
})

# Test is_commented_out_code() ----

test_that("is_commented_out_code(): separates prose from commented-out calls", {
  prose <- c(
    "# --- end", # separator: parses as unary minus
    "# --- welcome",
    "# Simulate random choices (default)",
    "# (Columns are attributes, rows are alternatives)",
    "# Example 2: Named categorical priors (more explicit)",
    "# TODO",
    "#' roxygen line"
  )
  code <- c(
    '# sd_copy_value(id = "name")',
    "# all_params <- sd_get_url_pars()",
    '# message("Age question answered!")',
    "# foo(slow = TRUE)"
  )
  expect_false(any(vapply(prose, is_commented_out_code, logical(1))))
  expect_true(all(vapply(code, is_commented_out_code, logical(1))))
})

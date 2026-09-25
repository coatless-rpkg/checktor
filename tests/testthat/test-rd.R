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

# Test rd_sections() ----

test_that("rd_sections(): returns every section with the tag, in page order", {
  rd_file <- withr::local_tempfile(fileext = ".Rd")
  writeLines(
    c(
      "\\name{x}",
      "\\alias{x}",
      "\\alias{ y }",
      "\\title{Title}",
      "\\keyword{internal}"
    ),
    rd_file
  )
  rd <- tools::parse_Rd(rd_file)
  expect_length(rd_sections(rd, "\\alias"), 2L)
  expect_identical(rd_section_texts(rd, "\\alias"), c("x", "y"))
  expect_identical(rd_section_texts(rd, "\\value"), character(0))
  expect_identical(rd_primary_name(rd), "x")
  expect_true(rd_is_internal(rd))
})

# Test rd_examples() ----

test_that("rd_examples(): skips a page that does not parse or has no examples", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "a.Rd" = c("\\name{a}", "\\title{A}", "\\examples{", "a()", "}"),
      "b.Rd" = c("\\name{b}", "\\title{B}", "\\value{x}"),
      "c.Rd" = c("\\name{c}", "\\title{C", "\\examples{", "c()", "}")
    )
  )
  pages <- suppressWarnings(rd_examples(pkg))
  expect_identical(basename(vapply(pages, `[[`, character(1), "file")), "a.Rd")
  expect_match(collect_rd_text(pages[[1L]]$examples), "a()", fixed = TRUE)
})

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

test_that("write_destination(): counts only unnamed arguments as positions", {
  # R binds named arguments first and fills the remaining formals in order. A
  # named `sep =` or `plot =` therefore leaves the destination where it was, and
  # naming the data formal the destination follows moves it up to the first
  # unnamed argument.
  dest <- function(code) {
    calls <- xml2::xml_find_all(parse_text_xml(code), "//SYMBOL_FUNCTION_CALL")
    node <- calls[xml2::xml_text(calls) %in% WRITE_FUNCTIONS][[1L]]
    xml2::xml_text(write_destination(node))
  }
  expect_equal(dest("writeLines(sep = '\\n', x, 'out')"), "'out'")
  expect_equal(dest("write.csv(row.names = FALSE, x, 'out')"), "'out'")
  expect_equal(dest("ggplot2::ggsave(plot = p, 'out')"), "'out'")
  expect_equal(dest("writeLines(text = x, 'out')"), "'out'")
  expect_equal(dest("saveRDS(object = x, 'out')"), "'out'")
  expect_equal(dest("file.copy(from = x, 'out')"), "'out'")
  # file.copy() and file.rename() call their destination `to`.
  expect_equal(dest("file.copy(to = 'out', from = x)"), "'out'")
  expect_equal(dest("file.rename(to = 'out', from = x)"), "'out'")
})

test_that("write_destination(): knows the formal each destination follows", {
  # A destination in second place follows the data formal in WRITE_DATA_FORMAL.
  # The names are checked against the functions themselves where R ships them;
  # write.csv() takes `...` and hands them to write.table().
  second <- names(WRITE_DEST_ARG)[vapply(
    WRITE_DEST_ARG, function(p) identical(p, 2L), logical(1)
  )]
  expect_setequal(names(WRITE_DATA_FORMAL), second)
  for (fn in c("writeLines", "writeBin", "saveRDS", "write", "write.table",
               "file.copy", "file.rename", "download.file")) {
    expect_equal(
      WRITE_DATA_FORMAL[[fn]], names(formals(get(fn)))[[1L]],
      info = fn
    )
  }
  expect_equal(WRITE_DATA_FORMAL[["write.csv"]], names(formals(write.table))[[1L]])
})

test_that("write_destination(): takes a piped value as the first argument", {
  dest <- function(code) {
    calls <- xml2::xml_find_all(parse_text_xml(code), "//SYMBOL_FUNCTION_CALL")
    node <- calls[xml2::xml_text(calls) %in% WRITE_FUNCTIONS][[1L]]
    write_destination(node)
  }
  expect_equal(xml2::xml_text(dest("x |> writeLines('out')")), "'out'")
  expect_equal(xml2::xml_text(dest("d %>% write.csv('out')")), "'out'")
  expect_equal(xml2::xml_text(dest("d %T>% write.csv('out')")), "'out'")
  expect_equal(xml2::xml_text(dest("d |> f() |> write.csv('out')")), "'out'")
  expect_equal(xml2::xml_text(dest("'out' |> png()")), "'out'")
  expect_equal(xml2::xml_text(dest("'out' %>% file.create()")), "'out'")
  # A placeholder says where the left-hand side goes instead: a bare `.` argument
  # for magrittr, a named `_` for the native pipe.
  expect_equal(xml2::xml_text(dest("d %>% write.csv(., 'out')")), "'out'")
  expect_equal(xml2::xml_text(dest("'out' %>% writeLines(x, .)")), "'out'")
  expect_equal(
    xml2::xml_text(dest("'out' |> writeLines(text = x, con = _)")),
    "'out'"
  )
  # A `.` inside an argument is not a placeholder, so the value still goes first.
  # xml_text() joins the tokens without their spaces.
  expect_equal(
    xml2::xml_text(dest("d %>% write.csv(file.path(., 'out'))")),
    "file.path(.,'out')"
  )
  # `%$%` exposes names rather than passing its left-hand side, and `+` is no pipe.
  expect_equal(xml2::xml_text(dest("d %$% writeLines(x, 'out')")), "'out'")
  expect_null(dest("d + writeLines('out')"))
})

test_that("write_destination(): a method named like a writer has no destination", {
  # htmltools' `tags$svg()` builds a tag and anndata's `adata$write()` has its
  # own arguments. Read as grDevices::svg() and base::write(), their first
  # unnamed arguments were taken for paths.
  node <- function(code, fn) {
    xml2::xml_find_first(
      parse_text_xml(code),
      sprintf("//SYMBOL_FUNCTION_CALL[text() = '%s']", fn)
    )
  }
  expect_null(write_destination(
    node("tags$svg(width = 24, tags$g(fill = 'currentColor'))", "svg")
  ))
  expect_null(write_destination(node("adata$write(path, 'gzip')", "write")))
  expect_equal(
    xml2::xml_text(write_destination(node("grDevices::svg('out.svg')", "svg"))),
    "'out.svg'"
  )
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

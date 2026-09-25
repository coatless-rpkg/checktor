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

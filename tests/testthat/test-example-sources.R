# Where the code outside R/ comes from: examples, vignettes, demos and tests.

# Test rd_example_code() ----

test_that("rd_example_code(): gives the example as R, on the .Rd file's lines", {
  # An Rd `%` comment is dropped, as R drops it. A line of a hidden block that is
  # not R is blanked so the rest can parse. Nothing is added: the markers another
  # check wraps blocks in are not part of the example.
  pkg <- rd_pkg(c(
    "x <- 1 % an Rd comment",
    "\\dontrun{",
    "my_fn(<your API key>)",
    "y <- 2",
    "}"
  ))
  src <- rd_example_code(pkg)
  expect_length(src, 1L)
  expect_equal(basename(src[[1L]]$file), "f.Rd")
  expect_equal(src[[1L]]$kind, "example")
  lines <- strsplit(src[[1L]]$code, "\n", fixed = TRUE)[[1L]]
  expect_equal(which(nzchar(trimws(lines))), c(7L, 10L))
  expect_equal(trimws(lines[c(7L, 10L)]), c("x <- 1", "y <- 2"))
})

test_that("rd_example_code(): keeps an example that parses exactly as written", {
  # Only an example that will not parse is repaired. Read on its own a line at a
  # time, this block splits the `else` from its `if`, which inside the guard's
  # braces is valid R.
  pkg <- rd_pkg(c(
    "if (interactive()) {",
    "\\dontrun{",
    "if (a) {", "  b()", "}", "else c()",
    "}",
    "}"
  ))
  lines <- strsplit(rd_example_code(pkg)[[1L]]$code, "\n", fixed = TRUE)[[1L]]
  expect_equal(lines[9:12], c("if (a) {", "  b()", "}", "else c()"))
})

test_that("rd_example_code(): drops an #ifdef condition and keeps the lines after it", {
  # The condition names a platform and is not R. parse_Rd() folds the `#endif`
  # line into the #ifdef, so each directive line becomes a blank one, and the code
  # after the block stays on its line of the .Rd file.
  pkg <- rd_pkg(c("#ifdef windows", "x <- 1", "#endif", "y <- 2"))
  lines <- strsplit(rd_example_code(pkg)[[1L]]$code, "\n", fixed = TRUE)[[1L]]
  expect_equal(lines[7:10], c("", "x <- 1", "", "y <- 2"))
})

test_that("rd_example_code(): keeps a ; after a block on the block's line", {
  # A line of R cannot start with `;`, so the code after the block stays on the
  # line with it, as it is written. That holds in a block cut down to the lines
  # that parse, too.
  pkg <- rd_pkg(c("\\dontrun{f()}; g()", "h()"))
  src <- rd_example_code(pkg)[[1L]]
  expect_true(parses(src$code))
  lines <- strsplit(src$code, "\n", fixed = TRUE)[[1L]]
  expect_equal(lines[7:8], c("f(); g()", "h()"))

  pkg <- rd_pkg(
    c("\\donttest{", "key <- <your key>", "\\dontrun{f()}; g()", "}")
  )
  lines <- strsplit(rd_example_code(pkg)[[1L]]$code, "\n", fixed = TRUE)[[1L]]
  expect_equal(which(nzchar(trimws(lines))), 9L)
  expect_equal(lines[[9L]], "f(); g()")
})

test_that("rd_example_code(): reads on past a block an operator continues", {
  # R reads `\dontrun{f()} |> g()` as one line, `f() |> g()`, so the break
  # after the block must not split it, or the whole example stops parsing.
  for (example in c("\\dontrun{f()} |> g()", "\\dontrun{f()} -> y", "\\dontshow{x} * 2")) {
    pkg <- rd_pkg(c(example, "install.packages('x')"))
    expect_identical(
      lab_example_installs(pkg, verbose = FALSE)$issues,
      "example f.Rd:8 (installs software)",
      label = example
    )
  }
})

# Test read_example_xml() ----

test_that("read_example_xml(): parses an example with a broken hidden block", {
  pkg <- rd_pkg(c("\\dontrun{", "my_fn(<your API key>)", "}", "g(1)"))
  parsed <- read_example_xml(pkg, kinds = "example")
  expect_length(parsed, 1L)
  call <- xml2::xml_find_all(parsed[[1L]]$xml, "//SYMBOL_FUNCTION_CALL")
  expect_equal(xml2::xml_text(call), "g")
  expect_equal(xml2::xml_attr(call, "line1"), "10")
})

test_that("read_example_xml(): reads a block that shares a line on that line", {
  # A block's body is read on lines of its own, as Rd2ex lays out a block it
  # runs, so two blocks on one line, or a block that is a call's argument, parse
  # as R reads them. Each call is still reported on the line of the .Rd file it
  # is written on.
  pkg <- rd_pkg(c(
    "\\dontrun{f()}\\donttest{g()}",
    "suppressWarnings(\\donttest{h()})",
    "k()"
  ))
  parsed <- read_example_xml(pkg, kinds = "example")
  expect_length(parsed, 1L)
  calls <- xml2::xml_find_all(parsed[[1L]]$xml, "//SYMBOL_FUNCTION_CALL")
  expect_equal(xml2::xml_text(calls), c("f", "g", "suppressWarnings", "h", "k"))
  expect_equal(xml2::xml_attr(calls, "line1"), c("7", "7", "8", "8", "9"))
  exprs <- xml2::xml_find_all(parsed[[1L]]$xml, "/exprlist/expr")
  expect_equal(xml2::xml_attr(exprs, "line2"), c("7", "7", "8", "9"))
})

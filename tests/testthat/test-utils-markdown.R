# Test blank_fenced_code() ----

test_that("blank_fenced_code(): blanks a fence and its contents in place", {
  lines <- c("before", "```r", "x <- 1", "```", "after")
  expect_identical(
    blank_fenced_code(lines),
    c("before", "", "", "", "after")
  )
})

test_that("blank_fenced_code(): leaves a file with no fence untouched", {
  lines <- c("# Title", "Some prose with `code` in it.", "")
  expect_identical(blank_fenced_code(lines), lines)
})

test_that("blank_fenced_code(): a shorter fence does not close a longer one", {
  # A README showing markdown quotes a ``` block inside a ```` one.
  lines <- c("````md", "```r", "x <- 1", "```", "quoted", "````", "after")
  expect_identical(
    blank_fenced_code(lines),
    c(rep("", 6L), "after")
  )
})

test_that("blank_fenced_code(): knows a tilde fence", {
  expect_identical(
    blank_fenced_code(c("~~~", "x <- 1", "~~~", "after")),
    c("", "", "", "after")
  )
})

test_that("blank_fenced_code(): a tilde fence is not closed by backticks", {
  expect_identical(
    blank_fenced_code(c("~~~", "```", "x <- 1", "~~~", "after")),
    c("", "", "", "", "after")
  )
})

test_that("blank_fenced_code(): a fence left open runs to the end of the file", {
  expect_identical(
    blank_fenced_code(c("before", "```r", "x <- 1")),
    c("before", "", "")
  )
})

test_that("blank_fenced_code(): three spaces open a fence and four do not", {
  expect_identical(
    blank_fenced_code(c("   ```r", "x <- 1", "   ```")),
    c("", "", "")
  )
  indented <- c("    ```r", "x <- 1")
  expect_identical(blank_fenced_code(indented), indented)
})

test_that("blank_fenced_code(): a backtick in the info string means no fence", {
  # ``` `a` ``` is a code span sitting on its own line, not a block opener.
  lines <- c("``` `a` ```", "after")
  expect_identical(blank_fenced_code(lines), lines)
})

test_that("blank_fenced_code(): a knitr chunk header is a fence anyway", {
  # knitr lets a chunk option come from inline R, backticks and all.
  expect_identical(
    blank_fenced_code(c("```{r, eval = `r ok`}", "x <- 1", "```", "after")),
    c("", "", "", "after")
  )
})

test_that("blank_fenced_code(): a closing fence carries no info string", {
  # "```r" reopens nothing; it is content until a bare fence arrives.
  expect_identical(
    blank_fenced_code(c("```", "```r", "```", "after")),
    c("", "", "", "after")
  )
})

# Test blank_code_spans() ----

test_that("blank_code_spans(): replaces a span with spaces of equal width", {
  out <- blank_code_spans("Use `fn()` here.")
  expect_identical(out, "Use        here.")
  expect_identical(nchar(out), nchar("Use `fn()` here."))
})

test_that("blank_code_spans(): leaves a line with no backtick alone", {
  expect_identical(blank_code_spans("plain prose"), "plain prose")
})

test_that("blank_code_spans(): only an equal-length run closes a span", {
  # The single backtick inside the ``...`` span is content, not a closer.
  expect_identical(
    blank_code_spans("a ``x ` y`` b"),
    paste0("a ", strrep(" ", 9L), " b")
  )
})

test_that("blank_code_spans(): an unpaired run is ordinary text", {
  expect_identical(
    blank_code_spans("It is a `bad idea to leave one."),
    "It is a `bad idea to leave one."
  )
})

test_that("blank_code_spans(): pairs runs left to right", {
  expect_identical(
    blank_code_spans("`a` and `b`"),
    "    and    "
  )
})

# Test strip_markdown_code() ----

test_that("strip_markdown_code(): returns one string, newline joined", {
  expect_identical(strip_markdown_code(c("a", "b")), "a\nb")
})

test_that("strip_markdown_code(): blanks fences, spans and comments together", {
  lines <- c(
    "```r",
    "x <- 1",
    "```",
    "Use `fn()` and <!-- a comment --> keep this."
  )
  out <- strip_markdown_code(lines)
  expect_false(grepl("x <- 1", out, fixed = TRUE))
  expect_false(grepl("fn()", out, fixed = TRUE))
  expect_false(grepl("a comment", out, fixed = TRUE))
  expect_true(grepl("keep this", out, fixed = TRUE))
})

test_that("strip_markdown_code(): a comment may run over several lines", {
  out <- strip_markdown_code(c("<!--", "hidden", "-->", "shown"))
  expect_false(grepl("hidden", out, fixed = TRUE))
  expect_true(grepl("shown", out, fixed = TRUE))
})

test_that("strip_markdown_code(): a comment ends at the first close", {
  # The badge block sits between two comments, not inside one.
  out <- strip_markdown_code(c(
    "<!-- badges: start -->",
    "[![cov](x.svg)](y.html)",
    "<!-- badges: end -->"
  ))
  expect_true(grepl("x.svg", out, fixed = TRUE))
  expect_true(grepl("y.html", out, fixed = TRUE))
})

test_that("strip_markdown_code(): an unterminated comment is left alone", {
  out <- strip_markdown_code(c("shown", "<!-- dangling"))
  expect_true(grepl("shown", out, fixed = TRUE))
})

test_that("strip_markdown_code(): a span cannot pair across a line break", {
  # Pairing file-wide would let these two backticks blank the line between them.
  out <- strip_markdown_code(c("Use ` here.", "keep this", "and ` there."))
  expect_true(grepl("keep this", out, fixed = TRUE))
})

test_that("strip_markdown_code(): a trailing CR does not break a fence", {
  out <- strip_markdown_code(c("```r\r", "x <- 1\r", "```\r", "shown\r"))
  expect_identical(out, "\n\n\nshown")
})

test_that("strip_markdown_code(): handles an empty file", {
  expect_identical(strip_markdown_code(character(0)), "")
})

# Test extract_link_targets() ----

test_that("extract_link_targets(): finds markdown and HTML targets", {
  expect_setequal(
    extract_link_targets('[a](docs/a.md) <img src="man/figures/l.png">'),
    c("docs/a.md", "man/figures/l.png")
  )
})

test_that("extract_link_targets(): strips an optional link title", {
  expect_identical(
    extract_link_targets('[a](docs/a.md "The Guide")'),
    "docs/a.md"
  )
})

test_that("extract_link_targets(): unwraps a pointy-bracketed destination", {
  expect_identical(extract_link_targets("[a](<a file.md>)"), "a file.md")
})

test_that("extract_link_targets(): rejects a bare target containing a space", {
  # `knitr::opts_chunk[["set"]](` ends in `](`, so its arguments read as a
  # destination unless one that could not be a destination is thrown out.
  expect_identical(
    extract_link_targets('x[["set"]](\n  collapse = TRUE\n)'),
    character(0)
  )
})

test_that("extract_link_targets(): finds nothing in text with no links", {
  expect_identical(extract_link_targets("plain prose"), character(0))
})

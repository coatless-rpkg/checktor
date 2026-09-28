# Test blank_fenced_code() ----

test_that("blank_fenced_code(): blanks a fenced block by CommonMark's rules", {
  cases <- list(
    "a fence and its contents, in place" = list(
      lines = c("before", "```r", "x <- 1", "```", "after"),
      expected = c("before", "", "", "", "after")
    ),
    "a file with no fence" = list(
      lines = c("# Title", "Some prose with `code` in it.", ""),
      expected = c("# Title", "Some prose with `code` in it.", "")
    ),
    # A README showing markdown quotes a ``` block inside a ```` one.
    "a shorter fence does not close a longer one" = list(
      lines = c("````md", "```r", "x <- 1", "```", "quoted", "````", "after"),
      expected = c(rep("", 6L), "after")
    ),
    "a tilde fence" = list(
      lines = c("~~~", "x <- 1", "~~~", "after"),
      expected = c("", "", "", "after")
    ),
    "a tilde fence is not closed by backticks" = list(
      lines = c("~~~", "```", "x <- 1", "~~~", "after"),
      expected = c("", "", "", "", "after")
    ),
    "a fence left open runs to the end of the file" = list(
      lines = c("before", "```r", "x <- 1"),
      expected = c("before", "", "")
    ),
    "three spaces open a fence" = list(
      lines = c("   ```r", "x <- 1", "   ```"),
      expected = c("", "", "")
    ),
    "four spaces do not" = list(
      lines = c("    ```r", "x <- 1"),
      expected = c("    ```r", "x <- 1")
    ),
    # ``` `a` ``` is a code span sitting on its own line, not a block opener.
    "a backtick in the info string means no fence" = list(
      lines = c("``` `a` ```", "after"),
      expected = c("``` `a` ```", "after")
    ),
    # knitr lets a chunk option come from inline R, backticks and all.
    "a knitr chunk header is a fence anyway" = list(
      lines = c("```{r, eval = `r ok`}", "x <- 1", "```", "after"),
      expected = c("", "", "", "after")
    ),
    # "```r" reopens nothing; it is content until a bare fence arrives.
    "a closing fence carries no info string" = list(
      lines = c("```", "```r", "```", "after"),
      expected = c("", "", "", "after")
    )
  )
  for (case in names(cases)) {
    expect_identical(
      blank_fenced_code(cases[[case]]$lines),
      cases[[case]]$expected,
      info = case
    )
  }
})

# Test blank_code_spans() ----

test_that("blank_code_spans(): blanks a code span to spaces of equal width", {
  cases <- list(
    "a span becomes spaces" = list(
      input = "Use `fn()` here.",
      expected = "Use        here."
    ),
    "a line with no backtick" = list(
      input = "plain prose",
      expected = "plain prose"
    ),
    # The single backtick inside the ``...`` span is content, not a closer.
    "only an equal-length run closes a span" = list(
      input = "a ``x ` y`` b",
      expected = paste0("a ", strrep(" ", 9L), " b")
    ),
    "an unpaired run is ordinary text" = list(
      input = "It is a `bad idea to leave one.",
      expected = "It is a `bad idea to leave one."
    ),
    "runs pair left to right" = list(
      input = "`a` and `b`",
      expected = "    and    "
    )
  )
  for (case in names(cases)) {
    out <- blank_code_spans(cases[[case]]$input)
    expect_identical(out, cases[[case]]$expected, info = case)
    expect_identical(nchar(out), nchar(cases[[case]]$input), info = case)
  }
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

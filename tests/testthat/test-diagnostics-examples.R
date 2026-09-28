# Each test here reproduces a rejection a maintainer actually received, so the
# check that answers it cannot quietly stop working.

# Test lab_example_installs() ----

# "Please do not install packages in your functions, examples or vignette."
test_that("lab_example_installs(): reports an install in an example", {
  # Line 7 of f.Rd, where the call is, not line 2 of the code pulled out of it.
  res <- lab_example_installs(rd_pkg("install.packages('somepkg')"), verbose = FALSE)
  expect_equal(res$issues, "example f.Rd:7 (installs software)")
})

test_that("lab_example_installs(): reports an install in a vignette", {
  pkg <- script_pkg(
    c("---", "title: v", "---", "", "```{r}", "remotes::install_github('a/b')", "```"),
    "vignettes", "v.Rmd"
  )
  expect_equal(
    lab_example_installs(pkg, verbose = FALSE)$issues,
    "vignette v.Rmd:6 (installs software)"
  )
})

test_that("lab_example_installs(): an Rd comment does not hide the example", {
  # An Rd `%` comment is not R, and R drops it before running the example. Kept,
  # it stopped the whole example parsing, and one that does not parse was skipped
  # unread. The call in the comment itself is not code.
  pkg <- rd_pkg(c(
    "% the old way: install.packages('oldpkg')",
    "install.packages('somepkg') % the new way"
  ))
  expect_equal(
    lab_example_installs(pkg, verbose = FALSE)$issues,
    "example f.Rd:8 (installs software)"
  )
})

test_that("lab_example_installs(): a dontrun block that is not R hides nothing else", {
  # A placeholder such as `<your API key>` stops the block parsing. The rest of the
  # example, and the lines of the block that are R, are still read.
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "my_fn(<your API key>)",
    "install.packages('inblock')",
    "}",
    "install.packages('after')"
  ))
  expect_equal(
    lab_example_installs(pkg, verbose = FALSE)$issues,
    c("example f.Rd:9 (installs software)", "example f.Rd:11 (installs software)")
  )
})

test_that("lab_example_installs(): reads a block inside a broken block", {
  # The outer block is cut down to the lines that parse, and the inner block's
  # body is on lines of its own, so the call it is an argument of parses over
  # three lines. Read as one line, it did not parse and was blanked.
  pkg <- rd_pkg(c(
    "\\donttest{",
    "key <- <your key>",
    "suppressWarnings(\\dontrun{install.packages('x')})",
    "}"
  ))
  expect_equal(
    lab_example_installs(pkg, verbose = FALSE)$issues,
    "example f.Rd:9 (installs software)"
  )
})

test_that("lab_example_installs(): reads a hidden block that is not a whole statement", {
  # A block's body is read on lines of its own, as Rd2ex lays out a block it
  # runs, so R reads it as the argument or branch it sits in. Ending each block
  # with `;` made every one of these a syntax error, and the whole example went
  # unread.
  cases <- c(
    "suppressWarnings(\\donttest{install.packages('x')})",
    "r <- tryCatch(\\donttest{install.packages('x')}, error = function(e) NULL)",
    "if (FALSE) \\dontrun{install.packages('x')} else install.packages('y')",
    "\\dontrun{ install.packages('x'); }",
    "\\dontrun{f() # a note}\\donttest{install.packages('x')}"
  )
  for (case in cases) {
    expect_equal(
      lab_example_installs(rd_pkg(case), verbose = FALSE)$issues,
      "example f.Rd:7 (installs software)",
      label = case
    )
  }
})

test_that("lab_example_installs(): reads the code after a block that ends in ;", {
  cases <- list(
    c("\\dontrun{f();}", "install.packages('x')"),
    c("\\donttest{\\dontrun{f()}}", "install.packages('x')"),
    c("\\dontrun{f();}\\donttest{g();}", "install.packages('x')")
  )
  for (case in cases) {
    expect_equal(
      lab_example_installs(rd_pkg(case), verbose = FALSE)$issues,
      "example f.Rd:8 (installs software)",
      label = case[[1L]]
    )
  }
})

test_that("lab_example_installs(): reads the code after a block and a ;", {
  # `f(); g()` is two statements on one line. With a break after the block's
  # body the `;` started a line, which does not parse, and the whole example
  # went unread.
  cases <- list(
    list(c("\\dontrun{f()}; g()", "install.packages('x')"), 8L),
    list("\\dontrun{f()}; install.packages('x')", 7L),
    list("\\donttest{f()} ; install.packages('x')", 7L)
  )
  for (case in cases) {
    expect_equal(
      lab_example_installs(rd_pkg(case[[1L]]), verbose = FALSE)$issues,
      sprintf("example f.Rd:%d (installs software)", case[[2L]]),
      label = case[[1L]][[1L]]
    )
  }
})

test_that("lab_example_installs(): reads a dontdiff block as code", {
  # \dontdiff{} code runs; only its output is left out of the comparison with
  # the saved output. Run together, the two bodies read `f()install.packages()`.
  pkg <- rd_pkg("\\dontdiff{f()}\\dontdiff{install.packages('x')}")
  expect_equal(
    lab_example_installs(pkg, verbose = FALSE)$issues,
    "example f.Rd:7 (installs software)"
  )
})

test_that("lab_example_installs(): honours a Quarto eval: false chunk option", {
  # Quarto sets chunk options in `#|` comments rather than in the chunk header.
  pkg <- script_pkg(
    c(
      "---", "title: v", "---", "",
      "```{r}", "#| eval: false", "install.packages('shown')", "```", "",
      "```{r}", "#| echo: false", "install.packages('run')", "```"
    ),
    "vignettes", "v.qmd"
  )
  expect_equal(
    lab_example_installs(pkg, verbose = FALSE)$issues,
    "vignette v.qmd:12 (installs software)"
  )
})

test_that("lab_example_installs(): reads a Sweave vignette", {
  pkg <- script_pkg(
    c(
      "\\documentclass{article}", "\\begin{document}",
      "<<setup>>=", "install.packages('run')", "@",
      "<<shown, eval=FALSE>>=", "install.packages('shown')", "@",
      "\\end{document}"
    ),
    "vignettes", "v.Rnw"
  )
  expect_equal(
    lab_example_installs(pkg, verbose = FALSE)$issues,
    "vignette v.Rnw:4 (installs software)"
  )
})

test_that("lab_example_installs(): a conditional use is not an install", {
  pkg <- rd_pkg("if (requireNamespace('pkg', quietly = TRUE)) pkg::fn()")
  expect_true(lab_example_installs(pkg, verbose = FALSE)$passed)
})

# Test lab_example_writes() ----

# "Please ensure that your functions do not write by default or in your
# examples/vignettes/tests in the user's home filespace"
test_that("lab_example_writes(): reports a write to a literal path", {
  pkg <- rd_pkg("writeLines('x', 'out.txt')")
  res <- lab_example_writes(pkg, verbose = FALSE)
  expect_equal(res$issues, "example f.Rd:7 (writeLines())")
  # A write in a hidden block is read too, even as a call's argument.
  hidden <- rd_pkg("suppressMessages(\\donttest{writeLines('x', 'out.txt')})")
  expect_equal(
    lab_example_writes(hidden, verbose = FALSE)$issues,
    "example f.Rd:7 (writeLines())"
  )
})

test_that("lab_example_writes(): accepts a write into tempdir", {
  expect_true(lab_example_writes(rd_pkg("writeLines('x', tempfile())"),
                                 verbose = FALSE)$passed)
  expect_true(lab_example_writes(
    rd_pkg("write.csv(iris, file.path(tempdir(), 'o.csv'))"),
    verbose = FALSE
  )$passed)
})

test_that("lab_example_writes(): finds the destination behind a pipe or a named argument", {
  # A demo, so magrittr's `%` needs no Rd escape. The last two write where
  # tempfile() says.
  pkg <- script_pkg(
    c(
      "mtcars |> write.csv('mtcars.csv')",
      "mtcars %>% write.csv(row.names = FALSE, 'cars.csv')",
      "writeLines(sep = '', x, 'out.txt')",
      "file.copy(to = 'copy.txt', from = x)",
      "mtcars |> write.csv(tempfile())",
      "file.copy(from = 'a.txt', tempfile())"
    ),
    "demo", "d.R"
  )
  expect_identical(
    lab_example_writes(pkg, verbose = FALSE)$issues,
    c(
      "demo d.R:1 (write.csv())", "demo d.R:2 (write.csv())",
      "demo d.R:3 (writeLines())", "demo d.R:4 (file.copy())"
    )
  )
})

test_that("lab_example_writes(): knows the tidyverse and common writers", {
  # The three write-related checks each carried their own list, so one knew about
  # a function the others did not. They share WRITE_FUNCTIONS now.
  for (fn in c("write_csv", "write_rds", "write_tsv", "fwrite", "write_xlsx",
               "write_json", "write_parquet", "ggsave", "writeBin")) {
    expect_true(fn %in% WRITE_FUNCTIONS, info = fn)
    expect_false(is.null(WRITE_DEST_ARG[[fn]]), info = fn)
    # NA is a legitimate entry -- it means "named argument only", as in
    # `save(x, file = )` -- but it makes write_destination() return NULL for a
    # positional call, so an NA here would silently unjudge the function. These
    # writers all take their destination positionally.
    expect_false(is.na(WRITE_DEST_ARG[[fn]]), info = fn)
  }

  pkg <- rd_pkg("write_csv(x, 'out.csv')")
  expect_equal(
    lab_example_writes(pkg, verbose = FALSE)$issues,
    "example f.Rd:7 (write_csv())"
  )

  safe <- rd_pkg("write_csv(x, tempfile())")
  expect_true(lab_example_writes(safe, verbose = FALSE)$passed)
})

# Test lab_example_tf_usage() ----

# "Please write TRUE and FALSE instead of T and F. 'T' and 'F' instead of TRUE and
# FALSE: man/quiet.Rd: quiet(x, be_quiet = T)"
test_that("lab_example_tf_usage(): reports T in an example on its .Rd line", {
  res <- lab_example_tf_usage(rd_pkg("quiet(x, be_quiet = T)"), verbose = FALSE)
  expect_equal(res$issues, "example f.Rd:7")
  # \dontrun{} code is read as well: a reader copies it.
  pkg <- rd_pkg(c("\\dontrun{", "f(verbose = T)", "}"))
  expect_equal(lab_example_tf_usage(pkg, verbose = FALSE)$issues, "example f.Rd:8")
})

test_that("lab_example_tf_usage(): reports F in a vignette chunk on its line", {
  pkg <- script_pkg(
    c("---", "title: v", "---", "", "```{r}", "knitr::opts_chunk$set(echo = F)", "```"),
    "vignettes", "v.Rmd"
  )
  expect_equal(lab_example_tf_usage(pkg, verbose = FALSE)$issues, "vignette v.Rmd:6")
})

test_that("lab_example_tf_usage(): reports T in a demo", {
  pkg <- script_pkg(c("x <- 1", "y <- T"), "demo", "d.R")
  expect_equal(lab_example_tf_usage(pkg, verbose = FALSE)$issues, "demo d.R:2")
})

test_that("lab_example_tf_usage(): leaves tests out unless asked", {
  # Tests are where most hits are, and CRAN rarely reads them.
  pkg <- script_pkg("expect_true(T)", file.path("tests", "testthat"), "test-a.R")
  expect_true(lab_example_tf_usage(pkg, verbose = FALSE)$passed)
  expect_equal(
    lab_example_tf_usage(pkg, verbose = FALSE, tests = TRUE)$issues,
    "test test-a.R:1"
  )
})

test_that("lab_example_tf_usage(): judges T as lab_tf_usage() does", {
  # The same exemptions: a string, a comment, an argument name, `x$T` and
  # language built by quote() are not the logical.
  pkg <- rd_pkg(c(
    "x <- \"T\" # T",
    "f(T = 1)",
    "d$T",
    "quote(F[a] - F[b])",
    "g(TRUE, FALSE)"
  ))
  expect_true(lab_example_tf_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_tf_usage(): passes a package with no examples", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_example_tf_usage(pkg, verbose = FALSE)$passed)
})

# Test lab_example_unparseable() ----

# "Warning: Unexecutable code in man/make.trait.model.Rd"
test_that("lab_example_unparseable(): reports an unfinished example at its last line", {
  # The parser stops past the last line, so the report names the last line with
  # code in it.
  cases <- list(
    missing_paren = c("x <- 1", "plot(x, main = 'a'"),
    open_call = c("f(1,", "  2")
  )
  for (case in names(cases)) {
    res <- lab_example_unparseable(rd_pkg(cases[[case]]), verbose = FALSE)
    expect_false(res$passed, info = case)
    expect_identical(length(res$issues), 1L, info = case)
    expect_match(res$issues, "^example f\\.Rd:8 \\(", info = case)
  }
})

test_that("lab_example_unparseable(): reads inside dontrun, which R CMD check does not", {
  # The other example checks read the parts of a broken block that parse, so an
  # install beside a placeholder is still seen. That repair must not make the
  # example itself count as R: this check reads it unrepaired. Read repaired,
  # `x <- 1` and a blanked block would parse and nothing would be reported.
  pkg <- rd_pkg(c("x <- 1", "\\dontrun{", "my_fn(<your API key>)", "}"))
  res <- lab_example_unparseable(pkg, verbose = FALSE)
  expect_match(res$issues, "^example f\\.Rd:9 \\(unexpected '<'\\)$")
})

test_that("lab_example_unparseable(): an Rd comment is not code", {
  pkg <- rd_pkg(c("% this is <not R>", "x <- 1 % nor <this>", "f(x)"))
  expect_true(lab_example_unparseable(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_unparseable(): passes blocks that are R, on a line or across", {
  pkg <- rd_pkg(c(
    "\\dontrun{f()}\\donttest{g()}",
    "suppressWarnings(\\donttest{h()})",
    "\\dontrun{a()}; b()",
    "if (TRUE) {",
    "  1",
    "} else 2",
    "x <- '100\\%'"
  ))
  expect_true(lab_example_unparseable(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_unparseable(): passes a package with no examples", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_example_unparseable(pkg, verbose = FALSE)$passed)
})

# Test lab_example_internal_ns() ----

# "Used ::: in documentation: man/paint_format.Rd: paintr:::paint_format(...)"
test_that("lab_example_internal_ns(): reports a triple colon in an example", {
  pkg <- rd_pkg("t:::internal_fn(1)")
  res <- lab_example_internal_ns(pkg, verbose = FALSE)
  expect_equal(res$issues, "example f.Rd:7 (uses :::)")
})

test_that("lab_example_internal_ns(): accepts a double colon in an example", {
  expect_true(lab_example_internal_ns(rd_pkg("stats::median(1:3)"),
                                      verbose = FALSE)$passed)
})

test_that("lab_example_internal_ns(): skips an .Rbuildignore'd .Rd", {
  # {devtag}'s @dev tag documents an unexported function and adds the .Rd to
  # .Rbuildignore, so the topic never reaches CRAN. Reading it anyway told a
  # maintainer to remove a ::: from a file no reviewer will ever see.
  pkg <- rd_pkg("t:::internal_fn(1)")
  writeLines("^man/f\\.Rd$", file.path(pkg, ".Rbuildignore"))
  expect_true(lab_example_internal_ns(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_internal_ns(): reads an .Rd the tarball keeps", {
  # The guard against over-filtering: an unrelated .Rbuildignore entry must not
  # take the rest of man/ with it.
  pkg <- rd_pkg("t:::internal_fn(1)")
  writeLines("^docs$", file.path(pkg, ".Rbuildignore"))
  expect_false(lab_example_internal_ns(pkg, verbose = FALSE)$passed)
})

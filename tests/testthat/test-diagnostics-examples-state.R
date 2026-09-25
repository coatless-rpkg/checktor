# Test lab_example_state() ----

# "Please always make sure to reset to user's options(), working directory or par()
# after you changed it in examples and vignettes and demos" -> in your inst/demo folder
test_that("lab_example_state(): reports state never restored in a demo", {
  pkg <- script_pkg(c("options(digits = 3)", "plot(1:10)"), file.path("inst", "demo"), "d.R")
  expect_identical(
    lab_example_state(pkg, verbose = FALSE)$issues,
    "demo d.R:1 (never restored)"
  )
})

test_that("lab_example_state(): reports a setwd() never put back", {
  # setwd() takes a bare path, so unlike options() and par() it needs no named
  # argument to count as a change.
  pkg <- script_pkg(c("setwd(tempdir())", "plot(1)"), file.path("inst", "demo"), "d.R")
  expect_identical(
    lab_example_state(pkg, verbose = FALSE)$issues,
    "demo d.R:1 (never restored)"
  )
})

test_that("lab_example_state(): points at the vignette line that changes state", {
  pkg <- script_pkg(
    c(
      "---", "title: v", "---", "", "Some prose.", "",
      "```{r}", "x <- 1", "options(digits = 3)", "```"
    ),
    "vignettes", "v.Rmd"
  )
  expect_equal(
    lab_example_state(pkg, verbose = FALSE)$issues,
    "vignette v.Rmd:9 (never restored)"
  )
})

test_that("lab_example_state(): accepts state captured and put back", {
  pkg <- script_pkg(
    c("old <- options(digits = 3)", "plot(1:10)", "options(old)"),
    file.path("inst", "demo"), "d.R"
  )
  expect_identical(lab_example_state(pkg, verbose = FALSE)$issues, character(0))

  par_pkg <- script_pkg(
    c("oldpar <- par(mfrow = c(1, 2))", "plot(1:10)", "par(oldpar)"),
    file.path("inst", "demo"), "d.R"
  )
  expect_identical(lab_example_state(par_pkg, verbose = FALSE)$issues, character(0))

  # `=` is an assignment too, though it does not parse as an `expr` node.
  eq_pkg <- script_pkg(
    c("old = options(digits = 3)", "plot(1:10)", "options(old)"),
    file.path("inst", "demo"), "d.R"
  )
  expect_identical(lab_example_state(eq_pkg, verbose = FALSE)$issues, character(0))
})

test_that("lab_example_state(): accepts a setwd() whose old directory is captured", {
  # setwd() returns the directory it leaves, so `old <- setwd(tempdir())` is the
  # capture and `setwd(old)` the restore, as `old <- options(...)` and
  # `options(old)` are. Both lines of this shape were reported as never restored.
  for (capture in c("old <- setwd(tempdir())", "old = setwd(tempdir())")) {
    pkg <- script_pkg(
      c(capture, "plot(1)", "setwd(old)"),
      file.path("inst", "demo"), "d.R"
    )
    expect_identical(
      lab_example_state(pkg, verbose = FALSE)$issues,
      character(0),
      info = capture
    )
  }

  # The same pair in an Rd example, hidden from the reader in \dontshow{}.
  rd <- rd_pkg(c(
    "\\dontshow{old <- setwd(tempdir())}",
    "plot(1)",
    "\\dontshow{setwd(old)}"
  ))
  expect_identical(lab_example_state(rd, verbose = FALSE)$issues, character(0))

  # And across a vignette's chunks, which are read as one script.
  vig <- script_pkg(
    c(
      "---", "title: v", "---", "",
      "```{r}", "old <- setwd(tempdir())", "```", "",
      "```{r}", "plot(1)", "setwd(old)", "```"
    ),
    "vignettes", "v.Rmd"
  )
  expect_identical(lab_example_state(vig, verbose = FALSE)$issues, character(0))
})

test_that("lab_example_state(): accepts the other ways state is captured and put back", {
  # knitr's rocco.Rd restores in on.exit(), data.table's froll.Rd captures with
  # `=` into a dotted name, and the rest capture the old state before changing it.
  shapes <- list(
    c("f <- function() {", "  owd = setwd(tempdir())", "  on.exit(setwd(owd))", "}"),
    c(".op = options(datatable.verbose = TRUE)", "plot(1)", "options(.op)"),
    c("op <- par(no.readonly = TRUE)", "par(mfrow = c(1, 2))", "par(op)"),
    c("owd <- getwd()", "setwd(tempdir())", "setwd(owd)"),
    c("setwd(tempdir()) -> old", "plot(1)", "setwd(old)"),
    # One setting read out and handed back by name, as simBKMRdata's vignette does.
    c("old <- par()[['mfrow']]", "par(mfrow = c(2, 1))", "par(mfrow = old)"),
    c("old <- getOption('digits')", "options(digits = 3)", "options(scipen = 0, digits = old)")
  )
  for (lines in shapes) {
    pkg <- script_pkg(lines, file.path("inst", "demo"), "d.R")
    expect_identical(
      lab_example_state(pkg, verbose = FALSE)$issues,
      character(0),
      info = paste(lines, collapse = "; ")
    )
  }
})

test_that("lab_example_state(): a capture never handed back is not a restore", {
  # `old <- setwd(tempdir())` keeps the way back but never takes it, which is the
  # shape CRAN sends back. The value has to reach options(), par() or setwd().
  shapes <- list(
    list(c("old <- setwd(tempdir())", "plot(1)"), "demo d.R:1 (never restored)"),
    list(c("old = setwd(tempdir())", "plot(1)"), "demo d.R:1 (never restored)"),
    list(c("owd <- getwd()", "setwd(tempdir())"), "demo d.R:2 (never restored)"),
    list(c("old <- options(digits = 3)", "plot(1)"), "demo d.R:1 (never restored)"),
    list(
      c("old <- options(digits = 3)", "x <- 1", "options(x)"),
      "demo d.R:1 (never restored)"
    )
  )
  for (shape in shapes) {
    pkg <- script_pkg(shape[[1]], file.path("inst", "demo"), "d.R")
    expect_identical(
      lab_example_state(pkg, verbose = FALSE)$issues,
      shape[[2]],
      info = paste(shape[[1]], collapse = "; ")
    )
  }
})

test_that("lab_example_state(): a capture is an assignment OF the state call", {
  # A helper that calls setwd() is assigned a function, and a tryCatch() result
  # is whatever tryCatch() returns: neither holds the old state, so neither may
  # excuse the change in the file.
  helper <- script_pkg(
    c("go <- function(d) setwd(d)", "go(tempdir())"),
    file.path("inst", "demo"), "d.R"
  )
  expect_identical(
    lab_example_state(helper, verbose = FALSE)$issues,
    "demo d.R:1 (never restored)"
  )

  wrapped <- script_pkg(
    c("res <- tryCatch(setwd('/nope'), error = function(e) NULL)", "options(digits = 3)"),
    file.path("inst", "demo"), "d.R"
  )
  expect_identical(
    lab_example_state(wrapped, verbose = FALSE)$issues,
    c("demo d.R:1 (never restored)", "demo d.R:2 (never restored)")
  )

  # basename() of the old directory is not the old directory, so handing it back
  # to setwd() goes somewhere else.
  derived <- script_pkg(
    c("wd <- basename(setwd(tempdir()))", "setwd(wd)"),
    file.path("inst", "demo"), "d.R"
  )
  expect_identical(
    lab_example_state(derived, verbose = FALSE)$issues,
    c("demo d.R:1 (never restored)", "demo d.R:2 (never restored)")
  )
})

test_that("lab_example_state(): an unrelated assignment is not a restore", {
  # A restore needs an assignment that CAPTURES options(), par() or the working
  # directory. This one assigns something else and changes state anyway.
  pkg <- script_pkg(
    c("x <- 1", "options(digits = 3)", "plot(x)"),
    file.path("inst", "demo"), "d.R"
  )
  expect_identical(
    lab_example_state(pkg, verbose = FALSE)$issues,
    "demo d.R:2 (never restored)"
  )
})

test_that("lab_example_state(): reading options or par is not a change", {
  # par(no.readonly = TRUE) names an argument, but it asks for the settings and
  # changes none of them. Kept in `op` and never handed back, it has nothing to
  # put back, so it is not reported.
  pkg <- script_pkg(
    c(
      "plot(1:10, ylim = par('usr')[3:4])",
      "options('digits')",
      "op <- par(no.readonly = TRUE)",
      "par(no.readonly = TRUE)",
      "mf <- par('mfrow', no.readonly = TRUE)"
    ),
    file.path("inst", "demo"), "d.R"
  )
  expect_identical(lab_example_state(pkg, verbose = FALSE)$issues, character(0))

  # Another named argument beside it still changes that setting.
  set <- script_pkg(
    c("op <- par(no.readonly = TRUE, mfrow = c(1, 2))", "plot(1)"),
    file.path("inst", "demo"), "d.R"
  )
  expect_identical(
    lab_example_state(set, verbose = FALSE)$issues,
    "demo d.R:1 (never restored)"
  )
})

test_that("lab_example_state(): an on.exit() outside a function restores nothing", {
  # At top level on.exit() has no function to exit. R CMD check runs examples and
  # demos as a script, where it never fires, and knitr runs it straight after its
  # own line, before the change it was meant to undo. shiny.webawesome's vignette
  # registers its restore this way.
  demo <- script_pkg(
    c("old <- setwd(tempdir())", "on.exit(setwd(old))", "plot(1)"),
    file.path("inst", "demo"), "d.R"
  )
  expect_identical(
    lab_example_state(demo, verbose = FALSE)$issues,
    c("demo d.R:1 (never restored)", "demo d.R:2 (never restored)")
  )

  rd <- rd_pkg(c("old <- setwd(tempdir())", "on.exit(setwd(old))", "plot(1)"))
  expect_identical(
    lab_example_state(rd, verbose = FALSE)$issues,
    c("example f.Rd:7 (never restored)", "example f.Rd:8 (never restored)")
  )

  vig <- script_pkg(
    c(
      "---", "title: v", "---", "",
      "```{r}",
      "old <- getOption('digits')",
      "on.exit(options(digits = old), add = TRUE)",
      "options(digits = 3)",
      "```"
    ),
    "vignettes", "v.Rmd"
  )
  expect_identical(
    lab_example_state(vig, verbose = FALSE)$issues,
    c("vignette v.Rmd:7 (never restored)", "vignette v.Rmd:8 (never restored)")
  )

  # In a function, a lambda or local(), on.exit() runs when that code is done.
  shapes <- list(
    c("f <- function() {", "  old <- setwd(tempdir())", "  on.exit(setwd(old))", "}"),
    c("g <- \\(d) {", "  op <- par(mfrow = c(1, 2))", "  on.exit(par(op))", "}"),
    c("local({", "  old <- options(digits = 3)", "  on.exit(options(old))", "  plot(1)", "})")
  )
  for (lines in shapes) {
    pkg <- script_pkg(lines, file.path("inst", "demo"), "d.R")
    expect_identical(
      lab_example_state(pkg, verbose = FALSE)$issues,
      character(0),
      info = paste(lines, collapse = "; ")
    )
  }
})

test_that("lab_example_state(): an on.exit() in with(), within(), eval() or evalq() restores", {
  # Each evaluates its code in a call of its own, and on.exit() fires when that
  # call returns, exactly as in local().
  shapes <- c(
    "with(list(), { old <- options(digits = 3); on.exit(options(old)); plot(1) })",
    "d <- within(data.frame(a = 1), { op <- par(mfrow = c(1, 2)); on.exit(par(op)) })",
    "base::evalq({ old <- setwd(tempdir()); on.exit(setwd(old)) })",
    "eval(quote({ old <- options(digits = 3); on.exit(options(old)) }))"
  )
  for (line in shapes) {
    expect_identical(
      lab_example_state(rd_pkg(line), verbose = FALSE)$issues,
      character(0),
      info = line
    )
  }

  # A wrapper that evaluates its argument as a promise has no exit of its own.
  pkg <- rd_pkg(
    "suppressWarnings({ old <- options(digits = 3); on.exit(options(old)) })"
  )
  expect_identical(
    lab_example_state(pkg, verbose = FALSE)$issues,
    "example f.Rd:7 (never restored)"
  )
})

test_that("lab_example_state(): sees state captured or put back through a wrapper, pipe or do.call()", {
  # suppressWarnings() and invisible() return the value they wrap, and a pipe
  # returns what its right-hand call does, so each of these holds the old state.
  # do.call() and a pipe hand it back as surely as calling the setter with it.
  shapes <- list(
    c("oldpar <- suppressWarnings(par(no.readonly = TRUE))", "par(mfrow = c(1, 2))", "par(oldpar)"),
    c("old <- invisible(options(digits = 3))", "plot(1)", "options(old)"),
    c("old <- tempdir() |> setwd()", "plot(1)", "setwd(old)"),
    c("old <- tempdir() %>% setwd()", "plot(1)", "setwd(old)"),
    c("op <- par(no.readonly = TRUE) |> suppressWarnings()", "par(mfrow = c(1, 2))", "par(op)"),
    c("op <- par(mfrow = c(1, 2))", "plot(1)", "do.call(par, op)"),
    c("op <- par(mfrow = c(1, 2))", "plot(1)", "do.call('par', op)"),
    c("old <- setwd(tempdir())", "plot(1)", "old |> setwd()"),
    c("op <- par(mfrow = c(1, 2))", "plot(1)", "op %>% par()")
  )
  for (lines in shapes) {
    pkg <- script_pkg(lines, file.path("inst", "demo"), "d.R")
    expect_identical(
      lab_example_state(pkg, verbose = FALSE)$issues,
      character(0),
      info = paste(lines, collapse = "; ")
    )
  }
})

test_that("lab_example_state(): a restore puts back only the kind of state it captured", {
  # An old directory handed to options() restores nothing, and par() put back
  # leaves the directory changed. Each kind of state changed needs its own
  # restore.
  shapes <- list(
    list(c("old <- setwd(tempdir())", "plot(1)", "options(old)"), "demo d.R:1 (never restored)"),
    list(c("old <- options(digits = 3)", "plot(1)", "par(old)"), "demo d.R:1 (never restored)"),
    list(
      c("op <- par(no.readonly = TRUE)", "options(digits = 3)", "par(op)"),
      "demo d.R:2 (never restored)"
    ),
    list(
      c("op <- par(mfrow = c(1, 2))", "par(op)", "setwd(tempdir())"),
      "demo d.R:3 (never restored)"
    )
  )
  for (shape in shapes) {
    pkg <- script_pkg(shape[[1]], file.path("inst", "demo"), "d.R")
    expect_identical(
      lab_example_state(pkg, verbose = FALSE)$issues,
      shape[[2]],
      info = paste(shape[[1]], collapse = "; ")
    )
  }

  every <- script_pkg(
    c(
      "op <- par(mfrow = c(1, 2))", "owd <- setwd(tempdir())",
      "old <- options(digits = 3)", "plot(1)",
      "options(old)", "setwd(owd)", "par(op)"
    ),
    file.path("inst", "demo"), "d.R"
  )
  expect_identical(lab_example_state(every, verbose = FALSE)$issues, character(0))
})

test_that("lab_example_state(): reads a hidden block that ends in ;", {
  pkg <- rd_pkg("\\dontrun{options(digits = 3);}")
  expect_equal(
    lab_example_state(pkg, verbose = FALSE)$issues,
    "example f.Rd:7 (never restored)"
  )
})

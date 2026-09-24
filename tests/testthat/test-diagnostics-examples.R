# Each test here reproduces a rejection a maintainer actually received, so the
# check that answers it cannot quietly stop working.

# Test lab_example_interactive() ----

# "Functions which are supposed to only run interactively (e.g. shiny) should be
# wrapped in if(interactive()). Please replace \dontrun{} with if(interactive()){}"
test_that("lab_example_interactive(): reports an interactive call in dontrun", {
  pkg <- rd_pkg(c("\\dontrun{", "  run_electron_app(app)", "}"))
  expect_equal(
    lab_example_interactive(pkg, verbose = FALSE)$issues,
    "f.Rd: run_electron_app() is hidden in \\dontrun{}"
  )
})

test_that("lab_example_interactive(): accepts an interactive() guard", {
  pkg <- rd_pkg("if (interactive()) { runApp(app) }")
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): accepts dontrun AROUND a guard", {
  # The test above has no \dontrun{} at all, so it never gets past the "nothing is
  # hidden" guard and never reaches the interactive() exemption. This shape does:
  # something IS hidden, and it is an interactive call, and the author has already
  # written the guard CRAN asks for. Belt and braces, not a finding.
  pkg <- rd_pkg(c("\\dontrun{", "  if (interactive()) runApp(app)", "}"))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): a guard outside dontrun is no excuse", {
  # The exemption used to be read against the whole \examples{} block, so an
  # unrelated guard anywhere in it waved through the hidden call. Worse, the
  # hidden text was derived by subtracting the runnable text from the whole
  # section, which matches nothing as soon as anything follows the block, so
  # "hidden" was frequently the entire section.
  pkg <- rd_pkg(c("if (interactive()) safe_thing()", "\\dontrun{ runApp(app) }"))
  expect_equal(
    lab_example_interactive(pkg, verbose = FALSE)$issues,
    "f.Rd: runApp() is hidden in \\dontrun{}"
  )
})

test_that("lab_example_interactive(): prints its finding and treatment", {
  # The treatment's `{ ... }` reached cli as an expression, so every package this
  # check caught was reported as an errored check instead (#19).
  pkg <- rd_pkg(c("\\dontrun{", "  runApp(app)", "}"))
  out <- NULL
  expect_no_error(out <- cli::cli_fmt(lab_example_interactive(pkg)))
  out <- gsub("\\s+", " ", paste(out, collapse = " ")) # undo cli's wrapping
  expect_match(out, "f.Rd: runApp() is hidden in \\dontrun{}", fixed = TRUE)
  expect_match(
    out,
    "Guard the call with `if (interactive()) { ... }`",
    fixed = TRUE
  )
  expect_match(out, "in place of `\\dontrun{}`", fixed = TRUE)
  expect_match(out, "runs `\\donttest{}` code", fixed = TRUE)
})

test_that("lab_example_interactive(): leaves a non-interactive dontrun alone", {
  pkg <- rd_pkg(c("\\dontrun{", "  long_running_fit(data)", "}"))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): ignores a call named in a comment (#19)", {
  # The reporter's example: the only interactive name is in a comment telling the
  # reader what to try next. Nothing in the block calls it.
  pkg <- rd_pkg(c(
    "\\donttest{",
    "# For more structured information call `View(iris)`",
    "four()",
    "}"
  ))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): ignores a call named in a string", {
  pkg <- rd_pkg(c("\\dontrun{", "message(\"Use View(x) to inspect\")", "}"))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): ignores a call named in an Rd comment", {
  # An Rd `%` comment never reaches the example R runs.
  pkg <- rd_pkg(c("\\dontrun{", "% runApp(app) was the old way", "f()", "}"))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): matches whole names, not fragments", {
  # Each of these contains an interactive name, or used to match the pattern
  # that stood for one, without calling it.
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "relaunch_job(id = 1)",
    "f(launch_date = '2020-01-01', launch.browser = FALSE)",
    "m <- leaflet::setView(map, 0, 0, zoom = 2)",
    "add_context_menu(x)",
    "electronegativity('O')",
    "readlines_from(con)",
    "}"
  ))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): a method of the same name is not the call", {
  pkg <- rd_pkg(c("\\dontrun{", "app$runApp()", "obj$View()", "}"))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): recognises a launcher by its name", {
  pkg <- rd_pkg(c("\\dontrun{", "launch_app()", "runShinyApp(dir)", "}"))
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "launch_app()", all = FALSE, fixed = TRUE)
  expect_match(res$issues, "runShinyApp()", all = FALSE, fixed = TRUE)
})

test_that("lab_example_interactive(): a guard in a comment or string is no excuse", {
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "# needs an interactive() session",
    "message('not interactive()-safe')",
    "shiny::runApp(app)",
    "}"
  ))
  expect_false(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): a negated guard is no excuse", {
  # Under R CMD check the stop() fires, so the example errors either way.
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "if (!interactive()) stop('run me at the console')",
    "shiny::runApp(app)",
    "}"
  ))
  expect_equal(
    lab_example_interactive(pkg, verbose = FALSE)$issues,
    "f.Rd: runApp() is hidden in \\dontrun{}"
  )
})

test_that("lab_example_interactive(): a guard around one call excuses only it", {
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "if (interactive()) utils::View(df)",
    "shiny::runApp(app)",
    "}"
  ))
  expect_equal(
    lab_example_interactive(pkg, verbose = FALSE)$issues,
    "f.Rd: runApp() is hidden in \\dontrun{}"
  )
})

test_that("lab_example_interactive(): the else branch is not guarded", {
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "if (interactive()) print(1) else shiny::runApp(app)",
    "}"
  ))
  expect_equal(
    lab_example_interactive(pkg, verbose = FALSE)$issues,
    "f.Rd: runApp() is hidden in \\dontrun{}"
  )
})

test_that("lab_example_interactive(): accepts an @examplesIf interactive() guard", {
  # roxygen writes `@examplesIf interactive()` as a \dontshow{} wrapper around the
  # whole example, which guards everything inside it.
  pkg <- rd_pkg(c(
    "\\dontshow{if (interactive()) (if (getRversion() >= \"3.4\") withAutoprint else force)(\\{ # examplesIf}",
    "\\dontrun{",
    "shiny::runApp(app)",
    "}",
    "\\dontshow{\\}) # examplesIf}"
  ))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): names \\donttest{} as \\donttest{}", {
  # CRAN's request is about \dontrun{}. Code in \donttest{} is a different
  # problem: R CMD check --as-cran runs it, where the call errors or hangs.
  pkg <- rd_pkg(c("\\donttest{", "shiny::runApp(app)", "}"))
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "\\donttest{}", all = FALSE, fixed = TRUE)
  expect_match(res$issues, "--as-cran", all = FALSE, fixed = TRUE)
  expect_false(any(grepl("dontrun", res$issues, fixed = TRUE)))
})

test_that("lab_example_interactive(): tells adjacent blocks apart", {
  pkg <- rd_pkg("\\dontrun{f()}\\donttest{shiny::runApp(app)}")
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "\\donttest{}", all = FALSE, fixed = TRUE)
  expect_false(any(grepl("dontrun", res$issues, fixed = TRUE)))
})

test_that("lab_example_interactive(): recognises launchers beyond app and gadget", {
  # manureshed's launch_dashboard() wraps shiny::runApp(); shinystan's launcher
  # and a GUI launcher are named for what they open, not for "app".
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "launch_dashboard(port = 3838)",
    "launch_shinystan(fit)",
    "launchGUI()",
    "run_shiny()",
    "}"
  ))
  res <- lab_example_interactive(pkg, verbose = FALSE)
  for (fn in c("launch_dashboard()", "launch_shinystan()", "launchGUI()", "run_shiny()")) {
    expect_match(res$issues, fn, all = FALSE, fixed = TRUE)
  }
})

test_that("lab_example_interactive(): building a shiny app is not running it", {
  # shinyApp() returns an app object, which runs only when it is printed. Assigned
  # or handed to another function, as shiny's own examples do, nothing starts.
  pkg <- rd_pkg(c(
    "\\donttest{",
    "app <- shinyApp(ui, server)",
    "d <- AppDriver$new(shinyApp(ui, server))",
    "}"
  ))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): a shiny app printed at top level runs", {
  pkg <- rd_pkg(c("\\dontrun{", "shinyApp(ui, server)", "}"))
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_match(res$issues, "shinyApp()", all = FALSE, fixed = TRUE)
})

test_that("lab_example_interactive(): reports one launch once", {
  # The app shinyApp() builds here is what runGadget() launches.
  pkg <- rd_pkg(c("\\dontrun{", "runGadget(shinyApp(ui, server))", "}"))
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_length(res$issues, 1L)
  expect_match(res$issues, "runGadget()", fixed = TRUE)
})

test_that("lab_example_interactive(): reads what parses of a block that will not", {
  # shinyjs keeps JavaScript beside the R in one \dontrun{} block. The JavaScript
  # stops the block parsing, which must not hide the app it launches.
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "var params = {",
    "  a: 1",
    "};",
    "shinyApp(ui, server)",
    "}"
  ))
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "shinyApp()", all = FALSE, fixed = TRUE)
})

test_that("lab_example_interactive(): keeps an enclosing guard when a block will not parse", {
  pkg <- rd_pkg(c(
    "\\dontshow{if (interactive()) (if (getRversion() >= \"3.4\") withAutoprint else force)(\\{ # examplesIf}",
    "\\dontrun{",
    "my_fn(<your API key here>)",
    "}",
    "\\dontrun{",
    "shiny::runApp(app)",
    "}",
    "\\dontshow{\\}) # examplesIf}"
  ))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): a guarded `=` assignment is guarded", {
  pkg <- rd_pkg(c("\\dontrun{", "if (interactive()) res = readline('Name? ')", "}"))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): the else of a negated guard is guarded", {
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "if (!interactive()) message('skip') else shiny::runApp(app)",
    "}"
  ))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): the else of a negated conjunction is not guarded", {
  # The else runs whenever either side is false, so `ready()` alone being false
  # runs the app outside a session.
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "if (!interactive() && ready()) message('skip') else shiny::runApp(app)",
    "}"
  ))
  expect_equal(
    lab_example_interactive(pkg, verbose = FALSE)$issues,
    "f.Rd: runApp() is hidden in \\dontrun{}"
  )
})

test_that("lab_example_interactive(): the else of a negated disjunction is guarded", {
  # The else runs only when both sides are false, so only in a session.
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "if (!interactive() || !ready()) message('skip') else shiny::runApp(app)",
    "}"
  ))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): a guard that short-circuits is a guard", {
  # `&&` evaluates its right side only when its left side is true.
  pkg <- rd_pkg(c("\\dontrun{", "interactive() && shiny::runApp(app)", "}"))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): a comment inside a guard leaves it a guard", {
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "if (interactive() && # someone at the keyboard",
    "    ready()) shiny::runApp(app)",
    "}"
  ))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): a condition that is true under R CMD check is no guard", {
  for (guard in c(
    "isFALSE(interactive())",
    "Sys.getenv('CI') == '' || interactive()",
    "session$interactive()"
  )) {
    pkg <- rd_pkg(c("\\dontrun{", paste0("if (", guard, ") shiny::runApp(app)"), "}"))
    expect_false(lab_example_interactive(pkg, verbose = FALSE)$passed, label = guard)
  }
})

test_that("lab_example_interactive(): reads each block when the whole will not", {
  # A \dontrun{} block may hold something that is not R. That must not hide an
  # interactive call in another block.
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "my_fn(<your API key here>)",
    "}",
    "\\dontrun{",
    "shiny::runApp(app)",
    "}"
  ))
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "runApp()", all = FALSE, fixed = TRUE)
})

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

test_that("lab_example_installs(): names the .Rd line of a call after an #ifdef", {
  pkg <- rd_pkg(c(
    "#ifdef windows", "x <- 1", "#endif", "y <- 2", "install.packages('x')"
  ))
  expect_equal(
    lab_example_installs(pkg, verbose = FALSE)$issues,
    "example f.Rd:11 (installs software)"
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
})

test_that("lab_example_writes(): reads hidden blocks that share a line", {
  # Run together, the two bodies read `f()writeLines(...)`, which does not parse.
  pkg <- rd_pkg("\\dontrun{f()}\\donttest{writeLines('x', 'out.txt')}")
  expect_equal(
    lab_example_writes(pkg, verbose = FALSE)$issues,
    "example f.Rd:7 (writeLines())"
  )
})

test_that("lab_example_writes(): reads a hidden block that is a call's argument", {
  pkg <- rd_pkg("suppressMessages(\\donttest{writeLines('x', 'out.txt')})")
  expect_equal(
    lab_example_writes(pkg, verbose = FALSE)$issues,
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

# Test lab_example_internal_ns() ----

# "Used ::: in documentation: man/paint_format.Rd: paintr:::paint_format(...)"
test_that("lab_example_internal_ns(): reports a triple colon in an example", {
  pkg <- rd_pkg("t:::internal_fn(1)")
  res <- lab_example_internal_ns(pkg, verbose = FALSE)
  expect_equal(res$issues, "example f.Rd:7 (uses :::)")
})

test_that("lab_example_internal_ns(): reads an example that carries an Rd comment", {
  pkg <- rd_pkg(c("% was: t:::old_fn()", "t:::internal_fn(1)"))
  expect_equal(
    lab_example_internal_ns(pkg, verbose = FALSE)$issues,
    "example f.Rd:8 (uses :::)"
  )
})

test_that("lab_example_internal_ns(): reads the code after a block that ends in ;", {
  pkg <- rd_pkg(c("\\dontrun{f();}", "t:::internal_fn(1)"))
  expect_equal(
    lab_example_internal_ns(pkg, verbose = FALSE)$issues,
    "example f.Rd:8 (uses :::)"
  )
})

test_that("lab_example_internal_ns(): reads the code after a block and a ;", {
  pkg <- rd_pkg("\\dontrun{f()} ; t:::g()")
  expect_equal(
    lab_example_internal_ns(pkg, verbose = FALSE)$issues,
    "example f.Rd:7 (uses :::)"
  )
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

# Test rd_example_marked() ----

test_that("rd_example_marked(): leaves out an #ifdef condition, keeping its lines", {
  # `windows` names a platform and is not R: kept, it ran into the code around
  # it, and this example did not parse at all.
  pkg <- rd_pkg(c("x <- c(", "#ifdef windows", "  'a',", "#endif", "  'b')"))
  section <- extract_rd_section(
    tools::parse_Rd(file.path(pkg, "man", "f.Rd")),
    "\\examples"
  )
  for (mark in c(TRUE, FALSE)) {
    expect_equal(
      rd_example_marked(section, mark = mark),
      "\nx <- c(\n\n  'a',\n\n  'b')\n",
      label = paste("mark =", mark)
    )
  }
})

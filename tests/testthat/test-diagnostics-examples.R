# Each test here reproduces a rejection a maintainer actually received, so the
# check that answers it cannot quietly stop working.

# Test lab_example_interactive() ----

# "Functions which are supposed to only run interactively (e.g. shiny) should be
# wrapped in if(interactive()). Please replace \dontrun{} with if(interactive()){}"
test_that("lab_example_interactive(): reports an interactive call in dontrun", {
  pkg <- rd_pkg(c("\\dontrun{", "  run_electron_app(app)", "}"))
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "dontrun", all = FALSE)
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
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "dontrun", all = FALSE)
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
  expect_false(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_interactive(): a guard around one call excuses only it", {
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "if (interactive()) utils::View(df)",
    "shiny::runApp(app)",
    "}"
  ))
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "runApp()", all = FALSE, fixed = TRUE)
  expect_false(any(grepl("View()", res$issues, fixed = TRUE)))
})

test_that("lab_example_interactive(): the else branch is not guarded", {
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "if (interactive()) print(1) else shiny::runApp(app)",
    "}"
  ))
  expect_false(lab_example_interactive(pkg, verbose = FALSE)$passed)
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
test_that("lab_example_installs(): reports an install in example or vignette", {
  pkg <- rd_pkg("install.packages('somepkg')")
  expect_false(lab_example_installs(pkg, verbose = FALSE)$passed)

  vig <- make_temp_dir()
  write_pkg(vig)
  dir.create(file.path(vig, "vignettes"))
  writeLines(
    c("---", "title: v", "---", "", "```{r}", "remotes::install_github('a/b')", "```"),
    file.path(vig, "vignettes", "v.Rmd")
  )
  res <- lab_example_installs(vig, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "vignette", all = FALSE)
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
  expect_false(res$passed)
  expect_match(res$issues, "writeLines", all = FALSE)
})

test_that("lab_example_writes(): accepts a write into tempdir", {
  expect_true(lab_example_writes(rd_pkg("writeLines('x', tempfile())"),
                                 verbose = FALSE)$passed)
  expect_true(lab_example_writes(
    rd_pkg("write.csv(iris, file.path(tempdir(), 'o.csv'))"),
    verbose = FALSE
  )$passed)
})

# Test lab_example_state() ----

# "Please always make sure to reset to user's options(), working directory or par()
# after you changed it in examples and vignettes and demos" -> in your inst/demo folder
test_that("lab_example_state(): reports state never restored in a demo", {
  pkg <- script_pkg(c("options(digits = 3)", "plot(1:10)"), file.path("inst", "demo"), "d.R")
  res <- lab_example_state(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "demo", all = FALSE)
})

test_that("lab_example_state(): accepts state captured and put back", {
  pkg <- script_pkg(
    c("old <- options(digits = 3)", "plot(1:10)", "options(old)"),
    file.path("inst", "demo"), "d.R"
  )
  expect_true(lab_example_state(pkg, verbose = FALSE)$passed)

  par_pkg <- script_pkg(
    c("oldpar <- par(mfrow = c(1, 2))", "plot(1:10)", "par(oldpar)"),
    file.path("inst", "demo"), "d.R"
  )
  expect_true(lab_example_state(par_pkg, verbose = FALSE)$passed)
})

test_that("lab_example_state(): an unrelated assignment is not a restore", {
  # The restore predicate wants an assignment that CAPTURES options()/par()/getwd().
  # Every other must-fail fixture here contains no assignment at all, so a rule
  # that accepted any assignment whatsoever would still pass them. This one assigns
  # and then changes state anyway.
  pkg <- script_pkg(
    c("x <- 1", "options(digits = 3)", "plot(x)"),
    file.path("inst", "demo"), "d.R"
  )
  res <- lab_example_state(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "never restored", all = FALSE, fixed = TRUE)
})

test_that("lab_example_state(): reading options or par is not a change", {
  pkg <- script_pkg(c("u <- par('usr')", "d <- options('digits')"),
                    file.path("inst", "demo"), "d.R")
  expect_true(lab_example_state(pkg, verbose = FALSE)$passed)
})

# Test lab_example_internal_ns() ----

# "Used ::: in documentation: man/paint_format.Rd: paintr:::paint_format(...)"
test_that("lab_example_internal_ns(): reports a triple colon in an example", {
  pkg <- rd_pkg("t:::internal_fn(1)")
  res <- lab_example_internal_ns(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, ":::", all = FALSE, fixed = TRUE)
})

test_that("lab_example_internal_ns(): accepts a double colon in an example", {
  expect_true(lab_example_internal_ns(rd_pkg("stats::median(1:3)"),
                                      verbose = FALSE)$passed)
})

# Test checktor() ----

test_that("checktor(): runs the example checks", {
  pkg <- rd_pkg("install.packages('somepkg')")
  td <- tidy(checktor(pkg, verbose = FALSE, progress = FALSE))
  for (nm in c("example_interactive", "example_installs", "example_writes",
               "example_state", "example_internal_ns")) {
    expect_true(nm %in% td$check, info = nm)
  }
  expect_false(td$passed[td$check == "example_installs"])
})

# Test lab_example_structure() ----

test_that("lab_example_structure(): an install is not a reason for dontrun", {
  # checktor used to accept this shape, which is the one CRAN sent back.
  pkg <- rd_pkg(c("\\dontrun{", "  install_nodejs()", "  run_electron_app()", "}"))
  expect_false(lab_example_structure(pkg, verbose = FALSE)$passed)
})

# Test lab_example_writes() ----

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
  expect_false(lab_example_writes(pkg, verbose = FALSE)$passed)

  safe <- rd_pkg("write_csv(x, tempfile())")
  expect_true(lab_example_writes(safe, verbose = FALSE)$passed)
})

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

# Test lab_unexported_example_ns() ----

test_that("lab_unexported_example_ns(): agrees with the other ::: check", {
  # unexported_example_ns used to tell a maintainer to add ::: to an example,
  # which is the change CRAN asks them to undo.
  #
  # The fixture needs a NAMESPACE and an unexported topic whose example calls it
  # bare, or the check returns before it has anything to say and the assertion
  # below passes on an empty string. And cli hard-wraps the treatment line, so the
  # phrase has to be matched against the joined output, not element by element.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "helper.Rd" = c(
        "\\name{helper}", "\\alias{helper}", "\\title{Helper}",
        "\\description{d}", "\\value{x}", "\\examples{", "helper(1)", "}"
      )
    )
  )
  writeLines("export(test_fn)", file.path(pkg, "NAMESPACE"))

  res <- lab_unexported_example_ns(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "helper", all = FALSE, fixed = TRUE)

  out <- paste(
    cli::cli_fmt(lab_unexported_example_ns(pkg, verbose = TRUE)),
    collapse = " "
  )
  expect_false(grepl("use `pkg:::", out, fixed = TRUE))
  expect_match(out, "Export the object", fixed = TRUE)
})

# Test lab_example_internal_ns() ----

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

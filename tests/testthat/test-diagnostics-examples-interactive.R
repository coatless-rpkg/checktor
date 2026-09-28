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

test_that("lab_example_interactive(): accepts a guard inside dontrun that keeps the call out of R CMD check", {
  cases <- list(
    # "accepts an interactive() guard" has no \dontrun{} at all, so it never gets
    # past the "nothing is hidden" guard and never reaches the interactive()
    # exemption. This shape does: something IS hidden, and it is an interactive
    # call, and the author has already written the guard CRAN asks for. Belt and
    # braces, not a finding.
    around = "  if (interactive()) runApp(app)",
    eq_assignment = "if (interactive()) res = readline('Name? ')",
    else_of_negated = "if (!interactive()) message('skip') else shiny::runApp(app)",
    # The else runs only when both sides are false, so only in a session.
    else_of_negated_disjunction =
      "if (!interactive() || !ready()) message('skip') else shiny::runApp(app)",
    # `&&` evaluates its right side only when its left side is true.
    short_circuit = "interactive() && shiny::runApp(app)",
    comment_inside = c(
      "if (interactive() && # someone at the keyboard",
      "    ready()) shiny::runApp(app)"
    )
  )
  for (case in names(cases)) {
    pkg <- rd_pkg(c("\\dontrun{", cases[[case]], "}"))
    expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed, label = case)
  }
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
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "launch_app()",
    "runShinyApp(dir)",
    # manureshed's launch_dashboard() wraps shiny::runApp(); shinystan's launcher
    # and a GUI launcher are named for what they open, not for "app".
    "launch_dashboard(port = 3838)",
    "launch_shinystan(fit)",
    "launchGUI()",
    "run_shiny()",
    "}"
  ))
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_false(res$passed)
  for (fn in c("launch_app()", "runShinyApp()", "launch_dashboard()",
               "launch_shinystan()", "launchGUI()", "run_shiny()")) {
    expect_match(res$issues, fn, all = FALSE, fixed = TRUE, label = fn)
  }
})

test_that("lab_example_interactive(): a guard that does not keep the call out of R CMD check is no excuse", {
  cases <- list(
    in_comment_or_string = c(
      "# needs an interactive() session",
      "message('not interactive()-safe')",
      "shiny::runApp(app)"
    ),
    # Under R CMD check the stop() fires, so the example errors either way.
    negated = c("if (!interactive()) stop('run me at the console')", "shiny::runApp(app)"),
    around_another_call = c("if (interactive()) utils::View(df)", "shiny::runApp(app)"),
    else_branch = "if (interactive()) print(1) else shiny::runApp(app)",
    # The else runs whenever either side is false, so `ready()` alone being false
    # runs the app outside a session.
    else_of_negated_conjunction =
      "if (!interactive() && ready()) message('skip') else shiny::runApp(app)",
    # The next three conditions can be true under R CMD check, so none of them
    # is a guard.
    is_false = "if (isFALSE(interactive())) shiny::runApp(app)",
    or_ci_unset = "if (Sys.getenv('CI') == '' || interactive()) shiny::runApp(app)",
    method = "if (session$interactive()) shiny::runApp(app)"
  )
  for (case in names(cases)) {
    pkg <- rd_pkg(c("\\dontrun{", cases[[case]], "}"))
    expect_equal(
      lab_example_interactive(pkg, verbose = FALSE)$issues,
      "f.Rd: runApp() is hidden in \\dontrun{}",
      label = case
    )
  }
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

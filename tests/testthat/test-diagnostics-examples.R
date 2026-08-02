# Each test here reproduces a rejection a maintainer actually received, so the
# check that answers it cannot quietly stop working.

rd_pkg <- function(example, envir = parent.frame()) {
  pkg <- make_temp_dir(envir = envir)
  write_pkg(
    pkg,
    rd_files = list(
      "f.Rd" = c(
        "\\name{f}", "\\alias{f}", "\\title{F}", "\\description{d}",
        "\\value{x}", "\\examples{", example, "}"
      )
    )
  )
  pkg
}

script_pkg <- function(lines, dir, file, envir = parent.frame()) {
  pkg <- make_temp_dir(envir = envir)
  write_pkg(pkg)
  dir.create(file.path(pkg, dir), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, file.path(pkg, dir, file))
  pkg
}

# "Functions which are supposed to only run interactively (e.g. shiny) should be
# wrapped in if(interactive()). Please replace \dontrun{} with if(interactive()){}"
test_that("an interactive example hidden in dontrun is reported", {
  pkg <- rd_pkg(c("\\dontrun{", "  run_electron_app(app)", "}"))
  res <- lab_example_interactive(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "dontrun", all = FALSE)
})

test_that("an interactive example guarded by interactive() is accepted", {
  pkg <- rd_pkg("if (interactive()) { runApp(app) }")
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("dontrun AROUND an interactive() guard is accepted", {
  # The test above has no \dontrun{} at all, so it never gets past the "nothing is
  # hidden" guard and never reaches the interactive() exemption. This shape does:
  # something IS hidden, and it is an interactive call, and the author has already
  # written the guard CRAN asks for. Belt and braces, not a finding.
  pkg <- rd_pkg(c("\\dontrun{", "  if (interactive()) runApp(app)", "}"))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

test_that("an interactive() guard outside dontrun does not excuse what is inside", {
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

test_that("dontrun around a non-interactive call is left alone", {
  pkg <- rd_pkg(c("\\dontrun{", "  long_running_fit(data)", "}"))
  expect_true(lab_example_interactive(pkg, verbose = FALSE)$passed)
})

# "Please do not install packages in your functions, examples or vignette."
test_that("an install in an example or a vignette is reported", {
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

test_that("a conditional use of an installed package is not an install", {
  pkg <- rd_pkg("if (requireNamespace('pkg', quietly = TRUE)) pkg::fn()")
  expect_true(lab_example_installs(pkg, verbose = FALSE)$passed)
})

# "Please ensure that your functions do not write by default or in your
# examples/vignettes/tests in the user's home filespace"
test_that("a write to a literal path from an example is reported", {
  pkg <- rd_pkg("writeLines('x', 'out.txt')")
  res <- lab_example_writes(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "writeLines", all = FALSE)
})

test_that("a write into tempdir from an example is accepted", {
  expect_true(lab_example_writes(rd_pkg("writeLines('x', tempfile())"),
                                 verbose = FALSE)$passed)
  expect_true(lab_example_writes(
    rd_pkg("write.csv(iris, file.path(tempdir(), 'o.csv'))"),
    verbose = FALSE
  )$passed)
})

# "Please always make sure to reset to user's options(), working directory or par()
# after you changed it in examples and vignettes and demos" -> in your inst/demo folder
test_that("state changed in a demo and never restored is reported", {
  pkg <- script_pkg(c("options(digits = 3)", "plot(1:10)"), file.path("inst", "demo"), "d.R")
  res <- lab_example_state(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "demo", all = FALSE)
})

test_that("state captured and put back is accepted", {
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

test_that("an assignment that is not a restore does not count as one", {
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

test_that("reading options or par is not a change", {
  pkg <- script_pkg(c("u <- par('usr')", "d <- options('digits')"),
                    file.path("inst", "demo"), "d.R")
  expect_true(lab_example_state(pkg, verbose = FALSE)$passed)
})

# "Used ::: in documentation: man/paint_format.Rd: paintr:::paint_format(...)"
test_that("a triple colon in an example is reported", {
  pkg <- rd_pkg("t:::internal_fn(1)")
  res <- lab_example_internal_ns(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, ":::", all = FALSE, fixed = TRUE)
})

test_that("a double colon in an example is accepted", {
  expect_true(lab_example_internal_ns(rd_pkg("stats::median(1:3)"),
                                      verbose = FALSE)$passed)
})

test_that("the example checks run as part of checktor()", {
  pkg <- rd_pkg("install.packages('somepkg')")
  td <- tidy(checktor(pkg, verbose = FALSE, progress = FALSE))
  for (nm in c("example_interactive", "example_installs", "example_writes",
               "example_state", "example_internal_ns")) {
    expect_true(nm %in% td$check, info = nm)
  }
  expect_false(td$passed[td$check == "example_installs"])
})

test_that("example_structure no longer treats an install as a reason for dontrun", {
  # checktor used to accept this shape, which is the one CRAN sent back.
  pkg <- rd_pkg(c("\\dontrun{", "  install_nodejs()", "  run_electron_app()", "}"))
  expect_false(lab_example_structure(pkg, verbose = FALSE)$passed)
})

test_that("the write checks know the tidyverse and other common writers", {
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

test_that("a write function's destination position resolves to that argument", {
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

test_that("the two ::: checks agree rather than contradict", {
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

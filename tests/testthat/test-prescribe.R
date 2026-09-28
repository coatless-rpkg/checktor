# prescribe() turns the checks that failed into treatments.

# Test prescribe() ----

test_that("prescribe(): surfaces a registered check, which has no treatment", {
  # Only built-in checks have a treatment. Before the fallback, a check without
  # one got its header and nothing else, silent about the actual problem (#4).
  withr::defer(unregister_check("house_rule"))
  register_check(
    "house_rule",
    function(path, verbose = TRUE) {
      checktor_check_result(FALSE, "R/a.R:1 (house rule broken)", "House rule")
    },
    category = "general",
    severity = "policy"
  )
  pkg <- make_temp_dir()
  write_pkg(pkg)
  res <- checktor(pkg, verbose = FALSE, progress = FALSE)

  txt <- paste(cli::cli_fmt(prescribe(res)), collapse = "\n")
  expect_match(txt, "House rule", fixed = TRUE)
  expect_match(txt, "R/a.R:1 (house rule broken)", fixed = TRUE)
  expect_match(txt, "Review the detailed diagnosis above", fixed = TRUE)

  # The heading and the issues are the check's own text, printed as written.
  res$general_issues$house_rule$message <- "House rule for {stop('evaluated')}"
  res$general_issues$house_rule$issues <- "a.R mentions {stop('evaluated')}"
  out <- NULL
  expect_no_error(out <- cli::cli_fmt(prescribe(res)))
  out <- paste(out, collapse = "\n")
  expect_match(out, "House rule for {stop('evaluated')}", fixed = TRUE)
  expect_match(out, "a.R mentions {stop('evaluated')}", fixed = TRUE)
})

test_that("prescribe(): lists what a check with a treatment found, even on a clean verdict", {
  # The verdict can be clean while advisory findings remain. Prescribing for the
  # verdict alone would withhold the remedy for every one of them.
  pkg <- make_temp_dir()
  write_pkg(pkg, news = FALSE) # clean except: no NEWS file, which is `opinion`
  res <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false(res$general_issues$passed[["news_file"]]) # sanity
  expect_true(is_healthy(res)) # nothing CRAN will reject
  expect_gt(res$metadata$advisory_issues, 0L) # but there IS something to say

  txt <- paste(cli::cli_fmt(prescribe(res)), collapse = "\n")
  # A curated check gets its own title and remedy, not #4's generic fallback.
  expect_match(txt, "Missing NEWS File", fixed = TRUE)
  expect_match(txt, "usethis::use_news_md()", fixed = TRUE)
  # The finding, not only the "NEWS file check" heading: "NEWS" alone is
  # satisfied by a header, and a header-only prescription is exactly the
  # silence this test is here to rule out.
  expect_match(txt, "No NEWS file found", fixed = TRUE)

  # The issues quote the package, so they print as written.
  res$general_issues$news_file$issues <- "NEWS.md mentions {stop('evaluated')}"
  out <- NULL
  expect_no_error(out <- cli::cli_fmt(prescribe(res)))
  expect_match(
    paste(out, collapse = "\n"),
    "NEWS.md mentions {stop('evaluated')}",
    fixed = TRUE
  )
})

test_that("prescribe(): gives a DESCRIPTION R cannot read its own treatment", {
  r <- checktor(unparseable_pkg(), verbose = FALSE, progress = FALSE)
  txt <- paste(cli::cli_fmt(prescribe(r)), collapse = "\n")
  expect_match(txt, "DESCRIPTION R Cannot Read", fixed = TRUE)
  expect_match(txt, "indented by a space or tab", fixed = TRUE)
  # The finding itself, which quotes the line R stopped at.
  expect_match(txt, "this line is not a f", fixed = TRUE)
  expect_no_match(txt, "Review the detailed diagnosis above", fixed = TRUE)

  # That line is the package's text, so it prints as written.
  r$description_issues$description_file$issues <-
    "DESCRIPTION does not parse: Line starting '{stop('evaluated')} ...' is malformed!"
  out <- NULL
  expect_no_error(out <- cli::cli_fmt(prescribe(r)))
  expect_match(paste(out, collapse = "\n"), "{stop('evaluated')}", fixed = TRUE)
})

test_that("prescribe(): fits the DESCRIPTION example to why R cannot read it", {
  # The reflowed Description line is the fix for a malformed line only. A file
  # that is missing or cannot be opened needs a fix of its own.
  r <- checktor(unopenable_pkg("directory"), verbose = FALSE, progress = FALSE)
  shown <- function(issue) {
    r$description_issues$description_file$issues <- issue
    paste(cli::cli_fmt(prescribe(r)), collapse = "\n")
  }

  txt <- shown(r$description_issues$description_file$issues)
  expect_match(txt, "# DESCRIPTION is a directory, not a file", fixed = TRUE)
  expect_match(txt, "has to be a file", fixed = TRUE)
  expect_no_match(txt, "reflowed", fixed = TRUE)

  txt <- shown("DESCRIPTION file not found")
  expect_match(txt, "usethis::use_description()", fixed = TRUE)
  expect_no_match(txt, "reflowed", fixed = TRUE)

  txt <- shown("DESCRIPTION cannot be read (permission denied)")
  expect_match(txt, "Sys.chmod(\"DESCRIPTION\", \"644\")", fixed = TRUE)
  expect_no_match(txt, "reflowed", fixed = TRUE)

  # Every one of them ends by reading the file the way R CMD build does.
  expect_match(txt, "read.dcf(\"DESCRIPTION\")", fixed = TRUE)
  txt <- shown(paste(
    "DESCRIPTION contains a blank line, which splits it into more than one",
    "record"
  ))
  expect_match(txt, "reflowed", fixed = TRUE)
})

test_that("prescribe(): prints the finding, the treatment and the example", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "bad <- function() T")
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_snapshot(prescribe(r))
})

test_that("prescribe(): every built-in check has a treatment, and only those", {
  # Treatments are looked up by check name alone, so a misspelt one would never
  # be shown, and a check without one would get only the generic fallback.
  expect_setequal(names(treatments), BUILTIN_CHECKS$name)
  expect_identical(anyDuplicated(names(treatments)), 0L)
  for (chk in names(treatments)) {
    rx <- treatments[[chk]]
    expect_true(is.character(rx$title) && length(rx$title) == 1L, label = chk)
    expect_true(
      is.character(rx$treatment) && length(rx$treatment) == 1L,
      label = chk
    )
  }
})

test_that("prescribe(): every treatment renders in cli and in the reports", {
  # The treatment reaches cli as a format string, so a stray brace would error or
  # evaluate; the reports convert the same markup, and none of it may survive.
  for (chk in names(treatments)) {
    rx <- treatments[[chk]]
    out <- NULL
    expect_no_error(
      out <- cli::cli_fmt({
        cli::cli_h3(cli_literal(rx$title))
        cli::cli_text(paste0("{.strong Treatment:} ", rx$treatment))
      })
    )
    expect_no_match(paste(out, collapse = " "), "{.", fixed = TRUE, label = chk)
    md <- treatment_markdown(rx$treatment)
    expect_no_match(md, "{.", fixed = TRUE, label = chk)
    expect_no_match(md, "{{", fixed = TRUE, label = chk)
    expect_no_match(md, "}}", fixed = TRUE, label = chk)
  }
})

# Test treatment_markdown() ----

test_that("treatment_markdown(): turns cli markup into code spans", {
  expect_identical(
    treatment_markdown("Replace {.code T} with {.code TRUE}"),
    "Replace `T` with `TRUE`"
  )
  expect_identical(
    treatment_markdown("Put it in {.code \\donttest{{}}} with {.pkg bibtex}"),
    "Put it in `\\donttest{}` with bibtex"
  )
  expect_identical(
    treatment_markdown("Guard with {.code if (x) {{ ... }}}. Done"),
    "Guard with `if (x) { ... }`. Done"
  )
  expect_identical(treatment_markdown("No markup"), "No markup")
})

test_that("treatment_html(): escapes the text and marks the code", {
  expect_identical(
    treatment_html("Write {.code <https://...>} links"),
    "Write <code>&lt;https://...&gt;</code> links"
  )
})

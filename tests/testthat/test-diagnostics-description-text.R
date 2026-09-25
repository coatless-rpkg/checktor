# Regression tests for the DESCRIPTION-file diagnostics, especially that
# multi-line fields (Description, Title) are read in full via read.dcf.
#
# A test that names a CRAN package reproduces a false positive or a missed
# finding from that package's real sources, so a regression fails here first.

# Test lab_description_length() ----

test_that("lab_description_length(): reads continuation lines, not just line 1", {
  pkg <- make_temp_dir()
  long_desc <- paste(
    "First sentence with enough words to fool nobody.",
    "    Second continuation sentence with even more words.",
    "    Third line continuing to make sure word counting picks it up.",
    sep = "\n"
  )
  write_pkg(pkg, description = long_desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$description_length$passed)
  expect_gte(res$description_length$words, 20L)
  expect_gte(res$description_length$sentences, 2L)
})

test_that("lab_description_length(): still flags short descriptions", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Short.")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$description_length$passed)
})

test_that("lab_description_length(): measures words, not sentences", {
  # renderthis ships a complete 31-word single-sentence Description. Demanding
  # "2+ sentences" has no authority and flagged it.
  one_sentence <- paste(
    "Render slides to different formats, including 'html', 'pdf', 'png', 'gif',",
    "'pptx', and 'mp4', as well as a 'social' output, a 'png' of the first slide",
    "re-sized for sharing on social media."
  )
  expect_true(
    lab_description_length(make_temp_dir(),
      verbose = FALSE,
      desc = c(Description = one_sentence)
    )$passed
  )
})

test_that("lab_description_length(): flags a Description that says nothing", {
  res <- lab_description_length(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Does stuff.")
  )
  expect_false(res$passed)
})

test_that("lab_description_length(): a 31-word single-sentence Description is not too short", {
  # renderthis/DESCRIPTION. The old rule demanded 2+ sentences, which has no
  # authority behind it.
  desc <- paste(
    "Render slides to different formats, including 'html', 'pdf', 'png', 'gif',",
    "'pptx', and 'mp4', as well as a 'social' output, a 'png' of the first slide",
    "re-sized for sharing on social media."
  )
  expect_true(
    lab_description_length(make_temp_dir(),
      verbose = FALSE,
      desc = c(Description = desc)
    )$passed
  )
})

# Test lab_description_function_quotes() ----

test_that("lab_description_function_quotes(): flags single-quoted functions", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      "Wraps the 'lm()' interface for users.",
      "It does a number of helpful things here."
    )
  )
  # Not part of a run any more: WRE says single quotes are for non-English usage
  # INCLUDING other packages, an inclusive list, so a quoted function name breaks
  # no rule. Still callable directly.
  expect_false(
    lab_description_function_quotes(pkg, verbose = FALSE)$passed
  )
  expect_null(
    diagnose_description_issues(
      pkg,
      verbose = FALSE
    )$description_function_quotes
  )
})

test_that("lab_description_function_quotes(): accepts quoted software names", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      "Provides an interface to 'ggplot2' graphics.",
      "It does a number of helpful things here."
    )
  )
  expect_true(
    lab_description_function_quotes(pkg, verbose = FALSE)$passed
  )
})

# Test lab_description_starts_with() ----

test_that("lab_description_starts_with(): flags CRAN's forbidden openers", {
  for (bad in c(
    "This package provides tools for X.",
    "A package that does X.",
    "In this package we do X."
  )) {
    res <- lab_description_starts_with(make_temp_dir(),
      verbose = FALSE,
      desc = c(Description = bad)
    )
    expect_false(res$passed, info = bad)
  }
})

test_that("lab_description_starts_with(): flags a lowercase initial", {
  # R's own descr_bad_initial rule, which checktor previously lacked.
  res <- lab_description_starts_with(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "runs extra diagnostics on R packages.")
  )
  expect_false(res$passed)
})

test_that("lab_description_starts_with(): accepts a well-formed Description", {
  expect_true(
    lab_description_starts_with(make_temp_dir(),
      verbose = FALSE,
      desc = c(Description = "Runs extra diagnostics on R packages.")
    )$passed
  )
})

# Test spelling_accepted_words() ----

test_that("spelling_accepted_words(): reads every Config/checktor vocabulary", {
  # A name listed for any of the quoting checks is a word the package uses on
  # purpose, so the spelling check must not ask about it either.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = c(
      "Config/checktor/acronyms: Qacro",
      "Config/checktor/software_names: Vbtool",
      "Config/checktor/language_names: Zqlang",
      "Config/checktor/format_names: Qwxformat"
    )
  )
  expect_contains(
    spelling_accepted_words(pkg),
    c("Qacro", "Vbtool", "Zqlang", "Qwxformat")
  )
})

# Test lab_spelling() ----

test_that("lab_spelling(): flags DESCRIPTION words and honours a whitelist", {
  skip_on_cran() # the words flagged depend on the installed dictionary
  skip_if_not(
    nzchar(Sys.which("aspell")) || nzchar(Sys.which("hunspell")),
    "no spell-check backend"
  )
  withr::local_options(checktor.spelling = TRUE)
  desc <- "Build a WASM REPL for WebAssembly workflows and more."

  pkg <- make_temp_dir()
  write_pkg(pkg, description = desc)
  res <- lab_spelling(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_true(all(c("WASM", "REPL", "WebAssembly") %in% res$issues))

  # accepted via Config/checktor/acronyms
  pkg2 <- make_temp_dir()
  write_pkg(
    pkg2,
    description = desc,
    extra = "Config/checktor/acronyms: WASM, REPL, WebAssembly"
  )
  expect_true(lab_spelling(pkg2, verbose = FALSE)$passed)

  # accepted via a .aspell/ dictionary
  pkg3 <- make_temp_dir()
  write_pkg(pkg3, description = desc)
  dir.create(file.path(pkg3, ".aspell"))
  saveRDS(
    c("WASM", "REPL", "WebAssembly"),
    file.path(pkg3, ".aspell", "words.rds")
  )
  expect_true(lab_spelling(pkg3, verbose = FALSE)$passed)
})

test_that("lab_spelling(): skips what CRAN incoming skips", {
  skip_on_cran() # the words flagged depend on the installed dictionary
  skip_if_not(
    nzchar(Sys.which("aspell")) || nzchar(Sys.which("hunspell")),
    "no spell-check backend"
  )
  withr::local_options(checktor.spelling = TRUE)
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste0(
      "Extends 'ggplot2' and 'dplyr' through mutate() and dplyr::filter(), ",
      "see <doi:10.1234/zzqqxx> and <https://example.org/zzqqyy>. Also qwzxv."
    )
  )
  res <- lab_spelling(pkg, verbose = FALSE)
  expect_equal(res$issues, "qwzxv")
})

test_that("lab_spelling(): reports a skip, not a pass, when turned off", {
  # A skipped check that reads as a passing one is exactly the failure mode the
  # skipped-result contract exists to prevent: the printed summary would drop
  # spelling from "checks did not run".
  withr::local_options(checktor.spelling = FALSE)
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Build a WASM REPL for WebAssembly.")
  res <- lab_spelling(pkg, verbose = FALSE)
  expect_true(res$skipped)
  expect_true(res$passed)
  expect_equal(length(res$issues), 0L)
})

test_that("lab_spelling(): reports a skip when the backend fails", {
  skip_on_os("windows") # the stand-in backend is a shell script
  withr::local_options(checktor.spelling = TRUE)
  # An aspell on the PATH that always fails: nothing was spell-checked, so the
  # check must not read as a pass.
  bin <- make_temp_dir()
  writeLines(c("#!/bin/sh", "exit 1"), file.path(bin, "aspell"))
  Sys.chmod(file.path(bin, "aspell"), "755")
  withr::local_envvar(PATH = bin)
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Build a WASM REPL for WebAssembly.")
  # utils::aspell() warns about the failed version probe on its way to the error
  res <- suppressWarnings(lab_spelling(pkg, verbose = FALSE))
  expect_true(res$skipped)
  expect_equal(length(res$issues), 0L)
})

test_that("lab_spelling(): reports a skip when no backend is installed", {
  withr::local_options(checktor.spelling = TRUE)
  # Empty the PATH so Sys.which() finds neither aspell nor hunspell, which is
  # the state every CI leg actually runs in.
  withr::local_envvar(PATH = "")
  skip_if(
    nzchar(Sys.which("aspell")) || nzchar(Sys.which("hunspell")),
    "backend still reachable with an empty PATH"
  )
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Build a WASM REPL for WebAssembly.")
  res <- lab_spelling(pkg, verbose = FALSE)
  expect_true(res$skipped)
  expect_match(res$skip_reason, "backend")
})

# Test spelling_accepted_words() ----

test_that("spelling_accepted_words(): gathers every whitelist mechanism", {
  # The detection test above is gated behind a backend that no CI leg installs,
  # so the whitelist plumbing is pinned here instead: no aspell/hunspell needed.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = c(
      "Config/checktor/acronyms: WebAssembly",
      "Config/checktor/software_names: Shinylive"
    )
  )
  dir.create(file.path(pkg, ".aspell"))
  saveRDS("WASM", file.path(pkg, ".aspell", "words.rds"))
  dir.create(file.path(pkg, "inst"))
  writeLines("REPL", file.path(pkg, "inst", "WORDLIST"))

  # One word per source, so dropping any single source changes the answer.
  expect_setequal(
    spelling_accepted_words(pkg),
    c("WASM", "REPL", "WebAssembly", "Shinylive")
  )
})

test_that("spelling_accepted_words(): is empty when there is no whitelist", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_equal(spelling_accepted_words(pkg), character(0))
})

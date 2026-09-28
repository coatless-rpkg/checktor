# Test lab_example_structure() ----

test_that("lab_example_structure(): flags unjustified \\dontrun{}", {
  cases <- list(
    arithmetic = "  x <- 1 + 1",
    "plain call" = "  add(1, 2)",
    # checktor used to accept this shape, which is the one CRAN sent back.
    "install and launcher" = c("  install_nodejs()", "  run_electron_app()")
  )
  for (case in names(cases)) {
    pkg <- rd_pkg(c("\\dontrun{", cases[[case]], "}"))
    expect_false(lab_example_structure(pkg, verbose = FALSE)$passed, label = case)
  }
})

test_that("lab_example_structure(): accepts \\dontrun{} justified by a keyword or a placeholder path", {
  # The credential/network justifiers were covered by a single fixture that read
  # "# Requires API token" and called authenticate(api_key = 'secret') -- that one
  # example matches FIVE alternatives at once (API, token, key, secret, auth), so
  # four of them could be deleted from justify_re and the test stayed green. Each
  # of the first five cases matches exactly ONE alternative alone, so any single
  # deletion is caught.
  cases <- list(
    API = "  pull_from_API(cfg)",
    token = "  refresh_token(tok)",
    key = "  set_key(cfg)",
    secret = "  read_secret(cfg)",
    auth = "  run_auth(cfg)",
    # The old fixture described above. It matches API, token, key, secret and
    # auth at once, and is kept only as the original input.
    "several keywords (old fixture)" = c(
      "  # Requires API token",
      "  authenticate(api_key = 'secret')"
    ),
    # shinyelectron ships run_electron_app("path/to/app") examples. The path/to
    # placeholder is what justifies \dontrun{} here: an install or launcher call
    # alone does not (CRAN asks for if (interactive()) there), as the install
    # case in "flags unjustified \dontrun{}" shows.
    "placeholder path" = c(
      "  install_nodejs()",
      "  run_electron_app(\"path/to/electron/app\")"
    )
  )
  for (case in names(cases)) {
    pkg <- rd_pkg(c("\\dontrun{", cases[[case]], "}"))
    expect_true(lab_example_structure(pkg, verbose = FALSE)$passed, label = case)
  }
})

test_that("lab_example_structure(): extracts only the \\examples{} block", {
  # Verifies the balanced-brace extractor doesn't bleed into other sections.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\value{1}",
        "\\examples{",
        "  x <- 1", # no \\dontrun here
        "}",
        "\\seealso{",
        "  \\dontrun{not-an-example}", # outside \\examples - must NOT trigger
        "}"
      )
    )
  )
  expect_true(lab_example_structure(pkg, verbose = FALSE)$passed)
})

test_that("lab_example_structure(): accepts \\dontrun{} around a shiny server", {
  # surveydown's examples define server <- function(input, output, session),
  # which cannot run outside a live app -- but never say the word "shiny", so a
  # literal search for it reported three correct \dontrun{} blocks as needless.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "sd_value.Rd" = c(
        "\\name{sd_value}",
        "\\alias{sd_value}",
        "\\title{v}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "\\dontrun{",
        "  server <- function(input, output, session) {",
        "    age <- sd_value(age)",
        "  }",
        "}",
        "}"
      )
    )
  )
  expect_true(lab_example_structure(pkg, verbose = FALSE)$passed)
})

# Test lab_missing_examples() ----

test_that("lab_missing_examples(): flags exported topics without \\examples", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\alias{fn}",
        "\\title{fn}",
        "\\usage{fn(x)}",
        "\\value{A value.}"
      )
    )
  )
  writeLines("export(fn)", file.path(pkg, "NAMESPACE"))
  res <- lab_missing_examples(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(res$missing, "fn.Rd")
})

test_that("lab_missing_examples(): accepts an exported topic with \\examples", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\alias{fn}",
        "\\title{fn}",
        "\\value{A value.}",
        "\\examples{",
        "fn(1)",
        "}"
      )
    )
  )
  writeLines("export(fn)", file.path(pkg, "NAMESPACE"))
  expect_true(lab_missing_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_missing_examples(): skips unexported topics and no NAMESPACE", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\alias{fn}",
        "\\title{fn}",
        "\\value{1}"
      )
    )
  )
  writeLines("export(other)", file.path(pkg, "NAMESPACE"))
  expect_true(lab_missing_examples(pkg, verbose = FALSE)$passed)

  pkg2 <- make_temp_dir()
  write_pkg(
    pkg2,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\alias{fn}",
        "\\title{fn}",
        "\\value{1}"
      )
    )
  ) # no NAMESPACE at all
  expect_true(lab_missing_examples(pkg2, verbose = FALSE)$passed)
})

test_that("lab_missing_examples(): exempts \\keyword{internal} topics", {
  # R's own checkRdContents grants keyword-internal pages substantive leniency,
  # keying off the keyword alone and never reading NAMESPACE.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = "deprecated_fn <- function() TRUE",
    rd_files = list(
      "deprecated_fn.Rd" = c(
        "\\name{deprecated_fn}",
        "\\alias{deprecated_fn}",
        "\\title{Old}",
        "\\usage{deprecated_fn()}",
        "\\description{Superseded.}",
        "\\value{x}",
        "\\keyword{internal}"
      )
    )
  )
  writeLines("export(deprecated_fn)", file.path(pkg, "NAMESPACE"))
  expect_true(lab_missing_examples(pkg, verbose = FALSE)$passed)
})

# Test lab_suggested_in_examples() ----

test_that("lab_suggested_in_examples(): recognises each way an example needs a package", {
  for (use in c(
    "library(dplyr)",
    "library('dplyr')",
    "require(dplyr)",
    "base::library(dplyr, quietly = TRUE)",
    "x <- dplyr::filter(df, y > 1)",
    "dplyr:::helper(x)",
    "data <- dplyr::starwars"
  )) {
    pkg <- rd_pkg(use, extra = "Suggests: dplyr")
    expect_equal(
      lab_suggested_in_examples(pkg, verbose = FALSE)$issues,
      "f.Rd: uses Suggested package 'dplyr' in \\examples without a guard",
      label = use
    )
  }

  # Two uses on one page are reported as a single issue.
  pkg <- rd_pkg(c("library(dplyr)", "dplyr::filter(x)"), extra = "Suggests: dplyr")
  expect_equal(
    lab_suggested_in_examples(pkg, verbose = FALSE)$issues,
    "f.Rd: uses Suggested package 'dplyr' in \\examples without a guard",
    label = "two uses, one issue"
  )
})

test_that("lab_suggested_in_examples(): accepts each guard that names the package", {
  for (guard in c(
    "requireNamespace(\"dplyr\", quietly = TRUE)",
    "rlang::is_installed('dplyr')",
    "rlang::is_installed(c('tidyr', 'dplyr'))",
    "require(dplyr)",
    "isTRUE(requireNamespace('dplyr', quietly = TRUE))",
    "requireNamespace('dplyr', quietly = TRUE) && interactive()",
    "{ set.seed(1); requireNamespace('dplyr', quietly = TRUE) }",
    "FALSE"
  )) {
    pkg <- rd_pkg(
      c(paste0("if (", guard, ") {"), "  library(dplyr)", "  dplyr::filter(x)", "}"),
      extra = "Suggests: dplyr, tidyr"
    )
    expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed, label = guard)
  }
})

test_that("lab_suggested_in_examples(): the else of a negated guard is guarded", {
  pkg <- rd_pkg(
    c(
      "if (!requireNamespace('dplyr', quietly = TRUE)) {",
      "  message('install dplyr')",
      "} else {",
      "  dplyr::filter(x)",
      "}"
    ),
    extra = "Suggests: dplyr"
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): a guard that short-circuits is a guard", {
  # FuelDeep3D asks whether reticulate is installed before asking reticulate
  # anything, which `&&` guarantees.
  pkg <- rd_pkg(
    c(
      "if (requireNamespace('reticulate', quietly = TRUE) &&",
      "    reticulate::py_module_available('torch')) {",
      "  library(reticulate)",
      "}"
    ),
    extra = "Suggests: reticulate"
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): a guard kept in a variable is a guard", {
  # lax asks once and tests the answer: `got_evd <- requireNamespace("evd")`.
  pkg <- rd_pkg(
    c(
      "got_evd <- requireNamespace('evd', quietly = TRUE)",
      "got_ismev = requireNamespace('ismev', quietly = TRUE)",
      "if (got_evd & got_ismev) {",
      "  library(evd)",
      "  fit <- ismev::gev.fit(x)",
      "}"
    ),
    extra = "Suggests: evd, ismev"
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): a comment inside a guard, an assignment or a call leaves a guard", {
  # A comment is a node of its own: after `&&`, between the arrow and the value,
  # or between a function's name and its arguments.
  for (example in list(
    c(
      "if (requireNamespace('dplyr', quietly = TRUE) && # need it",
      "    requireNamespace('tidyr', quietly = TRUE)) {",
      "  dplyr::filter(x)",
      "}"
    ),
    c(
      "ok <- # ask once",
      "  requireNamespace('dplyr', quietly = TRUE)",
      "if (ok) dplyr::filter(x)"
    ),
    c(
      "if (requireNamespace # ask first",
      "    ('dplyr', quietly = TRUE)) dplyr::filter(x)"
    )
  )) {
    pkg <- rd_pkg(example, extra = "Suggests: dplyr, tidyr")
    expect_true(
      lab_suggested_in_examples(pkg, verbose = FALSE)$passed,
      label = paste(example, collapse = " ")
    )
  }
})

test_that("lab_suggested_in_examples(): a guard read through a wrapper is a guard", {
  for (guard in c(
    "suppressWarnings(requireNamespace('dplyr', quietly = TRUE))",
    "suppressWarnings(requireNamespace('dplyr'), classes = 'warning')",
    "suppressMessages(requireNamespace('dplyr'))",
    "suppressPackageStartupMessages(require(dplyr))",
    "invisible(requireNamespace('dplyr', quietly = TRUE))",
    "suppressWarnings(expr = requireNamespace('dplyr'))",
    "suppressWarnings(classes = 'warning', requireNamespace('dplyr'))",
    "suppressMessages(classes = 'message', expr = requireNamespace('dplyr'))",
    "invisible(x = requireNamespace('dplyr', quietly = TRUE))"
  )) {
    pkg <- rd_pkg(
      c(paste0("if (", guard, ") {"), "  dplyr::filter(x)", "}"),
      extra = "Suggests: dplyr"
    )
    expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed, label = guard)
  }
})

test_that("lab_suggested_in_examples(): a guard assigned in another function, local() or a lambda is no guard", {
  for (example in list(
    # `ok` is local to g(), so the `if` at top level reads nothing g() set.
    "g <- function() ok <- requireNamespace('dplyr', quietly = TRUE)",
    # local() and `\(x)` open a scope of their own, like `function(x)`.
    c("local({", "  ok <- requireNamespace('dplyr', quietly = TRUE)", "})"),
    "g <- \\\\(x) ok <- requireNamespace('dplyr', quietly = TRUE)"
  )) {
    pkg <- rd_pkg(c(example, "if (ok) dplyr::filter(x)"), extra = "Suggests: dplyr")
    expect_equal(
      lab_suggested_in_examples(pkg, verbose = FALSE)$issues,
      "f.Rd: uses Suggested package 'dplyr' in \\examples without a guard",
      label = paste(example, collapse = " ")
    )
  }

  # Assigned and tested inside the same local() or lambda, it is a guard.
  pkg <- rd_pkg(
    c(
      "local({",
      "  ok <- requireNamespace('dplyr', quietly = TRUE)",
      "  if (ok) dplyr::filter(x)",
      "})",
      "h <- \\\\(x) { ok <- requireNamespace('dplyr'); if (ok) dplyr::filter(x) }"
    ),
    extra = "Suggests: dplyr"
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): a guard assigned in a condition feeds a later test", {
  # An `if` or `while` condition and a `for` sequence run whenever the statement
  # does; only the branches and the loop body may not.
  for (example in list(
    c(
      "if (!(ok <- requireNamespace('dplyr', quietly = TRUE))) message('no dplyr')",
      "if (ok) dplyr::filter(x)"
    ),
    c(
      "f <- function(x) {",
      "  if (!(ok <- requireNamespace('dplyr', quietly = TRUE))) return()",
      "  if (ok) dplyr::filter(x)",
      "}"
    ),
    c(
      "while ((ok <- requireNamespace('dplyr', quietly = TRUE))) {",
      "  if (ok) dplyr::filter(x)",
      "  break",
      "}"
    ),
    c(
      "for (p in (ok <- requireNamespace('dplyr', quietly = TRUE))) message(p)",
      "if (ok) dplyr::filter(x)"
    )
  )) {
    pkg <- rd_pkg(example, extra = "Suggests: dplyr")
    expect_true(
      lab_suggested_in_examples(pkg, verbose = FALSE)$passed,
      label = paste(example, collapse = " ")
    )
  }
})

test_that("lab_suggested_in_examples(): a guard assigned where it may never run is no guard", {
  for (line in c(
    # The body may never run, and then `ok` holds what it held before.
    "for (i in seq_len(n)) ok <- requireNamespace('dplyr', quietly = TRUE)",
    "while (retry()) ok <- requireNamespace('dplyr', quietly = TRUE)",
    # `a && b` evaluates `b` only when `a` is true, and `a || b` only when `a` is
    # false, so the assignment may never run and `ok` keeps what it held before.
    "if (interactive() && (ok <- requireNamespace('dplyr'))) NULL",
    "if (interactive() || (ok <- requireNamespace('dplyr'))) NULL",
    "y <- interactive() && (ok <- requireNamespace('dplyr'))",
    "interactive() && # why\n  (ok <- requireNamespace('dplyr'))"
  )) {
    pkg <- rd_pkg(
      c("ok <- TRUE", line, "if (ok) dplyr::filter(x)"),
      extra = "Suggests: dplyr"
    )
    expect_equal(
      lab_suggested_in_examples(pkg, verbose = FALSE)$issues,
      "f.Rd: uses Suggested package 'dplyr' in \\examples without a guard",
      label = line
    )
  }

  # The left side always runs, and so does either side of `&` or `|`.
  for (line in c(
    "if ((ok <- requireNamespace('dplyr')) && interactive()) NULL",
    "y <- interactive() & (ok <- requireNamespace('dplyr'))"
  )) {
    pkg <- rd_pkg(
      c("ok <- TRUE", line, "if (ok) dplyr::filter(x)"),
      extra = "Suggests: dplyr"
    )
    expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed, label = line)
  }
})

test_that("lab_suggested_in_examples(): reads \\dontdiff{} code written beside another block", {
  # R CMD check runs \dontdiff{} code, on lines of its own.
  pkg <- rd_pkg("\\dontrun{f()}\\dontdiff{dplyr::filter(x)}", extra = "Suggests: dplyr")
  expect_equal(
    lab_suggested_in_examples(pkg, verbose = FALSE)$issues,
    "f.Rd: uses Suggested package 'dplyr' in \\examples without a guard"
  )
})

test_that("lab_suggested_in_examples(): a variable holding another answer is no guard", {
  pkg <- rd_pkg(
    c(
      "got_evd <- requireNamespace('evd', quietly = TRUE)",
      "got_evd <- TRUE",
      "if (got_evd) library(evd)"
    ),
    extra = "Suggests: evd"
  )
  expect_false(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): ignores usage inside \\dontrun", {
  pkg <- rd_pkg(c("\\dontrun{", "library(dplyr)", "}"), extra = "Suggests: dplyr")
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): \\donttest{} is no guard", {
  # R CMD check --as-cran runs \donttest{} code, so on a machine without the
  # package the example fails there.
  pkg <- rd_pkg(c("\\donttest{", "library(dplyr)", "}"), extra = "Suggests: dplyr")
  expect_equal(
    lab_suggested_in_examples(pkg, verbose = FALSE)$issues,
    "f.Rd: uses Suggested package 'dplyr' in \\examples without a guard"
  )
})

test_that("lab_suggested_in_examples(): passes when there are no Suggests", {
  pkg <- rd_pkg("library(dplyr)")
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): a guard that is false under R CMD check excuses the use", {
  # CRAN's noSuggests run is R CMD check, which never enters these branches, so
  # the missing package is never reached there. surveydown's sd_question_custom.Rd
  # guards with interactive().
  for (guard in c(
    "interactive()",
    "rlang::is_interactive()",
    "identical(Sys.getenv('IN_PKGDOWN'), 'true')",
    "Sys.getenv('NOT_CRAN') == 'true'",
    "'true' == Sys.getenv(\"NOT_CRAN\")",
    "identical(Sys.getenv('NOT_CRAN', 'false'), 'true')",
    "isTRUE(as.logical(Sys.getenv('NOT_CRAN')))",
    "identical(x = Sys.getenv('NOT_CRAN'), y = 'true')",
    "identical(y = 'true', x = Sys.getenv('NOT_CRAN'))",
    "Sys.getenv(unset = 'false', 'NOT_CRAN') == 'true'",
    "nzchar(Sys.getenv('IN_PKGDOWN'))",
    "Sys.getenv('IN_PKGDOWN') != ''",
    "as.logical(Sys.getenv('NOT_CRAN', 'false'))"
  )) {
    pkg <- rd_pkg(
      c(paste0("if (", guard, ") {"), "  library(leaflet)", "  leaflet::leaflet()", "}"),
      extra = "Suggests: leaflet"
    )
    expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed, label = guard)
  }
})

test_that("lab_suggested_in_examples(): an @examplesIf interactive() excuses the use", {
  pkg <- rd_pkg(
    c(
      "\\dontshow{if (interactive()) (if (getRversion() >= \"3.4\") withAutoprint else force)(\\{ # examplesIf}",
      "leaflet::leaflet()",
      "\\dontshow{\\}) # examplesIf}"
    ),
    extra = "Suggests: leaflet"
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): a condition that holds or errors under R CMD check is no guard", {
  for (guard in c(
    "!interactive()",
    "Sys.getenv('NOT_CRAN') != 'true'",
    "!identical(Sys.getenv('IN_PKGDOWN'), 'true')",
    "identical(Sys.getenv('NOT_CRAN', unset = 'true'), 'true')",
    "isTRUE(as.logical(Sys.getenv('NOT_CRAN', 'TRUE')))",
    "identical(y = 'true', x = Sys.getenv('NOT_CRAN', unset = 'true'))",
    "Sys.getenv(unset = 'true', 'NOT_CRAN') == 'true'",
    "!nzchar(Sys.getenv('IN_PKGDOWN'))",
    "nzchar(Sys.getenv('IN_PKGDOWN', 'no'))",
    "Sys.getenv('IN_PKGDOWN') == ''",
    "Sys.getenv('IN_PKGDOWN', 'no') != ''",
    "as.logical(Sys.getenv('NOT_CRAN', 'true'))",
    # as.logical("") is NA, and `if (NA)` stops the example there instead of
    # skipping the branch; isTRUE() is what turns it into a guard.
    "as.logical(Sys.getenv('NOT_CRAN'))",
    "as.logical(Sys.getenv('NOT_CRAN', unset = 'no'))"
  )) {
    pkg <- rd_pkg(
      c(paste0("if (", guard, ") {"), "  leaflet::leaflet()", "}"),
      extra = "Suggests: leaflet"
    )
    expect_equal(
      lab_suggested_in_examples(pkg, verbose = FALSE)$issues,
      "f.Rd: uses Suggested package 'leaflet' in \\examples without a guard",
      label = guard
    )
  }
})

test_that("lab_suggested_in_examples(): a base or recommended package ships with R, and excuses no other", {
  # R ships its recommended packages, and CRAN's checks keep one available once the
  # DESCRIPTION declares it, in Suggests too. ggplot2's examples reach rpart and
  # nlme in \donttest{}.
  pkg <- rd_pkg(
    c(
      "MASS::fractions(0.5)",
      "\\donttest{",
      "library(nlme)",
      "fit <- rpart::rpart(Kyphosis ~ Age, data = rpart::kyphosis)",
      "}"
    ),
    extra = "Suggests: MASS, nlme, rpart"
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed, label = "recommended")

  # Every R installation has its base packages, so one in Suggests is always there.
  base <- c(
    "parallel", "tcltk", "tools", "utils", "stats", "methods", "grDevices",
    "graphics", "grid", "splines", "stats4", "compiler", "datasets"
  )
  pkg <- rd_pkg(
    c(
      "n <- parallel::detectCores()",
      "library(tcltk)",
      "\\donttest{",
      paste0(setdiff(base, c("parallel", "tcltk")), "::f()"),
      "}"
    ),
    extra = paste("Suggests:", paste(base, collapse = ", "))
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed, label = "base")

  # Neither excuses another Suggested package used beside it.
  shipped <- c(parallel = "parallel::detectCores()", MASS = "MASS::fractions(0.5)")
  for (p in names(shipped)) {
    pkg <- rd_pkg(
      c(shipped[[p]], "dplyr::filter(x)"),
      extra = paste0("Suggests: ", p, ", dplyr")
    )
    expect_equal(
      lab_suggested_in_examples(pkg, verbose = FALSE)$issues,
      "f.Rd: uses Suggested package 'dplyr' in \\examples without a guard",
      label = p
    )
  }
})

test_that("lab_suggested_in_examples(): a guard from a Suggested package is itself a use", {
  # rlang::is_installed() needs rlang, so when rlang is only suggested the guard
  # fails where rlang is missing. The treatment recommends base R instead.
  pkg <- rd_pkg(
    c("if (rlang::is_installed('dplyr')) {", "  dplyr::filter(x)", "}"),
    extra = "Suggests: dplyr, rlang"
  )
  expect_equal(
    lab_suggested_in_examples(pkg, verbose = FALSE)$issues,
    "f.Rd: uses Suggested package 'rlang' in \\examples without a guard"
  )
})

test_that("lab_suggested_in_examples(): recommends a guard from base R", {
  pkg <- rd_pkg("dplyr::filter(x)", extra = "Suggests: dplyr")
  out <- paste(cli::cli_fmt(lab_suggested_in_examples(pkg)), collapse = "\n")
  expect_match(
    out,
    "Treatment: Guard the use with `if (requireNamespace(\"pkg\", quietly = TRUE))`",
    fixed = TRUE
  )
  expect_no_match(out, "rlang", fixed = TRUE)
})

test_that("lab_suggested_in_examples(): `if (require('pkg'))` IS the sanctioned guard", {
  # Writing R Extensions sanctions exactly this for conditional Suggests use in
  # examples. The old guard recognised only requireNamespace(), and only quoted,
  # while the USE pattern matched require() -- so the guard was the violation.
  pkg <- rd_pkg(
    c('if (require("chron")) {', "  tt <- as.chron('2000-01-01')", "}"),
    extra = "Suggests: chron"
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): an @examplesIf naming the package is a guard", {
  # roxygen compiles it to \dontshow{if (COND) ...}. cli asks through its own
  # `cli:::has_packages(c("htmltools"))`.
  pkg <- rd_pkg(
    c(
      "\\dontshow{if (cli:::has_packages(c(\"htmltools\"))) \\{ # examplesIf}",
      "htmltools::html_print(page)",
      "\\dontshow{\\} # examplesIf}"
    ),
    extra = "Suggests: htmltools"
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): an @examplesIf for another package is no guard", {
  # The structure used to be the guard whatever it asked, and so did the word
  # examplesIf anywhere in the example.
  pkg <- rd_pkg(
    c(
      "\\dontshow{if (requireNamespace(\"tidyr\", quietly = TRUE)) (if (getRversion() >= \"3.4\") withAutoprint else force)(\\{ # examplesIf}",
      "dplyr::filter(x)",
      "\\dontshow{\\}) # examplesIf}"
    ),
    extra = "Suggests: dplyr, tidyr"
  )
  expect_equal(
    lab_suggested_in_examples(pkg, verbose = FALSE)$issues,
    "f.Rd: uses Suggested package 'dplyr' in \\examples without a guard"
  )
})

test_that("lab_suggested_in_examples(): a guard for another package is no guard", {
  pkg <- rd_pkg(
    c("if (requireNamespace('dplyrExtra', quietly = TRUE)) {", "  dplyr::filter(x)", "}"),
    extra = "Suggests: dplyr, dplyrExtra"
  )
  expect_false(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): a guard that does not enclose the use is no guard", {
  pkg <- rd_pkg(
    c("if (requireNamespace('dplyr', quietly = TRUE)) x <- 1", "dplyr::filter(x)"),
    extra = "Suggests: dplyr"
  )
  expect_false(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): a guard in a comment or a string is no guard", {
  pkg <- rd_pkg(
    c(
      "# if (requireNamespace('dplyr')) -- @examplesIf",
      "message('requireNamespace(\"dplyr\")')",
      "dplyr::filter(x)"
    ),
    extra = "Suggests: dplyr"
  )
  expect_false(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): a package named in a comment or a string is not used", {
  pkg <- rd_pkg(
    c(
      "# library(dplyr) gives a faster filter()",
      "message('see dplyr::filter() for more')",
      "% dplyr::filter(x) in an Rd comment",
      "x <- subset(df, y > 1)"
    ),
    extra = "Suggests: dplyr"
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_suggested_in_examples(): a package whose name starts with a Suggests is another package", {
  pkg <- rd_pkg(
    c("library(dplyrExtra)", "dplyrExtra::go()"),
    extra = "Suggests: dplyr"
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

# Test lab_commented_examples() ----

test_that("lab_commented_examples(): does not flag prose comments", {
  cases <- list(
    # The old rule was "a comment containing an open paren", which flags English.
    # All 41 comment lines across the 9 Rd files this fired on in the wild were
    # prose; not one was a disabled call. The first two lines are cbcTools'.
    "prose with parens" = c(
      "# Simulate random choices (default)",
      "# (Columns are attributes, rows are alternatives)",
      "# Example 2: Named categorical priors (more explicit)",
      "foo()"
    ),
    "short note" = c("# Prepare data", "x <- 1")
  )
  for (case in names(cases)) {
    pkg <- rd_pkg(cases[[case]])
    expect_true(lab_commented_examples(pkg, verbose = FALSE)$passed, label = case)
  }
})

test_that("lab_commented_examples(): flags an \\examples block that runs nothing", {
  cases <- list(
    # The real defect: every line that would demonstrate the function is
    # commented out, so the example block executes nothing at all.
    "every call commented out" = c("# foo(slow = TRUE)", "# foo()"),
    # A commented-out call is only a defect when it is ALL the example has. Beside
    # live code it is illustration, which is why the live `actual_call()` this
    # fixture used to carry made it a false positive.
    "a lone commented call" = "# my_function(x)   # the only 'example' here"
  )
  for (case in names(cases)) {
    pkg <- rd_pkg(cases[[case]])
    res <- lab_commented_examples(pkg, verbose = FALSE)
    expect_false(res$passed, label = case)
    expect_match(res$issues, "runs nothing", all = FALSE, label = case)
  }
})

test_that("lab_commented_examples(): names \\examples{} with its braces", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "foo.Rd" = c(
        "\\name{foo}", "\\alias{foo}", "\\title{Foo}", "\\description{d}",
        "\\value{x}", "\\examples{", "# foo()", "}"
      )
    )
  )
  out <- paste(cli::cli_fmt(lab_commented_examples(pkg)), collapse = "\n")
  expect_match(out, "`\\examples{}` blocks that run nothing", fixed = TRUE)

  writeLines(
    c("\\name{foo}", "\\alias{foo}", "\\title{Foo}", "\\description{d}",
      "\\value{x}", "\\examples{", "foo()", "}"),
    file.path(pkg, "man", "foo.Rd")
  )
  out <- paste(cli::cli_fmt(lab_commented_examples(pkg)), collapse = "\n")
  expect_match(out, "Every `\\examples{}` block runs something", fixed = TRUE)
})

test_that("lab_commented_examples(): allows a comment alongside live code", {
  # surveydown's examples comment out the server and .qmd snippets that belong in
  # the USER's files, then call sd_create_survey() for real. That is illustration,
  # not a disabled example, and flagging it flagged the docs for doing their job.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "foo.Rd" = c(
        "\\name{foo}",
        "\\alias{foo}",
        "\\title{Foo}",
        "\\usage{foo()}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "# Put this in your own app.R:",
        "# server <- function(input, output) {",
        "#   foo(reactive = TRUE)",
        "# }",
        "foo()",
        "}"
      )
    )
  )
  expect_true(lab_commented_examples(pkg, verbose = FALSE)$passed)
})

# Test lab_unexported_example_ns() ----

test_that("lab_unexported_example_ns(): flags a bare call to an unexported topic", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(add)", file.path(pkg, "NAMESPACE"))
  write_unexported_rd(pkg, "helper(1)")

  res <- lab_unexported_example_ns(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "helper", all = FALSE)
})

test_that("lab_unexported_example_ns(): accepts an example that runs no bare call to the unexported topic", {
  examples <- c(
    # Qualified with :::.
    ":::" = "pkg:::helper(1)",
    # \dontrun{} is never executed, so a bare call there cannot fail. R CMD check
    # would not run it either.
    "\\dontrun" = "\\dontrun{helper(1)}",
    # The exact false positive the AST rewrite exists to prevent.
    "comment or string" = paste(
      "# you could call helper(1) yourself",
      "msg <- \"helper(2)\"",
      sep = "\n"
    ),
    # `helper` as a value, never invoked, is not a namespace problem.
    "same-named value" = "x <- list(helper = 1)"
  )
  for (case in names(examples)) {
    pkg <- make_temp_dir()
    write_pkg(pkg)
    writeLines("export(add)", file.path(pkg, "NAMESPACE"))
    write_unexported_rd(pkg, examples[[case]])
    expect_true(lab_unexported_example_ns(pkg, verbose = FALSE)$passed, label = case)
  }
})

test_that("lab_unexported_example_ns(): reads an exported [ method (#18)", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "reproclass <- function(x) structure(x, class = \"reproclass\")",
      "`[.reproclass` <- function(x, i, ...) reproclass(NextMethod())"
    )
  )
  writeLines(
    c("S3method(\"[\", reproclass)", "export(reproclass)"),
    file.path(pkg, "NAMESPACE")
  )
  write_operator_rd(pkg, "[.reproclass", "r <- reproclass(1:5); r[2:3]")

  res <- NULL
  expect_no_warning(res <- lab_unexported_example_ns(pkg, verbose = FALSE))
  expect_true(res$passed)
})

test_that("lab_unexported_example_ns(): reads unexported operator methods", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(add)", file.path(pkg, "NAMESPACE"))
  write_operator_rd(
    pkg,
    c("[.cls", "[[.cls", "$.cls", "+.cls", "==.cls"),
    "x[1]; x[[1]]; x$a; x + x; x == x"
  )

  res <- NULL
  expect_no_warning(res <- lab_unexported_example_ns(pkg, verbose = FALSE))
  expect_true(res$passed)
})

test_that("lab_unexported_example_ns(): does not flag an exported topic", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(helper)", file.path(pkg, "NAMESPACE"))
  write_unexported_rd(pkg, "helper(1)")

  expect_true(
    lab_unexported_example_ns(pkg, verbose = FALSE)$passed
  )
})

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

test_that("lab_unexported_example_ns(): a multi-line export( block is read in full", {
  # digest/NAMESPACE. The line-wise regex returned exactly one entry -- the string
  # "AES," -- when the truth is nine exports, so digest::digest(), the package's
  # flagship function, was reported as unexported. It explains 121 of the 831.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "export(AES,",
      "       digest,",
      "       digest2int,",
      "       getVDigest,",
      "       hmac)"
    ),
    file.path(pkg, "NAMESPACE")
  )
  dir.create(file.path(pkg, "man"), showWarnings = FALSE)
  for (nm in c("digest", "hmac", "AES")) {
    writeLines(
      c(
        paste0("\\name{", nm, "}"),
        paste0("\\alias{", nm, "}"),
        "\\title{t}",
        "\\description{d}",
        "\\value{x}",
        paste0("\\examples{", nm, "(1)}")
      ),
      file.path(pkg, "man", paste0(nm, ".Rd"))
    )
  }
  expect_true(
    lab_unexported_example_ns(pkg, verbose = FALSE)$passed
  )
})

# Test lab_donttest_vs_dontrun() ----

test_that("lab_donttest_vs_dontrun(): leaves slow code that ALSO cannot run", {
  # \dontrun{ Sys.sleep(60); download.file(...) } is slow *and* network-bound.
  # Telling the author to move it to \donttest{} is telling them to hand CRAN an
  # example CRAN then executes, on a machine with no network. Only the file that
  # is slow and nothing else may be reported, so assert the exact issue count --
  # a bare "at least one issue" would not notice the second file being dragged in.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "slow_only.Rd" = c(
        "\\name{slow_only}",
        "\\alias{slow_only}",
        "\\title{s}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "\\dontrun{",
        "  Sys.sleep(60)",
        "}",
        "}"
      ),
      "slow_and_network.Rd" = c(
        "\\name{slow_and_network}",
        "\\alias{slow_and_network}",
        "\\title{n}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "\\dontrun{",
        "  Sys.sleep(60)",
        "  download.file('https://example.com/big.zip', tempfile())",
        "}",
        "}"
      )
    )
  )
  res <- lab_donttest_vs_dontrun(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
  expect_match(res$issues, "^slow_only\\.Rd: uses \\\\dontrun\\{\\} for slow code")
})

test_that("lab_donttest_vs_dontrun(): names both wrappers with their braces", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "slow.Rd" = c(
        "\\name{slow}", "\\title{slow}", "\\value{1}",
        "\\examples{", "\\dontrun{", "Sys.sleep(60)", "}", "}"
      )
    )
  )
  out <- paste(cli::cli_fmt(lab_donttest_vs_dontrun(pkg)), collapse = "\n")
  expect_match(
    out,
    "Some `\\dontrun{}` blocks should be `\\donttest{}`",
    fixed = TRUE
  )
  expect_match(out, "Slow-only code belongs in `\\donttest{}`", fixed = TRUE)

  writeLines(
    c("\\name{slow}", "\\title{slow}", "\\value{1}", "\\examples{", "slow()", "}"),
    file.path(pkg, "man", "slow.Rd")
  )
  out <- paste(cli::cli_fmt(lab_donttest_vs_dontrun(pkg)), collapse = "\n")
  expect_match(out, "`\\dontrun{}` use is appropriate", fixed = TRUE)
})

test_that("lab_donttest_vs_dontrun(): leaves slow code that needs a Suggested package", {
  # R CMD check --as-cran runs \\donttest{}, so moving this block there would
  # report it under suggested_in_examples.
  pkg <- rd_pkg(
    c("\\dontrun{", "Sys.sleep(60)", "library(dplyr)", "}"),
    extra = "Suggests: dplyr"
  )
  expect_true(lab_donttest_vs_dontrun(pkg, verbose = FALSE)$passed)
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("lab_donttest_vs_dontrun(): still advises when the Suggested use is safe to move", {
  # Guarded inside the block, a recommended package, or outside the block
  # altogether: moving the block creates no new finding.
  for (example in list(
    c(
      "\\dontrun{",
      "Sys.sleep(60)",
      "if (requireNamespace('dplyr', quietly = TRUE)) dplyr::filter(x)",
      "}"
    ),
    c("\\dontrun{", "Sys.sleep(60)", "MASS::fractions(0.5)", "}"),
    c("dplyr::filter(x)", "\\dontrun{", "Sys.sleep(60)", "}")
  )) {
    pkg <- rd_pkg(example, extra = "Suggests: dplyr, MASS")
    expect_equal(
      lab_donttest_vs_dontrun(pkg, verbose = FALSE)$issues,
      "f.Rd: uses \\dontrun{} for slow code; prefer \\donttest{}",
      label = paste(example, collapse = " ")
    )
  }
})

test_that("lab_donttest_vs_dontrun(): judges each \\dontrun{} block on its own", {
  # A block that needs dplyr stays in \dontrun{}, but a slow block beside it can
  # still move.
  for (example in list(
    c("\\dontrun{", "library(dplyr)", "}", "\\dontrun{", "Sys.sleep(60)", "}"),
    c(
      "\\dontrun{", "Sys.sleep(1)", "library(dplyr)", "}",
      "\\dontrun{", "Sys.sleep(60)", "}"
    )
  )) {
    pkg <- rd_pkg(example, extra = "Suggests: dplyr")
    expect_equal(
      lab_donttest_vs_dontrun(pkg, verbose = FALSE)$issues,
      "f.Rd: uses \\dontrun{} for slow code; prefer \\donttest{}",
      label = paste(example, collapse = " ")
    )
  }

  # The slow block is the one that needs dplyr, so there is nothing to move.
  pkg <- rd_pkg(
    c("\\dontrun{", "Sys.sleep(60)", "library(dplyr)", "}", "\\dontrun{", "plot(1)", "}"),
    extra = "Suggests: dplyr"
  )
  expect_true(lab_donttest_vs_dontrun(pkg, verbose = FALSE)$passed)
})

test_that("lab_donttest_vs_dontrun(): accepts \\dontrun for justified cases", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "net.Rd" = c(
        "\\name{net}",
        "\\title{net}",
        "\\value{1}",
        "\\examples{",
        "\\dontrun{",
        "# Requires API token",
        "download.file('https://example.com/', '/tmp/x')",
        "}",
        "}"
      )
    )
  )
  res <- lab_donttest_vs_dontrun(pkg, verbose = FALSE)
  expect_true(res$passed)
})

# Test lab_print_cat_usage() ----

test_that("lab_print_cat_usage(): ignores cat in strings and verbosity-gated", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "msg <- 'cat(...)'", # cat inside a string
      "f <- function(verbose) if (verbose) cat('x')", # gated on verbosity
      "g <- function(quiet) { if (!quiet) cat('y'); invisible() }"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)

  # A function that COMPUTES and also prints is the leak: the caller wanted the
  # value and got noise too. (A function that only prints is an emitter, and
  # cli::cat_line() is exactly that; see the emitter test below.)
  pkg2 <- make_temp_dir()
  write_pkg(
    pkg2,
    r_code = c(
      "f <- function(x) {",
      "  cat('always')",
      "  compute(x)",
      "}"
    )
  )
  expect_false(lab_print_cat_usage(pkg2, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): recognises every verbosity-flag stem", {
  # The two fixtures in the test above never reach the whitelist: both bodies are
  # already exempt as functions with no visible return, so the guard is never
  # consulted. These bodies end in `compute(x)`, a visible return, which is the
  # only shape that gets as far as the flag-name test. One fixture per stem, so
  # dropping any single name from the list (which is how geoR's `messages.screen`
  # came to be reported 117 times) fails here.
  stems <- c(
    "verbose", "quiet", "silent", "debug", "trace", "message", "msg",
    "print", "report", "note", "info", "show", "echo", "progress",
    "log", "warn", "output"
  )
  for (stem in stems) {
    flag <- paste0(stem, "_flag")
    pkg <- make_temp_dir()
    write_pkg(
      pkg,
      r_code = c(
        sprintf("f <- function(x, %s = TRUE) {", flag),
        sprintf("  if (%s) cat('working')", flag),
        "  compute(x)",
        "}"
      )
    )
    expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed, info = stem)
  }

  # The control: the same shape gated on something that is not an output flag is
  # still the unsuppressable output the check is for.
  pkg_bad <- make_temp_dir()
  write_pkg(
    pkg_bad,
    r_code = c(
      "f <- function(x, n) {",
      "  if (n > 0) cat('working')",
      "  compute(x)",
      "}"
    )
  )
  res <- lab_print_cat_usage(pkg_bad, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

test_that("lab_print_cat_usage(): exempts a pure emitter with a single cat()", {
  # cli::cat_line(). Its whole documented job is to put one line on the screen:
  # it formats its arguments and emits them, and does nothing else. An earlier
  # rule demanded two or more output calls before granting the exemption, which
  # reported cat_line() and 31 other cli functions.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "cat_line <- function(..., col = NULL, file = stdout()) {",
      "  out <- paste0(..., collapse = '\n')",
      "  out <- apply_style(out, col)",
      "  cat(out, '\n', sep = '', file = file, append = TRUE)",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): exempts cat/print in S3 print/format (#6)", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "print.myclass <- function(x, ...) {",
      "  cat(\"Object of class 'myclass'\\n\")",
      "  cat(\"Value:\", x$value, \"\\n\")",
      "  invisible(x)",
      "}",
      "format.myclass <- function(x, ...) {",
      "  cat(format(x$value))",
      "  invisible(x)",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): still flags cat beside an exempt method", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "print.myclass <- function(x, ...) cat('exempt')",
      "analyze <- function(data) {",
      "  cat('always flagged')",
      "  fit(data)", # computes AND prints: the real leak
      "}"
    )
  )
  res <- lab_print_cat_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L) # only the ordinary function's cat
})

test_that("lab_print_cat_usage(): flags output from a value-returning fn", {
  # The genuine violation: the caller wants the value and gets the noise too.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "estimate <- function(data) {",
      "  cat('Fitting model...\\n')",
      "  fit_model(data)",
      "}"
    )
  )
  res <- lab_print_cat_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("lab_print_cat_usage(): exempts a fn with no visible return value", {
  # WRE permits console output when producing it IS the function's purpose. A
  # function ending in invisible(), an output call, or a loop is called for its
  # side effect, so the output is the point (logitr::statusCodes,
  # cbcTools::cbc_suggest_priors).
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "status_codes <- function() {",
      "  codes <- get_codes()",
      "  cat('Status codes:\\n')",
      "  for (i in seq_along(codes)) cat(i, ': ', codes[i], '\\n', sep = '')",
      "}",
      "",
      "suggest_priors <- function(x) {",
      "  out <- compute(x)",
      "  cat('Copy-paste this into your code:\\n')",
      "  cat(format(out), '\\n')",
      "  invisible(out)",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): exempts print() used as a file writer", {
  # officer's print.rpptx(x, target) SAVES the document. It writes no console
  # output at all (renderthis::to_pptx).
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "to_pptx <- function(png, output_file) {",
      "  doc <- build_doc(png)",
      "  print(doc, output_file)",
      "  output_file",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): still flags a plain console print()", {
  # Guard against the writer exemption swallowing an ordinary console print.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "summarise_it <- function(x) {",
      "  print(x)",
      "  compute(x)",
      "}"
    )
  )
  expect_false(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): exempts output before a yesno() prompt", {
  # CRAN's rule ends "(except for print, summary, interactive functions)".
  # surveydown cat()s a file tree, then asks "Overwrite all existing files?".
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "create_survey <- function(files) {",
      "  cat('The following files already exist:\\n')",
      "  cat(format_tree(files), '\\n')",
      "  ok <- yesno('Overwrite all existing files?')",
      "  if (!ok) stop('Aborted.')",
      "  scaffold(files)",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): exempts output guarded by interactive()", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "run <- function(x) {",
      "  if (interactive()) cat('working...\\n')",
      "  compute(x)",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): does NOT flag a void function (known miss)", {
  # `result <- compute(x); cat("Done!\n")` IS a leftover completion notice rather
  # than a report, and we no longer flag it. This test exists to pin that as a
  # deliberate decision rather than an accident.
  #
  # The rule was narrowed to its citable core: flag output only from a function that
  # ALSO hands a value back, because that is the harm the CRAN reviewer request
  # actually describes ("information messages ... that cannot easily be suppressed"
  # reaching a caller who wanted a value). A function with no visible return was
  # called for its side effect, and the output IS its contract.
  #
  # The wider rule cost a false-positive rate we could not defend across 196 CRAN
  # packages, on a convention that appears nowhere in the CRAN Repository Policy.
  # Precision is the only thing this package sells.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "process <- function(x) {",
      "  result <- compute(x)",
      "  cat('Done!\\n')",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): exempts an S4 show method and delegates", {
  # setMethod("show", ...) is S4's print method, and cat() is the required idiom
  # inside one. The S3 exemption keys off a NAME PREFIX on a top-level assignment,
  # so it was blind to S4 entirely: distrMod was reported 118 times for its show
  # methods. DBI registers its method BY NAME, which needs handling too.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      # inline, as distrMod writes it
      "setMethod('show', 'ParamFamParameter', function(object) {",
      "  cat('An object of class\\n')",
      "  cat('name:', object@name, '\\n')",
      "})",
      "",
      # registered by name, as DBI writes it
      "show_connection <- function(object) {",
      "  cat('<', is(object)[1], '>\\n', sep = '')",
      "}",
      "show_DBIConnection <- function(object) {",
      "  show_connection(object)",
      "  invisible(NULL)",
      "}",
      "setMethod('show', 'DBIConnection', show_DBIConnection)"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): a treatment line renders its markup", {
  # The fixture has to FAIL the check: a passing one emits the success alert and
  # never reaches the treatment line, so the markup assertion would be checked
  # against the wrong message. `f` returns a value, so its print() is a leak
  # rather than an exempt console reporter.
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c("a.R" = "f <- function(x) {\n  print(x)\n  x + 1\n}"))
  expect_false(lab_print_cat_usage(pkg, verbose = FALSE)$passed)

  out <- cli::cli_fmt(lab_print_cat_usage(pkg, verbose = TRUE))
  txt <- paste(out, collapse = "\n")
  expect_match(txt, "with `message()`", fixed = TRUE)
  expect_false(grepl("{.code", txt, fixed = TRUE))
})

test_that("lab_print_cat_usage(): a console reporter is not unsuppressable output", {
  # logitr/R/utils.R statusCodes(), cbcTools/R/priors.R cbc_suggest_priors().
  # Both exist to print. WRE permits console output when producing it IS the
  # function's purpose.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "statusCodes <- function() {",
      "  codes <- getStatusCodes()",
      "  cat('Status codes:', '\\n', sep = '')",
      "  for (i in seq_len(nrow(codes))) cat(codes$code[i], ': ', codes$msg[i], '\\n', sep = '')",
      "}",
      "",
      "cbc_suggest_priors <- function(profiles) {",
      "  suggestions <- compute_priors(profiles)",
      "  cat('========================================\\n')",
      "  cat('Copy-paste this into your code:\\n\\n')",
      "  cat('priors <- cbc_priors(\\n')",
      "  invisible(suggestions)",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): print(doc, target) writes a file, it does not print", {
  # renderthis/R/pptx.R to_pptx(). officer's print.rpptx(x, target) SAVES.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "to_pptx <- function(png, output_file) {",
      "  doc <- officer::read_pptx()",
      "  print(doc, output_file)",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): output that sets up a user prompt is interactive output", {
  # surveydown/R/util.R sd_create_survey(). CRAN's rule ends "(except for print,
  # summary, interactive functions)".
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "sd_create_survey <- function(existing_files, ask = TRUE) {",
      "  if (ask && length(existing_files) > 0) {",
      "    cat('The following files already exist:\\n\\n')",
      "    cat(format_file_tree(existing_files), '\\n\\n', sep = '')",
      "    overwrite_all <- yesno('Overwrite all existing files?')",
      "    if (!overwrite_all) stop('Operation aborted by the user.')",
      "  }",
      "  scaffold(existing_files)",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): printing during a computation is still caught", {
  # The rule the exemptions must never swallow: the caller wants a value and gets
  # the noise as well.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "estimate <- function(data) {",
      "  cat('Fitting model...\\n')",
      "  fit_model(data)",
      "}"
    )
  )
  expect_false(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): obj$cat() is a method call, not base::cat()", {
  # cli is built on objects with a `$cat` member, and was reported 25 times for
  # calling its own method. R's parser emits a SYMBOL_FUNCTION_CALL for the member
  # name, so //SYMBOL_FUNCTION_CALL[text()='cat'] matches it. tf_usage has always
  # guarded against this for `df$T`; the call detectors never did.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "clii__cat_ln <- function(app, lines) {",
      "  app$cat(paste0(lines, '\\n'))",
      "  self$print(lines)",
      "  invisible(app)",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): base::cat() is still matched", {
  # The member-access guard must not let a namespaced call slip through.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x) {",
      "  base::cat('leaking\\n')",
      "  compute(x)",
      "}"
    )
  )
  expect_false(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): an output flag named `messages` is a verbosity gate", {
  # geoR gates every message on `messages.screen`. checktor's verbosity whitelist
  # was 8 hardcoded stems with no "message" among them, so all 117 of geoR's
  # correctly-guarded cat() calls were reported.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "krige <- function(x, messages.screen = TRUE) {",
      "  if (messages.screen) cat('krige.conv: computing\\n')",
      "  compute(x)",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): a method defined with a QUOTED name is still a method", {
  # R's classic idiom: `"print.summary.xvalid" <- function(x, ...)`. The LHS parses
  # as STR_CONST, not SYMBOL, so every SYMBOL-only XPath was blind to it. geoR
  # writes 201 of its 208 top-level functions this way.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      '"print.summary.xvalid" <- function(x, ...) {',
      "  res <- rbind(x$error, x$std.error)",
      "  print(res)",
      "  invisible()",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
  expect_equal(
    enclosing_function_name(
      xml2::xml_find_first(
        read_r_xml(pkg)[[1]]$xml,
        "//SYMBOL_FUNCTION_CALL[text()='print']"
      )
    ),
    "print.summary.xvalid"
  )
})

test_that("lab_print_cat_usage(): an if/else of printers is a printer", {
  # knitr's normal_print = function(x, ...) if (isS4(x)) methods::show(x) else print(x)
  # An `if` evaluates to the branch TAKEN, so it is side-effect-only when every
  # branch is. Reading ./expr[1] inspects the CONDITION instead, so this pure
  # dispatcher was reported as leaking output.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "normal_print = function(x, ...) {",
      "  if (isS4(x)) methods::show(x) else print(x)",
      "}"
    )
  )
  expect_true(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_print_cat_usage(): an if/else that RETURNS a value still leaks", {
  # The branch rule must not swallow the real thing.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "estimate <- function(x) {",
      "  cat('fitting\\n')",
      "  if (x > 0) fit_a(x) else fit_b(x)",
      "}"
    )
  )
  expect_false(lab_print_cat_usage(pkg, verbose = FALSE)$passed)
})

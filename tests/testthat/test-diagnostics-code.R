# A test that names a CRAN package reproduces a false positive or a missed
# finding from that package's real sources, so a regression fails here first.

# Test lab_tf_usage() ----

test_that("lab_tf_usage(): flags bare T/F (including leading position)", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "T", # leading T - missed by old regex
      "  F",
      "x <- T",
      "fn <- function() F"
    )
  )
  res <- lab_tf_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 4L)
})

test_that("lab_tf_usage(): ignores T/F inside strings and comments", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "x <- 'T cells and F-stats'",
      "# T - reminder",
      "# F-statistic",
      'msg <- "T"',
      "y <- TRUE"
    )
  )
  res <- lab_tf_usage(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("lab_tf_usage(): ignores TRUE/FALSE and words containing T or F", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "x <- TRUE",
      "y <- FALSE",
      "transform <- function() NULL",
      "field <- 1"
    )
  )
  res <- lab_tf_usage(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("lab_tf_usage(): T/F inside expression()/substitute() are language tokens", {
  # EL builds plotmath labels: substitute(expression(F[a] - F[b]), ...). That F is
  # the cumulative distribution function, not FALSE.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "label <- function(call) {",
      "  substitute(expression(F[a] - F[b]), list(a = call$Y, b = call$X))",
      "}",
      "lab2 <- function() quote(T + F)"
    )
  )
  expect_true(lab_tf_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_tf_usage(): a real bare T/F is still flagged", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() mean(x, na.rm = T)")
  expect_false(lab_tf_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_tf_usage(): `na.rm = T` is flagged, `f(T = 1)` is not", {
  # A FALSE NEGATIVE, not a false positive. An argument NAME parses as SYMBOL_SUB,
  # so //SYMBOL never matched `f(T = 1)` anyway; the guard that claimed to exclude
  # it actually excluded the argument VALUE, making `mean(x, na.rm = T)` -- the
  # commonest bare T in R -- unreportable.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x) mean(x, na.rm = T)",
      "g <- function(x) sd(x, na.rm = F)"
    )
  )
  res <- lab_tf_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)

  # An argument literally named T is not a bare logical.
  ok <- make_temp_dir()
  write_pkg(ok, r_code = "h <- function() transform(df, T = 1)")
  expect_true(lab_tf_usage(ok, verbose = FALSE)$passed)
})

# Test lab_seed_setting() ----

test_that("lab_seed_setting(): flags set.seed(1) but not set.seed(seed)", {
  pkg_bad <- make_temp_dir()
  write_pkg(pkg_bad, r_code = "f <- function() { set.seed(1); 1 }")
  expect_false(lab_seed_setting(pkg_bad, verbose = FALSE)$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(
    pkg_ok,
    r_code = c(
      "f <- function(seed = NULL) {",
      "  if (!is.null(seed)) set.seed(seed)",
      "  runif(1)",
      "}"
    )
  )
  expect_true(lab_seed_setting(pkg_ok, verbose = FALSE)$passed)
})

test_that("lab_seed_setting(): flags a seed under a live condition", {
  # The dead-code carve-out is narrow on purpose: only `if (FALSE)` can never run.
  # A seed under any condition a caller can satisfy DOES reach the user's RNG
  # state, so it stays a finding.
  pkg_live <- make_temp_dir()
  write_pkg(pkg_live, r_code = "f <- function(x) { if (x > 0) set.seed(123); x }")
  expect_false(lab_seed_setting(pkg_live, verbose = FALSE)$passed)

  pkg_dead <- make_temp_dir()
  write_pkg(pkg_dead, r_code = "f <- function(x) { if (FALSE) set.seed(123); x }")
  expect_true(lab_seed_setting(pkg_dead, verbose = FALSE)$passed)
})

test_that("lab_seed_setting(): set.seed() in dead code cannot touch the RNG", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x) {",
      "  if (FALSE) set.seed(123)",
      "  x",
      "}"
    )
  )
  expect_true(lab_seed_setting(pkg, verbose = FALSE)$passed)
})

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
  expect_match(txt, "Treatment: Use `message()`", fixed = TRUE)
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

# Test lab_option_changes() ----

test_that("lab_option_changes(): recognises on.exit and withr::local_*", {
  pkg_ok <- make_temp_dir()
  write_pkg(
    pkg_ok,
    r_code = c(
      "f <- function() {",
      "  op <- options(warn = 2)",
      "  on.exit(options(op))",
      "  invisible()",
      "}",
      "g <- function() {",
      "  withr::local_options(scipen = 999)",
      "  invisible()",
      "}"
    )
  )
  expect_true(lab_option_changes(pkg_ok, verbose = FALSE)$passed)

  pkg_bad <- make_temp_dir()
  write_pkg(pkg_bad, r_code = "f <- function() options(scipen = 999)")
  expect_false(lab_option_changes(pkg_bad, verbose = FALSE)$passed)
})

test_that("lab_option_changes(): exempts a factored on.exit restore handler", {
  # paintr's shape: the restore is a helper the caller registers with on.exit(),
  # so its own par() writes ARE the restore even though its body has no on.exit.
  pkg_ok <- make_temp_dir()
  write_pkg(
    pkg_ok,
    r_code = c(
      "reset_par <- function(op) par(cex = op$cex, mar = op$mar)",
      "draw <- function() {",
      "  op <- par(no.readonly = TRUE)",
      "  on.exit(reset_par(op))",
      "  par(mar = c(2, 2, 2, 2))",
      "  plot(1)",
      "}"
    )
  )
  expect_true(lab_option_changes(pkg_ok, verbose = FALSE)$passed)

  # But a helper that is NOT registered with on.exit stays a genuine leak.
  pkg_bad <- make_temp_dir()
  write_pkg(
    pkg_bad,
    r_code = "set_margins <- function() par(mar = c(1, 1, 1, 1))"
  )
  expect_false(lab_option_changes(pkg_bad, verbose = FALSE)$passed)
})

test_that("lab_option_changes(): exempts a setter that returns the old value", {
  # options()/par()/setwd() return the previous value, so capturing it and
  # handing it back is the base R setter contract, not a leak.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "cfg <- function(x) {",
      "  old <- options(digits = x)",
      "  invisible(old)",
      "}"
    )
  )
  expect_true(lab_option_changes(pkg, verbose = FALSE)$passed)
})

test_that("lab_option_changes(): flags options() whose old value is dropped", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "leak <- function(x) {",
      "  options(digits = x)",
      "  invisible(NULL)",
      "}"
    )
  )
  res <- lab_option_changes(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

test_that("lab_option_changes(): options()/par() READS and RESTORES are not changes", {
  # withr/R/options.R:12 is `reset_options <- function(old) options(old)`. That is
  # withr's own CLEANUP function, and checktor reported it as an unrestored change.
  # zoo/R/xblocks.R reads plot coordinates with par("usr")[3].
  # A NAMED argument is what makes the call a write.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "reset_options <- function(old_options) options(old_options)", # restore
      "get_digits <- function() options('digits')", # read
      "plot_area <- function() par('usr')[3]", # read
      "bottom <- function(h) par('usr')[3] + h" # read
    )
  )
  expect_true(lab_option_changes(pkg, verbose = FALSE)$passed)
})

test_that("lab_option_changes(): a NAMED option argument is still flagged", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() options(scipen = 999)",
      "g <- function() par(mfrow = c(1, 2))"
    )
  )
  res <- lab_option_changes(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)
})

test_that("lab_option_changes(): a package's OWN option is its own state", {
  # data.table toggles `datatable.verbose`, cli sets `cli.*`, knitr sets `knitr.*`.
  # CRAN's concern is a package disturbing options that OTHER code depends on.
  pkg <- make_temp_dir()
  write_pkg(pkg, package = "data.table")
  writeLines(
    c(
      "f <- function(verbose) {",
      "  options(datatable.verbose = FALSE)",
      "  compute()",
      "}",
      "g <- function() options(scipen = 999)" # someone else's option: still flagged
    ),
    file.path(pkg, "R", "a.R")
  )
  res <- lab_option_changes(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L) # only the foreign option
})

test_that("lab_option_changes(): setwd() in a callr subprocess does not touch the session", {
  # aisdk runs `callr::r(function(code, wd) { setwd(wd); ... })`. The child process
  # exits and takes its working directory with it.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "run_isolated <- function(code, wd) {",
      "  callr::r(function(code_str, wd) {",
      "    setwd(wd)",
      "    options(warn = 2)",
      "    eval(parse(text = code_str))",
      "  }, args = list(code, wd))",
      "}"
    )
  )
  expect_true(lab_option_changes(pkg, verbose = FALSE)$passed)
})

test_that("lab_option_changes(): a bare setwd() in ordinary code is still flagged", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function(d) { setwd(d); read.csv('x') }")
  expect_false(lab_option_changes(pkg, verbose = FALSE)$passed)
})

# Test lab_home_writing() ----

test_that("lab_home_writing(): does NOT flag formula tildes", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "fit <- function(d) lm(y ~ x, data = d)",
      "f <- function(d) update(fit, . ~ . + z)",
      "g <- function() y ~ a + b"
    )
  )
  expect_true(lab_home_writing(pkg, verbose = FALSE)$passed)
})

test_that("lab_home_writing(): flags WRITES into the home directory", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      'f <- function(x) writeLines(x, "~/leaked.txt")',
      'g <- function(x) saveRDS(x, "~/.myapp/cache.rds")',
      'h <- function(x) write.csv(x, file = file.path(Sys.getenv("HOME"), "o.csv"))'
    )
  )
  res <- lab_home_writing(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 3L)
})

test_that("lab_home_writing(): knows the tabular and device writers too", {
  # The three fixtures above exercise writeLines/saveRDS/write.csv, three of the
  # forty entries in WRITE_FUNCTIONS. A device opened on a home path leaves a file
  # there exactly as write.table() does, so both ends of the list are pinned.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function(x) write.table(x, '~/o.tsv')",
      "b <- function() png('~/p.png')"
    )
  )
  res <- lab_home_writing(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)
  expect_match(res$issues, "write.table", all = FALSE, fixed = TRUE)
  expect_match(res$issues, "png", all = FALSE, fixed = TRUE)
})

test_that("lab_home_writing(): does not flag reads of the home path", {
  # The old check inspected only path.expand/normalizePath/file.path/Sys.getenv,
  # which are all reads: it flagged these while MISSING the writes above.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() path.expand('~')",
      "g <- function() Sys.getenv('HOME')",
      "h <- function() normalizePath('~')",
      "i <- function() file.path('~', 'data.csv')"
    )
  )
  expect_true(lab_home_writing(pkg, verbose = FALSE)$passed)
})

test_that("lab_home_writing(): a genuine write to the user's home is caught", {
  # The violation home_writing claimed to detect and did not: it inspected only
  # read functions (Sys.getenv, path.expand) and missed every actual write.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "leak <- function(x) writeLines(x, '~/leaked.txt')",
      "cache <- function(x) saveRDS(x, '~/.myapp/cache.rds')"
    )
  )
  expect_false(lab_home_writing(pkg, verbose = FALSE)$passed)
})

# Test lab_temp_cleanup() ----

test_that("lab_temp_cleanup(): is per-tempfile and requires nearby cleanup", {
  # Scope is package code under R/, NOT tests/. Scanning tests/ is what made this
  # report withr, fs, rlang, testthat and cli, the packages that handle temp files
  # most carefully of anyone.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "clean <- function() {",
      "  t1 <- tempfile()",
      "  writeLines('a', t1)",
      "  unlink(t1)",
      "}",
      "",
      "leaky <- function() {",
      "  t2 <- tempfile()",
      "  writeLines('b', t2)",
      "}"
    )
  )

  res <- lab_temp_cleanup(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L) # only the leaky one
})

test_that("lab_temp_cleanup(): ignores .Rd files (they are not R)", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "foo.Rd" = c(
        "\\name{foo}",
        "\\title{foo}",
        "\\examples{",
        "  t <- tempfile()",
        "  writeLines('x', t)",
        "}"
      )
    )
  )
  # No tests/ directory ⇒ nothing to inspect ⇒ passes.
  expect_true(lab_temp_cleanup(pkg, verbose = FALSE)$passed)
})

test_that("lab_temp_cleanup(): does not scan tests/, and is not a policy check", {
  # It reported withr, fs, rlang, testthat and cli -- the packages that handle temp
  # files most carefully of anyone -- for tempfile() calls in their TEST files.
  # CRAN's policy expressly PERMITS writing to the session temp directory, and
  # tempfile() lands inside tempdir(), which R removes at session end.
  expect_true(startsWith(tempfile(), tempdir())) # the premise, verified
  expect_equal(check_severity("temp_cleanup"), "opinion")

  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() 1")
  dir.create(file.path(pkg, "tests", "testthat"), recursive = TRUE)
  writeLines(
    "test_that('x', { p <- tempfile(); writeLines('a', p) })",
    file.path(pkg, "tests", "testthat", "test-thing.R")
  )
  expect_true(lab_temp_cleanup(pkg, verbose = FALSE)$passed)
})

test_that("lab_temp_cleanup(): a call in a DEFAULT ARGUMENT does not hide the function body", {
  # `ancestor::expr[parent::expr/FUNCTION][1]` was meant to name the body, but a
  # function's DEFAULT-VALUE exprs are children of the same node and match the same
  # predicate. For a call in a default, the nearest match was the default itself, so
  # the on.exit() in the real body was invisible. Broke option_changes, temp_cleanup
  # and sys_setenv alike.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x, p = tempfile()) {",
      "  on.exit(unlink(p))",
      "  writeLines(x, p)",
      "}"
    )
  )
  expect_true(lab_temp_cleanup(pkg, verbose = FALSE)$passed)
})

# Test lab_globalenv_mod() ----

test_that("lab_globalenv_mod(): flags a <<- that binds nowhere", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "leaky <- function() {",
      "  undeclared_global <<- 1",
      "  invisible(NULL)",
      "}"
    )
  )
  res <- lab_globalenv_mod(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

test_that("lab_globalenv_mod(): exempts closures and package-level caches", {
  # `<<-` walks the enclosing environments and assigns in the first frame where
  # the name is already bound; it only reaches .GlobalEnv when the name is bound
  # nowhere else. Flagging every `<<-` false-positives on both correct idioms.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      ".cache <- NULL",
      "memoise <- function(x) { .cache <<- x; .cache }", # package-level cache
      "validate <- function(d) {",
      "  results <- list(errors = character(0))",
      "  add_error <- function(msg) results$errors <<- c(results$errors, msg)",
      "  add_error('boom')",
      "  results",
      "}",
      "reader <- function(nm) exists(nm, envir = globalenv())" # a pure READ
    )
  )
  expect_true(lab_globalenv_mod(pkg, verbose = FALSE)$passed)
})

test_that("lab_globalenv_mod(): reads the right-hand superassignment too", {
  # `v ->> x` is the same write as `x <<- v`, with the target on the OTHER side of
  # the operator. Nothing else in the suite writes one, so this is the only cover
  # superassign_target()'s RIGHT_ASSIGN branch has.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "leaky <- function() {",
      "  1 ->> undeclared_global",
      "  invisible(NULL)",
      "}"
    )
  )
  res <- lab_globalenv_mod(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
  expect_match(res$issues, "undeclared_global", all = FALSE, fixed = TRUE)
})

test_that("lab_globalenv_mod(): a memoisation cache is not a .GlobalEnv write", {
  # `<<-` binds in the first ENCLOSING frame where the name exists, reaching
  # .GlobalEnv only when it is bound nowhere. A package-level cache never is.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      ".cache <- NULL",
      "get_data <- function() {",
      "  if (is.null(.cache)) .cache <<- expensive_computation()",
      "  .cache",
      "}"
    )
  )
  expect_true(lab_globalenv_mod(pkg, verbose = FALSE)$passed)
})

test_that("lab_globalenv_mod(): `<<-` inside local() binds in the local() env, not .GlobalEnv", {
  # curl's make_option_type_table <- local({ cache <- NULL; function() ... }).
  # local() is a CALL, not a function, so an ancestor::expr[FUNCTION] search walks
  # straight past the scope that holds the binding. curl, cli and rlang all do this.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "make_table <- local({",
      "  cache <- NULL",
      "  function() {",
      "    if (is.null(cache)) cache <<- compute()",
      "    cache",
      "  }",
      "})"
    )
  )
  expect_true(lab_globalenv_mod(pkg, verbose = FALSE)$passed)
})

test_that("lab_globalenv_mod(): an `=` assignment is an assignment", {
  # knitr binds `defaults = value` in a closure factory and updates it with
  # `defaults <<- ...` from a nested function: a textbook closure that never
  # approaches .GlobalEnv. But `x = 1` parses as expr_or_assign_or_help, not expr,
  # so every XPath of the form expr[EQ_ASSIGN] missed EVERY `=` assignment in R.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "new_defaults = function(value = list()) {",
      "  defaults = value",
      "  locked = FALSE",
      "  set = function(v) defaults <<- v",
      "  lock = function(status = TRUE) locked <<- status",
      "  list(set = set, lock = lock)",
      "}"
    )
  )
  expect_true(lab_globalenv_mod(pkg, verbose = FALSE)$passed)
})

test_that("lab_globalenv_mod(): `<<-` inside a Reference Class is field assignment", {
  # chapensk's setRefClass initialize() does `coeff <<- ...` to set its own field,
  # the documented RC idiom. 52 findings in one file. R6's active-binding setters
  # use `<<-` the same way.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "CollisionIntegral <- setRefClass('CollisionIntegral',",
      "  fields = list(coeff = 'data.frame', A = 'numeric'),",
      "  methods = list(",
      "    initialize = function(l, s) {",
      "      coeff <<- subset(coefficients_ci, l == l & s == s)",
      "      A <<- coeff$A",
      "    }",
      "  ))"
    )
  )
  expect_true(lab_globalenv_mod(pkg, verbose = FALSE)$passed)
})

# Test lab_installed_packages() ----

test_that("lab_installed_packages(): flags the call but not the word", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "x <- 'installed.packages mentioned'", # in string ⇒ ignored
      "f <- function() installed.packages()"
    )
  )
  res <- lab_installed_packages(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

test_that("lab_installed_packages(): is quiet on the recommended idioms", {
  # The treatment line names requireNamespace() and find.package(); a package that
  # already took that advice must come back clean.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() requireNamespace('utils', quietly = TRUE)",
      "g <- function() find.package('utils')",
      "h <- function() utils::available.packages()"
    )
  )
  expect_true(lab_installed_packages(pkg, verbose = FALSE)$passed)
})

# Test lab_warn_option() ----

test_that("lab_warn_option(): finds warn = -1 in multi-arg and withr forms", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() options(scipen = 0, warn = -1)",
      "g <- function() withr::local_options(warn = -1)",
      "h <- function() options(",
      "  scipen = 999,",
      "  warn = -1",
      ")"
    )
  )
  res <- lab_warn_option(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 3L)
})

test_that("lab_warn_option(): only objects to -1, not to every warn = value", {
  # The rule is about SILENCING warnings for the rest of the session. `warn = 2`
  # turns them into errors and `options(warn = old)` puts the user's value back;
  # neither hides anything, so neither is a finding.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = "f <- function(old) { options(warn = 2); options(warn = old) }"
  )
  expect_true(lab_warn_option(pkg, verbose = FALSE)$passed)
})

# Test lab_software_install() ----

test_that("lab_software_install(): flags install.packages and install_*", {
  # `fine()` is the control: requireNamespace() is the conditional-Suggests idiom
  # Writing R Extensions prescribes, and it installs nothing. The count is exact so
  # that treating it as an install shows up here.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() install.packages('foo')",
      "g <- function() devtools::install_github('a/b')",
      "h <- function() remotes::install_local('.')",
      "fine <- function() requireNamespace('utils')"
    )
  )
  res <- lab_software_install(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 3L)
})

test_that("lab_software_install(): an install behind a consent prompt is consent", {
  # CRAN's objection is installing WITHOUT ASKING. rlang, devtools and usethis all
  # prompt first, which is the only way an install helper can exist at all.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "maybe_install <- function(pkg) {",
      "  if (yesno(paste('Install', pkg, '?'))) {",
      "    install.packages(pkg)",
      "  }",
      "}"
    )
  )
  expect_true(lab_software_install(pkg, verbose = FALSE)$passed)

  bad <- make_temp_dir()
  write_pkg(bad, r_code = "f <- function() install.packages('dplyr')")
  expect_false(lab_software_install(bad, verbose = FALSE)$passed)
})

# Test lab_sys_setenv() ----

test_that("lab_sys_setenv(): flags an env var that is never put back", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() Sys.setenv(MYVAR = '1')")
  res <- lab_sys_setenv(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

test_that("lab_sys_setenv(): accepts on.exit and local_envvar restores", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() {",
      "  old <- Sys.getenv('MYVAR')",
      "  on.exit(Sys.setenv(MYVAR = old))",
      "  Sys.setenv(MYVAR = '1')",
      "  invisible()",
      "}",
      "g <- function() withr::local_envvar(c(MYVAR = '1'))"
    )
  )
  expect_true(lab_sys_setenv(pkg, verbose = FALSE)$passed)
})

test_that("lab_sys_setenv(): flags naked Sys.setenv and accepts cleanup", {
  pkg_bad <- make_temp_dir()
  write_pkg(pkg_bad, r_code = "f <- function() Sys.setenv(FOO = 1)")
  expect_false(lab_sys_setenv(pkg_bad, verbose = FALSE)$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(
    pkg_ok,
    r_code = c(
      "f <- function() {",
      "  Sys.setenv(FOO = 1)",
      "  on.exit(Sys.unsetenv('FOO'))",
      "}",
      "g <- function() withr::local_envvar(c(BAR = 1))"
    )
  )
  expect_true(lab_sys_setenv(pkg_ok, verbose = FALSE)$passed)
})

test_that("lab_sys_setenv(): a setter that returns the captured state is not a leak", {
  # withr's set_path(): `old <- get_path(); Sys.setenv(PATH = path); invisible(old)`.
  # It hands the prior state back so a caller can restore, the base-R contract
  # option_changes already honours.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "set_path <- function(path) {",
      "  old <- get_path()",
      "  Sys.setenv(PATH = path)",
      "  invisible(old)",
      "}",
      "set_var <- function(value) {",
      "  old <- Sys.getenv('FOO')",
      "  Sys.setenv(FOO = value)",
      "  old", # bare return also counts
      "}"
    )
  )
  expect_true(lab_sys_setenv(pkg, verbose = FALSE)$passed)
})

test_that("lab_sys_setenv(): a Sys.setenv that captures nothing is still flagged", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "configure <- function() {",
      "  Sys.setenv(FOO = '1')",
      "  do_work()",
      "}"
    )
  )
  expect_false(lab_sys_setenv(pkg, verbose = FALSE)$passed)
})

# Test lab_core_usage() ----

test_that("lab_core_usage(): flags unbounded worker counts across frameworks", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function(x) parallel::mclapply(x, f, mc.cores = parallel::detectCores())",
      "b <- function(x) parallel::makeCluster(8)",
      "c1 <- function(x) doParallel::registerDoParallel(cores = detectCores())",
      "d <- function() future::plan(future::multisession, workers = 12)",
      "e <- function() mirai::daemons(6)",
      "f1 <- function() RcppParallel::setThreadOptions(numThreads = detectCores())",
      "g <- function() data.table::setDTthreads(16)",
      "h <- function() BiocParallel::MulticoreParam(workers = detectCores())",
      "i1 <- function() doMC::registerDoMC(cores = 8)"
    )
  )
  res <- lab_core_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 9L)
})

test_that("lab_core_usage(): exempts a CRAN-guarded worker count", {
  # This is logitr's and cbcTools' real guard, and it is byte-for-byte R's own
  # parallel:::.check_ncores predicate. The old check flagged it anyway, because
  # it demanded an `mc.cores` argument on the detectCores() call itself, which
  # detectCores() can never carry.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "set_num_cores <- function(n) {",
      "  chk <- tolower(Sys.getenv('_R_CHECK_LIMIT_CORES_', ''))",
      "  if (nzchar(chk) && (chk != 'false')) return(2L)",
      "  cores <- parallel::detectCores()",
      "  parallel::makeCluster(cores - 1)",
      "}"
    )
  )
  expect_true(lab_core_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_core_usage(): exempts availableCores, <=2 literals, defaults", {
  # Measured under _R_CHECK_LIMIT_CORES_=TRUE: detectCores() returns 12 while
  # parallelly/future availableCores() return 2, so availableCores() is the safe idiom.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function() future::plan(future::multisession, workers = parallelly::availableCores())",
      "b <- function(x) parallel::makeCluster(2L)",
      "c1 <- function(x) parallel::mclapply(x, f, mc.cores = 2L)",
      "d <- function(x) parallel::mclapply(x, f)", # default mc.cores is 2L
      "e <- function() parallel::makeCluster(cl_spec)" # unresolvable: do not guess
    )
  )
  expect_true(lab_core_usage(pkg, verbose = FALSE)$passed)
})

test_that("lab_core_usage(): draws the line at two, not a larger number", {
  # CRAN's ceiling is a hard two ("it must never use more than two
  # simultaneously"), so 3 is a breach even though it is modest. Every other
  # fixture in this file sits at 8 or above, which leaves 3..5 untested and the
  # threshold free to drift upward unnoticed.
  pkg_bad <- make_temp_dir()
  write_pkg(pkg_bad, r_code = "f <- function() parallel::makeCluster(3L)")
  res <- lab_core_usage(pkg_bad, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, r_code = "f <- function() parallel::makeCluster(2L)")
  expect_true(lab_core_usage(pkg_ok, verbose = FALSE)$passed)
})

test_that("lab_core_usage(): makeCluster(2L) is CRAN-compliant, not a violation", {
  # cbcTools/R/design.R. The old rule demanded an mc.cores argument, which
  # makeCluster() does not take, so a compliant call was flagged 100% of the time.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "setup <- function() {",
      "  cl <- parallel::makeCluster(2L)",
      "  on.exit(parallel::stopCluster(cl))",
      "  cl",
      "}"
    )
  )
  expect_true(lab_core_usage(pkg, verbose = FALSE)$passed)
})

# Test lab_library_in_pkg() ----

test_that("lab_library_in_pkg(): exempts library() sent to a parallel worker", {
  # A daemon starts with an empty search path, so library() there sets up the
  # WORKER's path, not the user's. logitr does this via mirai::everywhere().
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "run <- function(cl) {",
      "  mirai::everywhere({ library(logitr) }, .compute = 'logitr')",
      "  parallel::clusterEvalQ(cl, library(stats))",
      "}"
    )
  )
  expect_true(lab_library_in_pkg(pkg, verbose = FALSE)$passed)
})

test_that("lab_library_in_pkg(): still flags library() in ordinary code", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() { library(dplyr); mutate(x) }")
  expect_false(lab_library_in_pkg(pkg, verbose = FALSE)$passed)
})

test_that("lab_library_in_pkg(): does not read $library() as base::library()", {
  # `api$library(...)` is a member of whatever `api` is, and nothing to do with
  # attaching a package. The check carries NOT_MEMBER_ACCESS for exactly this.
  pkg_ok <- make_temp_dir()
  write_pkg(
    pkg_ok,
    r_code = "run <- function(api) { api$library('x'); api$require('y') }"
  )
  expect_true(lab_library_in_pkg(pkg_ok, verbose = FALSE)$passed)

  # ...and the genuine call in the same shape of file is still reported, so the
  # exemption cannot be widened into a blanket one.
  pkg_bad <- make_temp_dir()
  write_pkg(
    pkg_bad,
    r_code = c(
      "run <- function(api) { api$library('x'); api$require('y') }",
      "go <- function() { library(stats); median(1:3) }"
    )
  )
  res <- lab_library_in_pkg(pkg_bad, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

test_that("lab_library_in_pkg(): flags library()/require() but not pkg::fn", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() {",
      "  library(stats)",
      "  require(stats)",
      "  utils::head(1:5)",
      "}"
    )
  )
  res <- lab_library_in_pkg(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)
})

test_that("lab_library_in_pkg(): library() sent to a parallel daemon is not a search-path change", {
  # logitr/R/optimLoop.R. A daemon starts with an empty search path.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "run_multistart <- function(mi) {",
      "  mirai::everywhere(",
      "    { library(logitr); RcppParallel::setThreadOptions(numThreads = nThreads) },",
      "    .args = list(nThreads = 1L), .compute = 'logitr'",
      "  )",
      "}"
    )
  )
  expect_true(lab_library_in_pkg(pkg, verbose = FALSE)$passed)
})

# Test lab_detect_cores_robustness() ----

test_that("lab_detect_cores_robustness(): flags an unguarded detectCores()", {
  # logitr and cbcTools both do this. ?detectCores says "An integer, NA if the
  # answer is unknown", and NA - 1 is NA, so the next comparison errors with
  # "missing value where TRUE/FALSE needed".
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "set_num_cores <- function(n) {",
      "  available <- parallel::detectCores()",
      "  max_cores <- available - 1",
      "  if (n > max_cores) n <- max_cores",
      "  n",
      "}"
    )
  )
  res <- lab_detect_cores_robustness(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "may return NA", all = FALSE)
})

test_that("lab_detect_cores_robustness(): accepts an is.na() guard", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "set_num_cores <- function(n) {",
      "  available <- parallel::detectCores()",
      "  if (is.na(available)) available <- 1L",
      "  min(n, available)",
      "}"
    )
  )
  expect_true(lab_detect_cores_robustness(pkg, verbose = FALSE)$passed)
})

test_that("lab_detect_cores_robustness(): is silent when it is never called", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() parallelly::availableCores()")
  expect_true(lab_detect_cores_robustness(pkg, verbose = FALSE)$passed)
})

test_that("lab_detect_cores_robustness(): an unguarded detectCores() is caught", {
  # logitr/R/modelInputs.R setNumCores(), cbcTools/R/util.R. ?detectCores: "An
  # integer, NA if the answer is unknown". NA - 1 is NA, and the comparison below
  # then errors with "missing value where TRUE/FALSE needed" -- reproduced live.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "setNumCores <- function(numCores) {",
      "  coresAvailable <- parallel::detectCores()",
      "  maxCores <- coresAvailable - 1",
      "  if (numCores > maxCores) numCores <- maxCores",
      "  numCores",
      "}"
    )
  )
  expect_false(lab_detect_cores_robustness(pkg, verbose = FALSE)$passed)
})

# Test lab_internal_ns() ----

# These live here, next to lab_internal_ns() in R/diagnostics-code.R, rather than
# beside the example-side ::: check they pair with. Kept in
# test-diagnostics-examples.R they gave a false all-clear: editing
# R/diagnostics-code.R and running its own test file exercised none of them.

test_that("lab_internal_ns(): reports ::: in package code, not only examples", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c("a.R" = "f <- function() otherpkg:::helper()"))
  res <- lab_internal_ns(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "otherpkg:::helper", all = FALSE, fixed = TRUE)
})

test_that("lab_internal_ns(): accepts :: in package code and ::: in a string", {
  ok <- make_temp_dir()
  write_pkg(ok, r_code = c("a.R" = "f <- function() stats::median(1:3)"))
  expect_true(lab_internal_ns(ok, verbose = FALSE)$passed)

  # The AST is what makes this safe: the text appears, but no call does.
  str_pkg <- make_temp_dir()
  write_pkg(str_pkg, r_code = c("a.R" = "f <- function() nchar('pkg:::x')"))
  expect_true(lab_internal_ns(str_pkg, verbose = FALSE)$passed)
})

# Test lab_hardcoded_credentials() ----

test_that("lab_hardcoded_credentials(): flags a token in a string literal", {
  pkg <- make_temp_dir()
  # Assembled at run time so no secret-shaped literal is committed to this repo.
  token <- paste0("ghp_", strrep("A", 36))
  write_pkg(
    pkg,
    r_code = sprintf("get_client <- function() '%s'", token)
  )
  res <- lab_hardcoded_credentials(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_true(any(grepl("GitHub token", res$issues)))
})

test_that("lab_hardcoded_credentials(): is quiet on ordinary code", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "greet <- function(name) paste('hello', name)",
      "token_pattern <- 'looks like a variable name, not a secret'"
    )
  )
  expect_true(lab_hardcoded_credentials(pkg, verbose = FALSE)$passed)
})

test_that("lab_hardcoded_credentials(): ignores a secret shape in a comment", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "# not a real key: AKIAIOSFODNN7EXAMPLE lives only in this comment",
      "f <- function() TRUE"
    )
  )
  expect_true(lab_hardcoded_credentials(pkg, verbose = FALSE)$passed)
})

test_that("lab_hardcoded_credentials(): recognises multiple provider formats", {
  # fabricated, format-correct sample tokens across providers
  # Assembled at run time so no secret-shaped literal is committed to this repo.
  cases <- list(
    "AWS access key" = "AKIAIOSFODNN7EXAMPLE", # AWS's documented example key
    "Stripe key" = paste0("sk_live_", strrep("A", 24)),
    "Anthropic key" = paste0("sk-ant-api03-", strrep("A", 30)),
    "private key" = "-----BEGIN RSA PRIVATE KEY-----",
    "JSON Web Token" = paste0(
      "eyJ",
      strrep("a", 12),
      ".eyJ",
      strrep("b", 12),
      ".",
      strrep("c", 12)
    )
  )
  for (label in names(cases)) {
    pkg <- make_temp_dir()
    write_pkg(pkg, r_code = sprintf("f <- function() '%s'", cases[[label]]))
    res <- lab_hardcoded_credentials(pkg, verbose = FALSE)
    expect_false(res$passed, info = label)
    expect_true(any(grepl(label, res$issues, fixed = TRUE)), info = label)
  }
})

test_that("lab_hardcoded_credentials(): does not flag a slug or a bare SHA", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "model <- 'sk-learn-style-identifier-that-is-quite-long'",
      "commit <- 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0'"
    )
  )
  expect_true(lab_hardcoded_credentials(pkg, verbose = FALSE)$passed)
})

# Test emit_issue_summary() ----

test_that("emit_issue_summary(): prints issue text literally, never evaluating it", {
  # A finding quotes the package under check: a Title, a file name, a README
  # link. A URL template such as `/items/{id}` there used to reach cli as R code.
  out <- NULL
  expect_no_error(
    out <- cli::cli_fmt(emit_issue_summary(
      "README.md: http://api.example.org/items/{stop('evaluated')}",
      verbose = TRUE,
      "No issues",
      "Issues found"
    ))
  )
  expect_match(
    paste(out, collapse = "\n"),
    "items/{stop('evaluated')}",
    fixed = TRUE
  )
})

# Test diagnose_code_issues() ----

test_that("diagnose_code_issues(): tolerates missing R/ and man/", {
  empty <- make_temp_dir()
  expect_no_error(diagnose_code_issues(empty, verbose = FALSE))
  expect_no_error(diagnose_documentation_issues(empty, verbose = FALSE))
  expect_no_error(diagnose_general_issues(empty, verbose = FALSE))
  expect_no_error(diagnose_policy_violations(empty, verbose = FALSE))
})

test_that("diagnose_code_issues(): a check that errors surfaces as a failure", {
  # Stub a diagnostic that always throws; check that the orchestrator records
  # it as a failure with a non-empty message rather than silently dropping it.
  with_mocked_bindings(
    lab_tf_usage = function(path, verbose = TRUE, parsed = NULL) {
      stop("synthetic")
    },
    code = {
      pkg <- make_temp_dir()
      write_pkg(pkg)
      res <- diagnose_code_issues(pkg, verbose = FALSE)
      expect_false(res$tf_usage$passed)
      expect_true(grepl("synthetic", res$tf_usage$issues))
    }
  )
})

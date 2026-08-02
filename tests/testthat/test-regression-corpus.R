# Regression corpus: minimised snippets from real CRAN packages.
#
# checktor shipped 0.1.0 having never been run against a real package. Pointed at
# five (pcaR2, logitr, cbcTools, surveydown, renderthis) it produced 126 findings,
# the large majority false positives.
#
# Every fixture below is a reduction of a pattern that WAS reported and should not
# have been, or one that should have been reported and was not. They are asserted
# in both directions, so a future change that reintroduces a false positive, or
# loses a true one, fails here rather than in a user's inbox.
#
# Each block cites the package and file it came from.

# ---- false positives: these must stay silent --------------------------------

test_that("corpus: a console reporter is not unsuppressable output", {
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

test_that("corpus: print(doc, target) writes a file, it does not print", {
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

test_that("corpus: output that sets up a user prompt is interactive output", {
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

test_that("corpus: a caller-supplied write destination is permission", {
  # surveydown/R/db.R and config.R. CRAN forbids writing to the user's filespace
  # WITHOUT PERMISSION; a path the caller passed in is permission.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "create_env <- function(path, template) {",
      "  env_file <- file.path(path, '.env')",
      "  writeLines(template, env_file)",
      "}",
      "",
      "write_settings <- function(paths, content) {",
      "  writeLines(content, con = paths$target_settings)",
      "}"
    )
  )
  expect_true(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("corpus: library() sent to a parallel daemon is not a search-path change", {
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

test_that("corpus: makeCluster(2L) is CRAN-compliant, not a violation", {
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

test_that("corpus: a memoisation cache is not a .GlobalEnv write", {
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

test_that("corpus: prose comments in \\examples are not commented-out code", {
  # cbcTools. All 41 comment lines across the 9 flagged Rd files were English.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "cbc_choices.Rd" = c(
        "\\name{cbc_choices}",
        "\\alias{cbc_choices}",
        "\\title{c}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "# Simulate random choices (default)",
        "# (Columns are attributes, rows are alternatives)",
        "cbc_choices(design)",
        "}"
      )
    )
  )
  expect_true(lab_commented_examples(pkg, verbose = FALSE)$passed)
})

test_that("corpus: \\dontrun{} around a shiny reactive context is justified", {
  # surveydown/man/sd_value.Rd. Cannot run outside a live app, but never says
  # the word "shiny".
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

test_that("corpus: a non-syntactic S3 method is registered, not unexported", {
  # cbcTools/NAMESPACE. S3method("[",cbc_profiles) quotes the generic; keeping
  # the quotes made every [.foo / names<-.foo method look unregistered.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "#' Subset",
      "#' @export",
      "`[.cbc_profiles` <- function(x, i) x",
      "#' Rename",
      "#' @export",
      "`names<-.cbc_profiles` <- function(x, value) x"
    )
  )
  writeLines(
    c(
      "# Generated by roxygen2: do not edit by hand",
      "S3method(\"[\",cbc_profiles)",
      "S3method(\"names<-\",cbc_profiles)"
    ),
    file.path(pkg, "NAMESPACE")
  )
  expect_true(lab_roxygen_usage(pkg, verbose = FALSE)$passed)
})

test_that("corpus: a 31-word single-sentence Description is not too short", {
  # renderthis/DESCRIPTION. The old rule demanded 2+ sentences, which has no
  # authority behind it.
  desc <- paste(
    "Render slides to different formats, including 'html', 'pdf', 'png', 'gif',",
    "'pptx', and 'mp4', as well as a 'social' output, a 'png' of the first slide",
    "re-sized for sharing on social media."
  )
  expect_true(
    lab_description_length(
      verbose = FALSE,
      desc = c(Description = desc)
    )$passed
  )
})

test_that("corpus: a quoted package name in Title keeps its own capitalisation", {
  # R's own toTitleCase() restores single-quoted spans, which is why R does not
  # flag 'shiny' and the homegrown word-loop did.
  expect_true(
    lab_title_case(
      verbose = FALSE,
      desc = c(Title = "Extra Diagnostics for 'shiny' and 'rmarkdown' Packages")
    )$passed
  )
})

# ---- false negatives: these must be caught ----------------------------------

test_that("corpus: an unfilled usethis Authors@R template is caught", {
  # pcaR2/DESCRIPTION ships person("First", "Last", ...) -- a hard CRAN
  # rejection. checktor 0.1.0 passed it, because it only tested that the field
  # EXISTS. R CMD check says nothing either, for the same reason.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    authors_r = paste0(
      "person(\"First\", \"Last\", , \"january.weiner@gmail.com\", ",
      "role = c(\"aut\", \"cre\", \"cph\"))"
    )
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)$authors
  expect_false(res$passed)
  expect_true(any(grepl("placeholder", res$issues)))
})

test_that("corpus: an unguarded detectCores() is caught", {
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

test_that("corpus: a genuine write to the user's home is caught", {
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

test_that("corpus: printing during a computation is still caught", {
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

test_that("corpus: a hardcoded write destination is still caught", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x) writeLines(x, 'output.csv')",
      "g <- function(x, path = '~/data.csv') writeLines(x, path)"
    )
  )
  res <- lab_file_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)
})

test_that("corpus: a Suggests used in \\examples without a guard is caught", {
  # surveydown/man/sd_question_custom.Rd guards on interactive() rather than
  # requireNamespace(), which does not make the package available. This one was
  # a TRUE positive that an earlier audit pass wrongly dismissed.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = "Suggests: leaflet",
    rd_files = list(
      "q.Rd" = c(
        "\\name{q}",
        "\\alias{q}",
        "\\title{q}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "if (interactive()) {",
        "  library(leaflet)",
        "  leaflet::leaflet()",
        "}",
        "}"
      )
    )
  )
  expect_false(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

# ---- CRAN-corpus regressions (45-package audit) -----------------------------
# checktor was re-run against 45 CRAN packages, 15 of them expert-maintained
# (cli, rlang, testthat, withr, jsonlite, digest, curl, zoo, ...). It produced 831
# findings and NOT ONE of the 15 came out clean. These pin the root causes.

test_that("corpus: a multi-line export( block is read in full", {
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

test_that("corpus: roxygen @export may name several objects at once", {
  # jsonlite/R/fromJSON.R line 21 is `#' @export fromJSON toJSON`. Storing that
  # whole string as one name invented a function called "fromJSON toJSON".
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "#' Convert",
      "#' @export fromJSON toJSON",
      "fromJSON <- function(txt) txt",
      "toJSON <- function(x) x"
    )
  )
  writeLines(
    c(
      "# Generated by roxygen2: do not edit by hand",
      "export(fromJSON)",
      "export(toJSON)"
    ),
    file.path(pkg, "NAMESPACE")
  )
  expect_true(lab_roxygen_usage(pkg, verbose = FALSE)$passed)
})

test_that("corpus: temp_cleanup does not scan tests/, and is not a policy check", {
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

test_that("corpus: options()/par() READS and RESTORES are not changes", {
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

test_that("corpus: a NAMED option argument is still flagged", {
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

test_that("corpus: `urls` is advice, not policy", {
  # It flags any http:// link. CRAN's NOTE is for URLs that are INVALID or that
  # REDIRECT, which R determines by FETCHING them; checktor is offline and cannot
  # know whether a host even offers https. testthat, stringr, rlang, curl,
  # jsonlite, digest and zoo all ship http:// links and are on CRAN today.
  expect_equal(check_severity("urls"), "opinion")
})

test_that("corpus: obj$cat() is a method call, not base::cat()", {
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

test_that("corpus: base::cat() is still matched", {
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

test_that("corpus: obj$system() and obj$browser() are method calls too", {
  # The same defect in undesirable_function_check(), which backs system_calls,
  # browser_calls, library_in_pkg and the install checks.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "run <- function(api) {",
      "  api$system('ls')",
      "  api$browser()",
      "  invisible(NULL)",
      "}"
    )
  )
  expect_true(lab_system_calls(pkg, verbose = FALSE)$passed)
  expect_true(lab_browser_calls(pkg, verbose = FALSE)$passed)
})

# ---- second CRAN-corpus wave (adversarial triage of 105 groups) -------------

test_that("corpus: an output flag named `messages` is a verbosity gate", {
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

test_that("corpus: a method defined with a QUOTED name is still a method", {
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

test_that("corpus: `<<-` inside local() binds in the local() env, not .GlobalEnv", {
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

test_that("corpus: package_size measures the COMPRESSED size CRAN limits", {
  # CRAN's 5 MB limit is on the gzipped tarball. billboarder is 6.3 MB on disk and
  # 2.93 MB as a tarball; every package_size finding in the audit was this mistake.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "inst"), showWarnings = FALSE)
  # 8 MB of highly compressible text: over the limit raw, far under it compressed.
  writeLines(
    rep(paste(rep("a", 100), collapse = ""), 80000),
    file.path(pkg, "inst", "big.csv")
  )
  res <- lab_package_size(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_lt(res$size_mb, 5)
})

test_that("corpus: `if (require('pkg'))` IS the sanctioned guard", {
  # Writing R Extensions sanctions exactly this for conditional Suggests use in
  # examples. The old guard recognised only requireNamespace(), and only quoted,
  # while the USE pattern matched require() -- so the guard was the violation.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = "Suggests: chron",
    rd_files = list(
      "na.approx.Rd" = c(
        "\\name{na.approx}",
        "\\title{n}",
        "\\value{1}",
        "\\examples{",
        'if (require("chron")) {',
        "  tt <- as.chron('2000-01-01')",
        "}",
        "}"
      )
    )
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("corpus: interactive() is NOT a Suggests guard", {
  # It does not make the package available, so the example still fails without it.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = "Suggests: leaflet",
    rd_files = list(
      "q.Rd" = c(
        "\\name{q}",
        "\\title{q}",
        "\\value{1}",
        "\\examples{",
        "if (interactive()) {",
        "  library(leaflet)",
        "}",
        "}"
      )
    )
  )
  expect_false(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("corpus: T/F inside expression()/substitute() are language tokens", {
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

test_that("corpus: a real bare T/F is still flagged", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() mean(x, na.rm = T)")
  expect_false(lab_tf_usage(pkg, verbose = FALSE)$passed)
})

test_that("corpus: `na.rm = T` is flagged, `f(T = 1)` is not", {
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

# ---- third wave: the 196-package corpus -------------------------------------

test_that("corpus: an `=` assignment is an assignment", {
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

test_that("corpus: an if/else of printers is a printer", {
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

test_that("corpus: an if/else that RETURNS a value still leaks", {
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

# ---- backlog wave: the remaining root causes --------------------------------

test_that("corpus: a call in a DEFAULT ARGUMENT does not hide the function body", {
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

test_that("corpus: a vignette's PROSE is not code", {
  # curl's intro.Rmd calls itself "a drop-in replacement for `download.file` in
  # r-base" and was reported for saying so. Only the R chunks are code.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "vignettes"), showWarnings = FALSE)
  writeLines(
    c(
      "---",
      "title: Intro",
      "---",
      "",
      "This package is a drop-in replacement for `download.file` in r-base,",
      "and a modern alternative to httr::GET and RCurl.",
      "",
      "```{r}",
      "x <- 1 + 1",
      "```"
    ),
    file.path(pkg, "vignettes", "intro.Rmd")
  )
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("corpus: a vignette chunk that REALLY downloads is still flagged", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "vignettes"), showWarnings = FALSE)
  writeLines(
    c(
      "---",
      "title: Intro",
      "---",
      "",
      "```{r}",
      "download.file('https://example.com/x.csv', tmp)",
      "```"
    ),
    file.path(pkg, "vignettes", "intro.Rmd")
  )
  expect_false(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("corpus: a platform-branched system() call is the platform check", {
  # The check's own remediation asks for a platform check. beepr and cli branch on
  # the OS and were reported anyway.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "play <- function(f) {",
      "  if (Sys.info()[['sysname']] == 'Windows') {",
      "    shell(paste('start', f))",
      "  } else {",
      "    system(paste('afplay', f))",
      "  }",
      "}"
    )
  )
  expect_true(lab_system_calls(pkg, verbose = FALSE)$passed)
})

test_that("corpus: an install behind a consent prompt is consent", {
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

test_that("corpus: set.seed() in dead code cannot touch the RNG", {
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

test_that("corpus: a package's OWN option is its own state", {
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

test_that("corpus: roxygen's @examplesIf is a guard whatever its predicate", {
  # It compiles to \dontshow{if (COND) ...}, and COND can be anything: cli writes
  # `cli:::has_packages(c("htmltools"))`. The GUARD IS THE STRUCTURE.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = "Suggests: htmltools",
    rd_files = list(
      "ansi_html.Rd" = c(
        "\\name{ansi_html}",
        "\\title{a}",
        "\\value{1}",
        "\\examples{",
        "\\dontshow{if (cli:::has_packages(c(\"htmltools\"))) \\{ # examplesIf}",
        "htmltools::html_print(page)",
        "\\dontshow{\\} # examplesIf}",
        "}"
      )
    )
  )
  expect_true(lab_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

# ---- new-tier (packages first published under current CRAN review) -----------

test_that("corpus: `<<-` inside a Reference Class is field assignment", {
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

test_that("corpus: setwd() in a callr subprocess does not touch the session", {
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

test_that("corpus: a bare setwd() in ordinary code is still flagged", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function(d) { setwd(d); read.csv('x') }")
  expect_false(lab_option_changes(pkg, verbose = FALSE)$passed)
})

# ---- decisions from the new-tier review -------------------------------------

test_that("corpus: a setter that returns the captured state is not a leak", {
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

test_that("corpus: a Sys.setenv that captures nothing is still flagged", {
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

test_that("software_names flags a package name but not a programming language", {
  # Empirically split: ggplot2 is quoted in 96% of CRAN Descriptions that mention
  # it (a convention); JavaScript in 46%, HTML in 20% (a coin flip, not a rule).
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      "Bindings for JavaScript and HTML that build on ggplot2 graphics.",
      "It does a number of useful things for the user here."
    )
  )
  res <- lab_software_names(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_true(any(grepl("ggplot2", res$issues)))
  expect_false(any(grepl("JavaScript", res$issues)))
  expect_false(any(grepl("HTML", res$issues)))
})

test_that("software_names accepts a properly quoted package name", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      "Extends 'ggplot2' and 'shiny' with new layers.",
      "It does a number of useful things for the user here."
    )
  )
  expect_true(lab_software_names(pkg, verbose = FALSE)$passed)
})

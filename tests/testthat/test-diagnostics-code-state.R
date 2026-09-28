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

test_that("lab_seed_setting(): exempts if (FALSE) but flags a live condition", {
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
    r_code = c(
      "reset_par <- function(op) par(cex = op$cex, mar = op$mar)",
      "draw <- function() {",
      "  op <- par(no.readonly = TRUE)",
      "  on.exit(reset_par(op))",
      "  par(mar = c(2, 2, 2, 2))",
      "  plot(1)",
      "}",
      "set_margins <- function() par(mar = c(1, 1, 1, 1))"
    )
  )
  res <- lab_option_changes(pkg_bad, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
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

# Test lab_sys_setenv() ----

test_that("lab_sys_setenv(): flags an unrestored env var and accepts cleanup", {
  pkg_bad <- make_temp_dir()
  write_pkg(pkg_bad, r_code = "f <- function() Sys.setenv(MYVAR = '1')")
  res <- lab_sys_setenv(pkg_bad, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)

  pkg_ok <- make_temp_dir()
  write_pkg(
    pkg_ok,
    r_code = c(
      # restore the old value on exit
      "f <- function() {",
      "  old <- Sys.getenv('MYVAR')",
      "  on.exit(Sys.setenv(MYVAR = old))",
      "  Sys.setenv(MYVAR = '1')",
      "  invisible()",
      "}",
      # withr does the restore
      "g <- function() withr::local_envvar(c(MYVAR = '1'))",
      # restore by unsetting on exit
      "h <- function() {",
      "  Sys.setenv(FOO = 1)",
      "  on.exit(Sys.unsetenv('FOO'))",
      "}"
    )
  )
  res <- lab_sys_setenv(pkg_ok, verbose = FALSE)
  expect_true(res$passed)
  expect_identical(res$issues, character())
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

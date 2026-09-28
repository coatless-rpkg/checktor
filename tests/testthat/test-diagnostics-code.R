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

test_that("lab_tf_usage(): ignores strings, comments, TRUE/FALSE and words containing T or F", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "x <- 'T cells and F-stats'",
      "# T - reminder",
      "# F-statistic",
      'msg <- "T"',
      "y <- TRUE",
      "z <- FALSE",
      "transform <- function() NULL",
      "field <- 1"
    )
  )
  expect_identical(lab_tf_usage(pkg, verbose = FALSE)$issues, character(0))
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

test_that("lab_hardcoded_credentials(): is quiet on ordinary strings, a slug or a bare SHA", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "greet <- function(name) paste('hello', name)",
      "token_pattern <- 'looks like a variable name, not a secret'",
      # a near miss for the sk- OpenAI prefix
      "model <- 'sk-learn-style-identifier-that-is-quite-long'",
      # a 40-hex commit SHA
      "commit <- 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0'"
    )
  )
  expect_identical(lab_hardcoded_credentials(pkg, verbose = FALSE)$issues, character(0))
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
    "GitHub token" = paste0("ghp_", strrep("A", 36)),
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

# ---- browser() ---------------------------------------------------------------

test_that("lab_browser_calls flags browser() and not the word in strings", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "x <- 'browser() reminder'",
      "f <- function() browser()"
    )
  )
  res <- lab_browser_calls(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

# ---- system() ----------------------------------------------------------------

test_that("lab_system_calls flags system()/system2()/shell()", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() system('ls')",
      "g <- function() system2('ls')",
      "h <- function() shell('dir')"
    )
  )
  res <- lab_system_calls(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gte(length(res$issues), 3L)
})

# ---- file operations ---------------------------------------------------------

test_that("lab_file_operations does NOT double-match saveRDS as save()", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x) saveRDS(x, '/tmp/foo.rds')"
    )
  )
  res <- lab_file_operations(pkg, verbose = FALSE)
  # Should flag saveRDS once. With the bug, the issues list contained both
  # 'saveRDS()' and 'save()' for the same line.
  expect_equal(sum(grepl("saveRDS", res$issues)), 1L)
  expect_false(any(grepl(":\\d+ \\(save\\(\\)\\)", res$issues)))
})

test_that("lab_file_operations exempts tempfile/tempdir targets", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() {",
      "  path <- tempfile()",
      "  saveRDS(1, path)",
      "  unlink(path)",
      "}"
    )
  )
  res <- lab_file_operations(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("lab_file_operations flags writes outside tempdir", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() write.csv(mtcars, '/etc/foo.csv')")
  res <- lab_file_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
})

# ---- network ops in docs -----------------------------------------------------

test_that("lab_network_operations flags download.file in Rd without wrapper", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\value{1}",
        "\\examples{",
        "  download.file('https://example.com/x', 'x')",
        "}"
      )
    )
  )
  res <- lab_network_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("lab_network_operations accepts \\dontrun-wrapped network code", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\value{1}",
        "\\examples{",
        "\\dontrun{",
        "  download.file('https://example.com/x', 'x')",
        "}",
        "}"
      )
    )
  )
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("file_operations exempts a write to a caller-supplied destination", {
  # CRAN's rule is about writing without permission, and a path the caller
  # passed in is permission.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "report <- function(results, file) {",
      "  writeLines(results, file)",
      "}"
    )
  )
  expect_true(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("file_operations still flags a formal that defaults into the user's filespace", {
  # The destination is a formal, but calling report() with no arguments writes
  # to $HOME, so the exemption must not apply.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      'report <- function(results, file = "~/report.txt") {',
      "  writeLines(results, file)",
      "}"
    )
  )
  expect_false(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("file_operations does not exempt on the strength of a non-destination arg", {
  # `x` is a formal, but it is the DATA argument. The destination is a literal
  # home path and must still be flagged.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "bad <- function(x) {",
      '  writeLines(x, "~/data.csv")',
      "}"
    )
  )
  expect_false(lab_file_operations(pkg, verbose = FALSE)$passed)
})

# --- file_operations: only a provable destination is a violation -------------

test_that("file_operations flags a hardcoded literal destination", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x) writeLines(x, 'output.csv')", # writes to the CWD
      "g <- function(x) saveRDS(x, '~/cache.rds')" # writes to $HOME
    )
  )
  res <- lab_file_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)
})

test_that("file_operations allows a caller-supplied or computed destination", {
  # CRAN's rule is about writing WITHOUT PERMISSION. A path the caller passed in
  # is permission, and a computed path proves nothing either way. surveydown's
  # `writeLines(template, env_file)` builds env_file from a user-given directory.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x, file) writeLines(x, file)",
      "g <- function(x, path) {",
      "  env_file <- file.path(path, '.env')",
      "  writeLines(x, env_file)",
      "}",
      "h <- function(x) saveRDS(x, tempfile())"
    )
  )
  expect_true(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("file_operations still catches a formal that defaults into $HOME", {
  # The hole the literal rule would otherwise leave: the destination IS a symbol,
  # but calling with no argument writes to the user's home.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = "f <- function(x, path = '~/data.csv') writeLines(x, path)"
  )
  expect_false(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("file_operations reads file.create()'s destination as its FIRST arg", {
  # write.csv(x, file) puts the path second; file.create(path) puts it first.
  # Assuming "always the second argument" read file.create()'s path as content.
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() file.create('~/marker.txt')")
  expect_false(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("file_operations judges a path by its ROOT, not any literal in it", {
  # `file.path(temp_pkg, "NEWS.md")` is rooted at a variable, so the basename
  # literal proves nothing. checktor's own example_diagnose_scenario() does this,
  # and an earlier version of the rule flagged it.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "scaffold <- function() {",
      "  temp_pkg <- tempfile()",
      "  writeLines(c('# news'), file.path(temp_pkg, 'NEWS.md'))",
      "}",
      "under_dir <- function(dir, x) writeLines(x, file.path(dir, 'out.csv'))"
    )
  )
  expect_true(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("file_operations flags a path whose ROOT is a literal", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function(x) writeLines(x, file.path('~', 'out.csv'))", # $HOME
      "b <- function(x) writeLines(x, file.path('output', 'out.csv'))" # working dir
    )
  )
  res <- lab_file_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)
})

# Test lab_home_writing() ----

test_that("lab_home_writing(): does NOT flag formula tildes", {
  # A formula's `~` is an operator, not a path. The check looks only at write
  # calls, so a fixture with none could not fail whatever the home test does:
  # each one here writes, with a formula in the data it writes (f) or in the
  # expression that names its file (g).
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "fit <- function(d) lm(y ~ x, data = d)",
      "f <- function(d, path) saveRDS(lm(y ~ x, data = d), path)",
      "g <- function(d, dir) write.csv(d, file.path(dir, paste0(all.vars(y ~ x)[1], '.csv')))"
    )
  )
  expect_identical(lab_home_writing(pkg, verbose = FALSE)$issues, character(0))
})

test_that("lab_home_writing(): flags WRITES into the home directory", {
  # The violation home_writing claimed to detect and did not: it inspected only
  # read functions (Sys.getenv, path.expand) and missed every actual write.
  # writeLines/saveRDS/write.csv are three of the forty entries in
  # WRITE_FUNCTIONS. A device opened on a home path leaves a file there exactly
  # as write.table() does, so both ends of the list are pinned.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      'f <- function(x) writeLines(x, "~/leaked.txt")',
      'g <- function(x) saveRDS(x, "~/.myapp/cache.rds")',
      'h <- function(x) write.csv(x, file = file.path(Sys.getenv("HOME"), "o.csv"))',
      "a <- function(x) write.table(x, '~/o.tsv')",
      "b <- function() png('~/p.png')"
    )
  )
  res <- lab_home_writing(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(
    res$issues,
    c(
      "test.R:1 (writeLines() writes under the home directory)",
      "test.R:2 (saveRDS() writes under the home directory)",
      "test.R:3 (write.csv() writes under the home directory)",
      "test.R:4 (write.table() writes under the home directory)",
      "test.R:5 (png() writes under the home directory)"
    )
  )
})

test_that("lab_home_writing(): does not flag reads of the home path", {
  # The old check inspected only path.expand/normalizePath/file.path/Sys.getenv,
  # which are all reads: it flagged these while MISSING the writes above. A read
  # stays a read when its result is what a write sends out, since the file goes
  # where the destination says. Searching the whole call reported a to d.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() path.expand('~')",
      "g <- function() Sys.getenv('HOME')",
      "h <- function() normalizePath('~')",
      "i <- function() file.path('~', 'data.csv')",
      "a <- function(file) writeLines(normalizePath('~'), file)",
      "b <- function(path) saveRDS(Sys.getenv('HOME'), path)",
      "c <- function() cat('Home is', path.expand('~'))",
      "d <- function(dest) file.copy('~/.Rprofile', dest)"
    )
  )
  expect_identical(lab_home_writing(pkg, verbose = FALSE)$issues, character(0))
})

test_that("lab_home_writing(): finds the destination however the call names it", {
  # The destination is resolved per function, as lab_file_operations() does:
  # positional for writeLines() and file.copy(), named for cat() and save(), which
  # write to a file only when given `file =`. A call whose data AND destination
  # are both home is still one write.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function() writeLines(normalizePath('~'), '~/where.txt')",
      "b <- function(x) cat(x, file = '~/log.txt')",
      "c <- function(x) save(x, file = file.path(Sys.getenv('HOME'), 'x.rda'))",
      "d <- function(x) file.copy(x, '~/backup')"
    )
  )
  expect_identical(
    lab_home_writing(pkg, verbose = FALSE)$issues,
    c(
      "test.R:1 (writeLines() writes under the home directory)",
      "test.R:2 (cat() writes under the home directory)",
      "test.R:3 (save() writes under the home directory)",
      "test.R:4 (file.copy() writes under the home directory)"
    )
  )
})

test_that("lab_home_writing(): finds the destination a pipe hands on", {
  # The left-hand side of `|>` or `%>%` is the call's first argument, so the path
  # written in the call is the second: the destination. The last two send a home
  # path as the data and write where the caller says.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function(x) x |> writeLines('~/out.txt')",
      "b <- function(d) d %>% write.csv('~/out.csv')",
      "c <- function(x) x |> saveRDS(file.path(Sys.getenv('HOME'), 'x.rds'))",
      "d <- function(x) x %>% writeLines(., '~/dot.txt')",
      "e <- function(x) '~/notes.txt' |> writeLines(text = x, con = _)",
      "f <- function(path) normalizePath('~') |> writeLines(path)",
      "g <- function(path) normalizePath('~') %>% writeLines(., path)"
    )
  )
  expect_identical(
    lab_home_writing(pkg, verbose = FALSE)$issues,
    c(
      "test.R:1 (writeLines() writes under the home directory)",
      "test.R:2 (write.csv() writes under the home directory)",
      "test.R:3 (saveRDS() writes under the home directory)",
      "test.R:4 (writeLines() writes under the home directory)",
      "test.R:5 (writeLines() writes under the home directory)"
    )
  )
})

test_that("lab_home_writing(): a named argument does not move the destination", {
  # Counting `sep =` or `plot =` as a position read the data as the destination.
  # file.copy() and file.rename() call their destination `to`, and naming the
  # data formal, as in `saveRDS(object = x, ...)`, leaves the path as the first
  # unnamed argument. The last line copies FROM home.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function(x) file.copy(to = '~/b', from = x)",
      "b <- function(x) file.rename(to = '~/b', from = x)",
      "c <- function(x) writeLines(sep = '\\n', x, '~/o.txt')",
      "d <- function(x) write.csv(row.names = FALSE, x, '~/o.csv')",
      "e <- function(p) ggplot2::ggsave(plot = p, '~/p.png')",
      "f <- function(x) file.copy(from = x, '~/b')",
      "g <- function(x) saveRDS(object = x, '~/x.rds')",
      "h <- function(path) file.copy(from = '~/.Rprofile', path)"
    )
  )
  expect_identical(
    lab_home_writing(pkg, verbose = FALSE)$issues,
    c(
      "test.R:1 (file.copy() writes under the home directory)",
      "test.R:2 (file.rename() writes under the home directory)",
      "test.R:3 (writeLines() writes under the home directory)",
      "test.R:4 (write.csv() writes under the home directory)",
      "test.R:5 (ggsave() writes under the home directory)",
      "test.R:6 (file.copy() writes under the home directory)",
      "test.R:7 (saveRDS() writes under the home directory)"
    )
  )
})

test_that("lab_home_writing(): catches a destination that defaults to the home directory", {
  # Called with no path, a() writes to ~/x.txt, and b() under the HOME it reads.
  # lab_file_operations() reports a() only: it accepts a default that is itself
  # a `~` or absolute literal, and b()'s is a computed path. A default that is not
  # home, or a home default on the data rather than the destination, is not a
  # home write.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function(x, path = '~/x.txt') writeLines(x, path)",
      "b <- function(x, dir = file.path(Sys.getenv('HOME'), 'c')) saveRDS(x, file.path(dir, 'x.rds'))",
      "c <- function(x, path = tempfile()) writeLines(x, path)",
      "d <- function(x, path = '/srv/x.txt') writeLines(x, path)",
      "e <- function(path, x = '~/data') writeLines(x, path)"
    )
  )
  expect_identical(
    lab_home_writing(pkg, verbose = FALSE)$issues,
    c(
      "test.R:1 (writeLines() writes under the home directory)",
      "test.R:2 (saveRDS() writes under the home directory)"
    )
  )
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
  expect_equal(res$issues, "test.R:8") # the leaky one, not the clean one
})

test_that("lab_temp_cleanup(): a later function's cleanup does not excuse a leak", {
  # Every top-level statement in R/ is a function definition, so "a later
  # statement cleans up" let clean() excuse leaky() whenever it came second.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "leaky <- function() {",
      "  t2 <- tempfile()",
      "  writeLines('b', t2)",
      "}",
      "",
      "clean <- function() {",
      "  t1 <- tempfile()",
      "  writeLines('a', t1)",
      "  unlink(t1)",
      "}"
    )
  )
  expect_equal(lab_temp_cleanup(pkg, verbose = FALSE)$issues, "test.R:2")
})

test_that("lab_temp_cleanup(): a path the function returns is the caller's to clean", {
  # callr, rmarkdown and bigANNOY each wrap tempfile() in a small factory that
  # hands the path back. Whoever receives it decides when the file goes.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function(pattern) tempfile(pattern)",
      "b <- function(dir) {",
      "  dir.create(dir, showWarnings = FALSE)",
      "  base::tempfile(tmpdir = dir)",
      "}",
      "c1 <- function(str) {",
      "  f <- tempfile(fileext = '.html')",
      "  writeLines(str, f)",
      "  f",
      "}",
      "d <- function() return(tempfile())",
      "e <- function(x) {",
      "  p <- tempfile()",
      "  saveRDS(x, p)",
      "  invisible(p)",
      "}"
    )
  )
  expect_equal(lab_temp_cleanup(pkg, verbose = FALSE)$issues, character(0))
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

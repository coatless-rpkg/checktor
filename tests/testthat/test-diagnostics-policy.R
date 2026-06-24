# ---- browser() ---------------------------------------------------------------

test_that("diagnose_browser_calls flags browser() and not the word in strings", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "x <- 'browser() reminder'",
    "f <- function() browser()"
  ))
  res <- diagnose_browser_calls(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

# ---- system() ----------------------------------------------------------------

test_that("diagnose_system_calls flags system()/system2()/shell()", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "f <- function() system('ls')",
    "g <- function() system2('ls')",
    "h <- function() shell('dir')"
  ))
  res <- diagnose_system_calls(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gte(length(res$issues), 3L)
})

# ---- file operations ---------------------------------------------------------

test_that("diagnose_file_operations does NOT double-match saveRDS as save()", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "f <- function(x) saveRDS(x, '/tmp/foo.rds')"
  ))
  res <- diagnose_file_operations(pkg, verbose = FALSE)
  # Should flag saveRDS once. With the bug, the issues list contained both
  # 'saveRDS()' and 'save()' for the same line.
  expect_equal(sum(grepl("saveRDS", res$issues)), 1L)
  expect_false(any(grepl(":\\d+ \\(save\\(\\)\\)", res$issues)))
})

test_that("diagnose_file_operations exempts tempfile/tempdir targets", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c(
    "f <- function() {",
    "  path <- tempfile()",
    "  saveRDS(1, path)",
    "  unlink(path)",
    "}"
  ))
  res <- diagnose_file_operations(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("diagnose_file_operations flags writes outside tempdir", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() write.csv(mtcars, '/etc/foo.csv')")
  res <- diagnose_file_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
})

# ---- network ops in docs -----------------------------------------------------

test_that("diagnose_network_operations flags download.file in Rd without wrapper", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}",
    "\\title{fn}",
    "\\value{1}",
    "\\examples{",
    "  download.file('https://example.com/x', 'x')",
    "}"
  )))
  res <- diagnose_network_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("diagnose_network_operations accepts \\dontrun-wrapped network code", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("fn.Rd" = c(
    "\\name{fn}",
    "\\title{fn}",
    "\\value{1}",
    "\\examples{",
    "\\dontrun{",
    "  download.file('https://example.com/x', 'x')",
    "}",
    "}"
  )))
  expect_true(diagnose_network_operations(pkg, verbose = FALSE)$passed)
})

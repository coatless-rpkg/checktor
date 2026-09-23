# A test that names a CRAN package reproduces a false positive or a missed
# finding from that package's real sources, so a regression fails here first.

# Test lab_browser_calls() ----

test_that("lab_browser_calls(): flags browser() and not the word in strings", {
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

# Test lab_system_calls() ----

test_that("lab_system_calls(): flags system()/system2()/shell()", {
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

test_that("lab_system_calls(): obj$system() and obj$browser() are method calls too", {
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

test_that("lab_system_calls(): a platform-branched system() call is the platform check", {
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

# Test lab_file_operations() ----

test_that("lab_file_operations(): does NOT double-match saveRDS as save()", {
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

test_that("lab_file_operations(): exempts tempfile/tempdir targets", {
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

test_that("lab_file_operations(): flags writes outside tempdir", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() write.csv(mtcars, '/etc/foo.csv')")
  res <- lab_file_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("lab_file_operations(): exempts a write to a caller-supplied path", {
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

test_that("lab_file_operations(): flags a formal that defaults into the user's filespace", {
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

test_that("lab_file_operations(): does not exempt on the strength of a non-destination arg", {
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

# Only a provable destination is a violation.

test_that("lab_file_operations(): flags a hardcoded literal destination", {
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

test_that("lab_file_operations(): allows a caller-supplied or computed path", {
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

test_that("lab_file_operations(): catches a formal that defaults into $HOME", {
  # The hole the literal rule would otherwise leave: the destination IS a symbol,
  # but calling with no argument writes to the user's home.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = "f <- function(x, path = '~/data.csv') writeLines(x, path)"
  )
  expect_false(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_file_operations(): reads file.create()'s destination as its FIRST arg", {
  # write.csv(x, file) puts the path second; file.create(path) puts it first.
  # Assuming "always the second argument" read file.create()'s path as content.
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() file.create('~/marker.txt')")
  expect_false(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_file_operations(): judges a path by its ROOT, not any literal", {
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

test_that("lab_file_operations(): flags a path whose ROOT is a literal", {
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

test_that("lab_file_operations(): a caller-supplied write destination is permission", {
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

test_that("lab_file_operations(): a hardcoded write destination is still caught", {
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

# Test lab_network_operations() ----

test_that("lab_network_operations(): flags an unwrapped download.file in Rd", {
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

test_that("lab_network_operations(): names the wrappers with their braces", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}", "\\title{fn}", "\\value{1}", "\\examples{",
        "  download.file('https://example.com/x', 'x')", "}"
      )
    )
  )
  out <- paste(cli::cli_fmt(lab_network_operations(pkg)), collapse = "\n")
  expect_match(out, "Wrap in \\dontrun{}, \\donttest{}", fixed = TRUE)
})

test_that("lab_network_operations(): accepts \\dontrun-wrapped network code", {
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

test_that("lab_network_operations(): skips a build-ignored pkgdown article", {
  # usethis::use_article() writes vignettes/articles/ and excludes the directory
  # in .Rbuildignore, so nothing under it reaches CRAN.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "vignettes", "articles"), recursive = TRUE)
  writeLines(
    c("```{r}", "download.file('https://example.com', 'f')", "```"),
    file.path(pkg, "vignettes", "articles", "extra.Rmd")
  )
  expect_false(lab_network_operations(pkg, verbose = FALSE)$passed)

  writeLines("^vignettes/articles$", file.path(pkg, ".Rbuildignore"))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a vignette's PROSE is not code", {
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

test_that("lab_network_operations(): a vignette chunk that REALLY downloads is still flagged", {
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

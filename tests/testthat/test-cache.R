# The cache in R/cache.R lets the checks of one checktor() run share each parse.
# These tests hold it to parsing every help page once per run, and to keeping
# nothing from one run to the next.

# Test read_rd() ----

test_that("read_rd(): checktor() parses each help page once per run", {
  pkg <- rd_pkg("f(1)")
  writeLines(
    c("\\name{g}", "\\alias{g}", "\\title{G}", "\\description{d}", "\\value{x}"),
    file.path(pkg, "man", "g.Rd")
  )
  parses <- character(0)
  real_parse <- parse_rd_file
  local_mocked_bindings(parse_rd_file = function(file) {
    parses <<- c(parses, basename(file))
    real_parse(file)
  })

  checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_setequal(parses, c("f.Rd", "g.Rd"))
  expect_identical(anyDuplicated(parses), 0L)

  # A second run parses afresh rather than reusing the first run's pages.
  checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_identical(as.vector(table(parses)), c(2L, 2L))
})

test_that("read_rd(): a check called on its own parses every time", {
  pkg <- rd_pkg("f(1)")
  parses <- 0L
  real_parse <- parse_rd_file
  local_mocked_bindings(parse_rd_file = function(file) {
    parses <<- parses + 1L
    real_parse(file)
  })
  lab_value_tags(pkg, verbose = FALSE)
  lab_value_tags(pkg, verbose = FALSE)
  expect_identical(parses, 2L)
})

test_that("read_rd(): an edit between runs is seen by the next run", {
  pkg <- rd_pkg("f(1)")
  first <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_true(first$documentation_issues$example_installs$passed)

  rd <- file.path(pkg, "man", "f.Rd")
  lines <- readLines(rd)
  writeLines(sub("^f\\(1\\)$", "install.packages('x')", lines), rd)
  second <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false(second$documentation_issues$example_installs$passed)
})

# Test read_r_xml() ----

test_that("read_r_xml(): checktor() parses R/ once per run", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = c("a.R" = "f <- function() 1", "b.R" = "g <- function() 2"))
  parses <- character(0)
  real_parse <- parse_one_r_file
  local_mocked_bindings(parse_one_r_file = function(file) {
    parses <<- c(parses, basename(file))
    real_parse(file)
  })
  checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_setequal(parses, c("a.R", "b.R"))
  expect_identical(anyDuplicated(parses), 0L)
})

# Test read_example_xml() ----

test_that("read_example_xml(): checktor() reads the examples once per run", {
  pkg <- rd_pkg("f(1)")
  reads <- 0L
  real_read <- rd_example_code
  local_mocked_bindings(rd_example_code = function(path) {
    reads <<- reads + 1L
    real_read(path)
  })
  checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_identical(reads, 1L)
})

# Test local_run_cache() ----

test_that("local_run_cache(): the cache is empty and off once a run ends", {
  pkg <- rd_pkg("f(1)")
  checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false(isTRUE(.run_cache$active))
  expect_identical(ls(.run_cache, all.names = TRUE), character(0))
})

test_that("local_run_cache(): is emptied when the function using it errors", {
  f <- function() {
    local_run_cache()
    run_cached("k", function() 1)
    stop("boom")
  }
  expect_error(f(), "boom")
  expect_false(isTRUE(.run_cache$active))
  expect_identical(ls(.run_cache, all.names = TRUE), character(0))
})

test_that("local_run_cache(): a nested call leaves the teardown to the outer one", {
  inner <- function() {
    local_run_cache()
    run_cached("k", function() "inner")
  }
  outer <- function() {
    local_run_cache()
    inner()
    # Still on, and still holding what the inner call computed.
    c(isTRUE(.run_cache$active), run_cached("k", function() "recomputed"))
  }
  expect_identical(outer(), c("TRUE", "inner"))
  expect_false(isTRUE(.run_cache$active))
})

# Test run_cached() ----

test_that("run_cached(): computes once and repeats its warnings and errors", {
  calls <- 0L
  warns <- function() {
    calls <<- calls + 1L
    warning("careful")
    "value"
  }
  fails <- function() {
    calls <<- calls + 1L
    stop("broken")
  }
  f <- function() {
    local_run_cache()
    expect_warning(a <- run_cached("w", warns), "careful")
    expect_warning(b <- run_cached("w", warns), "careful")
    expect_identical(c(a, b), c("value", "value"))
    expect_error(run_cached("e", fails), "broken")
    expect_error(run_cached("e", fails), "broken")
  }
  f()
  expect_identical(calls, 2L)
})

test_that("run_cached(): outside a run computes every time", {
  calls <- 0L
  count <- function() {
    calls <<- calls + 1L
    calls
  }
  expect_identical(run_cached("k", count), 1L)
  expect_identical(run_cached("k", count), 2L)
})

# Test description_value() ----

test_that("description_value(): reads one field, NA when it cannot", {
  pkg <- make_temp_dir()
  write_pkg(pkg, package = "mypkg")
  expect_identical(description_value(pkg, "Package"), "mypkg")
  expect_identical(description_value(pkg, "Nope"), NA_character_)
  bare <- make_temp_dir()
  dir.create(bare, showWarnings = FALSE, recursive = TRUE)
  expect_identical(description_value(bare, "Package"), NA_character_)
  # A blank line splits the record; read.dcf() still reads the first one.
  writeLines(
    c("Package: split", "", "Title: After"),
    file.path(bare, "DESCRIPTION")
  )
  expect_identical(description_value(bare, "Package"), "split")
})

# Test description_or_null() ----

test_that("description_or_null(): the fields as a list, NULL on a bad file", {
  pkg <- make_temp_dir()
  write_pkg(pkg, package = "mypkg")
  expect_identical(description_or_null(pkg)[["Package"]], "mypkg")
  bad <- make_temp_dir()
  dir.create(bad, showWarnings = FALSE, recursive = TRUE)
  expect_null(description_or_null(bad))
  writeLines(
    c("Package: split", "", "Title: After"),
    file.path(bad, "DESCRIPTION")
  )
  expect_null(description_or_null(bad))
})

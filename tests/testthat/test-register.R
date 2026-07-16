# Tests for the runtime check registry (register_check / unregister_check /
# registered_checks). Every test that registers cleans up on exit so the registry
# never leaks into other test files.

test_that("registered_checks() is empty by default and grows with registration", {
  on.exit(unregister_check(), add = TRUE)
  unregister_check()
  expect_equal(nrow(registered_checks()), 0L)

  register_check(
    "noop",
    function(path, verbose = TRUE) {
      checktor_check_result(TRUE, character(0), "noop")
    },
    category = "general",
    severity = "opinion"
  )

  rc <- registered_checks()
  expect_equal(nrow(rc), 1L)
  expect_identical(rc$check, "noop")
  expect_identical(rc$category, "general")
  expect_identical(rc$severity, "opinion")
})

test_that("checktor() runs a registered check and surfaces it in the results", {
  on.exit(unregister_check(), add = TRUE)
  register_check(
    "no_banned",
    function(path, verbose = TRUE, parsed = NULL) {
      if (is.null(parsed)) {
        parsed <- read_r_xml(path)
      }
      hits <- undesirable_function_check(parsed, "banned_helper")
      checktor_check_result(length(hits) == 0L, hits, "no banned_helper()")
    },
    category = "code",
    severity = "policy"
  )

  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() banned_helper(1)")
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  expect_true("no_banned" %in% names(r$code_issues))
  expect_false(r$code_issues$no_banned$passed)
  expect_identical(r$code_issues$no_banned$severity, "policy")
  expect_true("no_banned" %in% tidy(r)$check)
})

test_that("a registered check's tier governs whether it counts toward the verdict", {
  on.exit(unregister_check(), add = TRUE)
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() banned_helper(1)")

  base_total <- checktor(
    pkg,
    verbose = FALSE,
    progress = FALSE
  )$metadata$total_issues

  flag <- function(path, verbose = TRUE, parsed = NULL) {
    if (is.null(parsed)) {
      parsed <- read_r_xml(path)
    }
    hits <- undesirable_function_check(parsed, "banned_helper")
    checktor_check_result(length(hits) == 0L, hits, "banned")
  }

  register_check("banned_policy", flag, category = "code", severity = "policy")
  r_policy <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_equal(r_policy$metadata$total_issues, base_total + 1L)
  unregister_check("banned_policy")

  register_check(
    "banned_opinion",
    flag,
    category = "code",
    severity = "opinion"
  )
  r_op <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_equal(r_op$metadata$total_issues, base_total) # default excludes opinion
  expect_gt(r_op$metadata$advisory_issues, 0L) # but it is still reported
})

test_that("checktor() forwards the parse cache to a registered code check", {
  on.exit(unregister_check(), add = TRUE)
  seen <- new.env()
  register_check(
    "cache_probe",
    function(path, verbose = TRUE, parsed = NULL) {
      seen$got_cache <- !is.null(parsed)
      checktor_check_result(TRUE, character(0), "cache probe")
    },
    category = "code"
  )

  pkg <- make_temp_dir()
  write_pkg(pkg)
  checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_true(isTRUE(seen$got_cache))
})

test_that("checktor() forwards the parsed DESCRIPTION to a registered description check", {
  on.exit(unregister_check(), add = TRUE)
  seen <- new.env()
  register_check(
    "desc_probe",
    function(path, verbose = TRUE, desc = NULL) {
      seen$got_desc <- !is.null(desc)
      checktor_check_result(TRUE, character(0), "desc probe")
    },
    category = "description"
  )

  pkg <- make_temp_dir()
  write_pkg(pkg)
  checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_true(isTRUE(seen$got_desc))
})

test_that("a registered check with no cache argument is still called", {
  on.exit(unregister_check(), add = TRUE)
  seen <- new.env()
  register_check(
    "plain",
    function(path, verbose = TRUE) {
      seen$ran <- TRUE
      checktor_check_result(TRUE, character(0), "plain")
    },
    category = "documentation"
  )

  pkg <- make_temp_dir()
  write_pkg(pkg)
  checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_true(isTRUE(seen$ran))
})

test_that("a registered check that errors is caught, not fatal", {
  on.exit(unregister_check(), add = TRUE)
  register_check(
    "boom",
    function(path, verbose = TRUE) stop("kaboom"),
    category = "general"
  )
  pkg <- make_temp_dir()
  write_pkg(pkg)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false(r$general_issues$boom$passed)
})

test_that("a registered check returning the wrong type is caught, not fatal", {
  on.exit(unregister_check(), add = TRUE)
  register_check(
    "wrongtype",
    function(path, verbose = TRUE) 42,
    category = "general"
  )
  pkg <- make_temp_dir()
  write_pkg(pkg)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false(r$general_issues$wrongtype$passed)
})

test_that("register_check() rejects bad input", {
  on.exit(unregister_check(), add = TRUE)
  ok <- function(path, verbose = TRUE) {
    checktor_check_result(TRUE, character(0), "x")
  }
  expect_error(register_check("tf_usage", ok), "built-in")
  expect_error(register_check("passed", ok), "reserved")
  expect_error(register_check("x", ok, category = "nope"))
  expect_error(register_check("x", ok, severity = "nope"))
  expect_error(register_check("x", 42))
  expect_error(register_check("", ok))
})

test_that("unregister_check() rejects a non-character, non-NULL argument", {
  expect_error(unregister_check(42), "character")
})

test_that("re-registering a name overwrites it with a message", {
  on.exit(unregister_check(), add = TRUE)
  ok <- function(path, verbose = TRUE) {
    checktor_check_result(TRUE, character(0), "x")
  }
  register_check("dup", ok, category = "general", severity = "policy")
  expect_message(
    register_check("dup", ok, category = "code", severity = "opinion"),
    "Replacing"
  )
  rc <- registered_checks()
  expect_identical(rc$category[rc$check == "dup"], "code")
  expect_identical(rc$severity[rc$check == "dup"], "opinion")
})

test_that("unregister_check() removes one or all", {
  on.exit(unregister_check(), add = TRUE)
  ok <- function(path, verbose = TRUE) {
    checktor_check_result(TRUE, character(0), "x")
  }
  register_check("a", ok, category = "general")
  register_check("b", ok, category = "general")
  unregister_check("a")
  expect_identical(registered_checks()$check, "b")
  unregister_check()
  expect_equal(nrow(registered_checks()), 0L)
})

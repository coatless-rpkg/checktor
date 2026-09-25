# The table of built-in checks in R/registry.R. Every per-check list checktor
# keeps is derived from it, so these tests hold the table to itself and to what
# the category functions actually run.

# Test BUILTIN_CHECKS ----

test_that("BUILTIN_CHECKS: every row is well formed", {
  expect_identical(anyDuplicated(BUILTIN_CHECKS$name), 0L)
  expect_true(all(BUILTIN_CHECKS$category %in% CHECK_CATEGORIES))
  expect_true(all(BUILTIN_CHECKS$severity %in% SEVERITY_LEVELS))
  expect_true(all(
    BUILTIN_CHECKS$when %in% c("always", "console", "backend", "request")
  ))
  # Nothing may shadow the summary slot every category result carries.
  expect_false("passed" %in% BUILTIN_CHECKS$name)
})

test_that("BUILTIN_CHECKS: CHECK_SEVERITY and CHECK_WHEN come from the table", {
  expect_identical(names(CHECK_SEVERITY), BUILTIN_CHECKS$name)
  expect_identical(unname(CHECK_SEVERITY), BUILTIN_CHECKS$severity)
  sometimes <- BUILTIN_CHECKS$when != "always"
  expect_identical(names(CHECK_WHEN), BUILTIN_CHECKS$name[sometimes])
  expect_identical(unname(CHECK_WHEN), BUILTIN_CHECKS$when[sometimes])
})

test_that("BUILTIN_CHECKS: a check that reads the parsed DESCRIPTION can be skipped", {
  # When R cannot read DESCRIPTION every check that reads the fields is reported
  # skipped under its label. One not marked `reads_desc` would instead run on a
  # NULL `desc`, so every description check that takes `desc` needs the mark.
  # description_file takes `desc` for a uniform signature but re-reads the file.
  desc_rows <- BUILTIN_CHECKS[
    BUILTIN_CHECKS$category == "description" &
      BUILTIN_CHECKS$when != "request",
  ]
  takes_desc <- vapply(
    desc_rows$name,
    function(nm) "desc" %in% names(formals(get(paste0("lab_", nm)))),
    logical(1)
  )
  needs_message <- setdiff(desc_rows$name[takes_desc], "description_file")
  expect_setequal(names(DESCRIPTION_FIELD_CHECKS), needs_message)
  # Only description checks carry one.
  others <- BUILTIN_CHECKS$category != "description"
  expect_false(any(BUILTIN_CHECKS$reads_desc[others]))
})

test_that("BUILTIN_CHECKS: every check reports under its label", {
  expect_identical(anyDuplicated(BUILTIN_CHECKS$label), 0L)
  pkg <- make_temp_dir()
  write_pkg(pkg)
  for (nm in BUILTIN_CHECKS$name) {
    res <- get(paste0("lab_", nm))(pkg, verbose = FALSE)
    expect_identical(res$message, check_label(nm), info = nm)
  }
})

# Test check_label() ----

test_that("check_label(): names a built-in check, and refuses an unknown one", {
  expect_identical(check_label("tf_usage"), "T/F usage check")
  expect_identical(
    check_label(c("urls", "spelling")),
    c("URLs check", "Spelling check")
  )
  expect_error(check_label("no_such_check"), "no_such_check")
})

# Test CATEGORY_FIELDS ----

test_that("CATEGORY_FIELDS: names each category's slot in checktor()'s result", {
  expect_identical(names(CATEGORY_FIELDS), CHECK_CATEGORIES)
  expect_identical(names(CATEGORY_ORCHESTRATORS), CHECK_CATEGORIES)
  pkg <- make_temp_dir()
  write_pkg(pkg)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_identical(setdiff(names(r), "metadata"), unname(CATEGORY_FIELDS))
})

# Test builtin_checks_for() ----

test_that("builtin_checks_for(): each category runs its rows in table order", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  for (category in CHECK_CATEGORIES) {
    ran <- setdiff(names(r[[CATEGORY_FIELDS[[category]]]]), "passed")
    expect_identical(ran, builtin_check_names(category), info = category)
  }
})

test_that("builtin_checks_for(): leaves out the checks that run on request", {
  on_request <- BUILTIN_CHECKS$name[BUILTIN_CHECKS$when == "request"]
  for (category in CHECK_CATEGORIES) {
    expect_false(any(on_request %in% names(builtin_checks_for(category))))
  }
})

test_that("builtin_checks_for(): passes a shared parse only to a check that takes it", {
  seen <- NULL
  local_mocked_bindings(
    lab_tf_usage = function(path, verbose = TRUE, parsed = NULL) {
      seen <<- parsed
      checktor_check_result(TRUE, character(0), "T/F usage check")
    },
    lab_package_size = function(path, verbose = TRUE) {
      checktor_check_result(TRUE, character(0), "Package size check")
    }
  )
  code <- builtin_checks_for("code", parsed = "the parse", desc = "unused")
  code$tf_usage(".", FALSE)
  expect_identical(seen, "the parse")
  general <- builtin_checks_for("general", parsed = "not wanted")
  expect_true(general$package_size(".", FALSE)$passed)
})

# Test run_category() ----

test_that("run_category(): runs what the category's orchestrator runs", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_identical(
    run_category("general", pkg, FALSE),
    diagnose_general_issues(pkg, verbose = FALSE)
  )
  expect_identical(
    run_category("code", pkg, FALSE, parsed = read_r_xml(pkg)),
    diagnose_code_issues(pkg, verbose = FALSE)
  )
})

test_that("begin_category(): prints the heading each orchestrator prints", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  for (category in CHECK_CATEGORIES) {
    heading <- cli::cli_fmt(begin_category(category, pkg, TRUE))
    full <- cli::cli_fmt(match.fun(CATEGORY_ORCHESTRATORS[[category]])(pkg))
    expect_identical(
      full[nzchar(full)][1L],
      heading[nzchar(heading)],
      info = category
    )
  }
})

test_that("begin_category(): turns the run cache on until its caller exits", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  during <- NULL
  orchestrator <- function() {
    root <- begin_category("general", file.path(pkg, "R"), FALSE)
    during <<- isTRUE(.run_cache$active)
    root
  }
  expect_identical(
    normalizePath(orchestrator()),
    normalizePath(pkg)
  )
  expect_true(during)
  expect_false(isTRUE(.run_cache$active))
})

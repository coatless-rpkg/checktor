# Test dcf_field() ----

test_that("dcf_field(): reads a field from a list or a vector", {
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "Tools for Tests")
  m <- read.dcf(file.path(pkg, "DESCRIPTION"))
  for (desc in list(as.list(m[1L, ]), m[1L, ])) {
    expect_identical(dcf_field(desc, "Title"), "Tools for Tests")
    expect_null(dcf_field(desc, "Copyright"))
  }
})

# Test desc_value() ----

test_that("desc_value(): a missing, NA or blank field is NULL, anything else as written", {
  desc <- list(Title = " Tools ", Blank = "", Space = "  ", Missing = NA_character_)
  expect_identical(desc_value(desc, "Title"), " Tools ")
  expect_null(desc_value(desc, "Blank"))
  expect_null(desc_value(desc, "Space"))
  expect_null(desc_value(desc, "Missing"))
  expect_null(desc_value(desc, "Copyright"))
  expect_null(desc_value(c(Title = "Tools"), "Copyright"))
})

# Test resolve_description() ----

test_that("resolve_description(): reads a read.dcf() matrix or a vector as the list read_description() gives", {
  # A matrix keeps its field names as column names, so desc[["Title"]] on one is
  # a subscript error, and so is a missing field on a vector.
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "Tools for Tests")
  f <- file.path(pkg, "DESCRIPTION")
  m <- read.dcf(f)
  expect_identical(resolve_description(pkg, m), read_description(f))
  expect_identical(resolve_description(pkg, m[1L, ]), read_description(f))
  expect_null(resolve_description(pkg, m)[["Copyright"]])
  expect_null(resolve_description(pkg, c(Title = "Tools"))[["Description"]])
})

test_that("resolve_description(): every DESCRIPTION check reads a read.dcf() matrix", {
  # `desc` is documented as what read.dcf() returns. Each check must find in
  # the matrix what it finds in the file.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    title = "Tools for \"ggplot2\" Plots in Python",
    description = "Builds on ggplot2 and \"shiny\" to fit XYZ models for the user."
  )
  m <- read.dcf(file.path(pkg, "DESCRIPTION"))
  ns <- asNamespace("checktor")
  checks <- ls(ns, pattern = "^lab_")
  checks <- checks[vapply(
    checks,
    function(f) "desc" %in% names(formals(get(f, envir = ns))),
    logical(1)
  )]
  expect_true(all(c("lab_acronyms", "lab_description_quoted_quotes") %in% checks))
  for (f in checks) {
    check <- get(f, envir = ns)
    from_file <- check(pkg, verbose = FALSE)
    from_matrix <- check(pkg, verbose = FALSE, desc = m)
    expect_identical(from_matrix$issues, from_file$issues, info = f)
    expect_identical(from_matrix$passed, from_file$passed, info = f)
  }
})

# Test diagnose_description_issues() ----

test_that("diagnose_description_issues(): a DESCRIPTION R cannot read is a failing check", {
  # It used to end the category early with no checks in it, which nothing
  # counted, so checktor() called a package R cannot install healthy.
  res <- diagnose_description_issues(unparseable_pkg(), verbose = FALSE)
  expect_s3_class(res, "checktor_category_result")
  expect_identical(failed_checks(res), "description_file")
  expect_equal(n_issues(res), 1L)
  expect_identical(res$description_file$severity, "policy")
})

test_that("diagnose_description_issues(): the checks that read DESCRIPTION sit out when R cannot", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  readable <- diagnose_description_issues(pkg, verbose = FALSE)
  res <- diagnose_description_issues(unparseable_pkg(), verbose = FALSE)

  # The same panel, so a check that could not run is named rather than missing.
  expect_identical(.check_names(res), .check_names(readable))
  status <- vapply(.check_names(res), function(nm) check_status(res[[nm]]), "")
  expect_identical(names(status)[status == "failed"], "description_file")
  # license_year reads LICENSE alone, so it still has something to examine.
  expect_identical(names(status)[status == "passed"], "license_year")
  sat_out <- names(status)[status == "skipped"]
  expect_setequal(
    sat_out,
    setdiff(.check_names(readable), c("description_file", "license_year"))
  )
  for (nm in sat_out) {
    expect_identical(res[[nm]]$skip_reason, "DESCRIPTION could not be read")
    # Each under its own name, as print() and health_report() show it.
    expect_identical(res[[nm]]$message, readable[[nm]]$message)
  }
})

test_that("diagnose_description_issues(): a registered DESCRIPTION check sits out too", {
  withr::defer(unregister_check("house_rule"))
  register_check(
    "house_rule",
    function(path, verbose = TRUE, desc = NULL) {
      checktor_check_result(FALSE, "DESCRIPTION:1", "House rule")
    },
    category = "description",
    severity = "policy"
  )
  res <- diagnose_description_issues(unparseable_pkg(), verbose = FALSE)
  expect_identical(check_status(res$house_rule), "skipped")
  expect_identical(res$house_rule$skip_reason, "DESCRIPTION could not be read")
  expect_identical(failed_checks(res), "description_file")
})

test_that("diagnose_description_issues(): an unfilled usethis Authors@R template is caught", {
  # pcaR2/DESCRIPTION ships person("First", "Last", ...) -- a hard CRAN
  # rejection. checktor 0.1.0 passed it, because it only tested that the field
  # EXISTS. R CMD check says nothing either, for the same reason.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    authors_r = paste0(
      "person(\"First\", \"Last\", , \"maintainer@example.org\", ",
      "role = c(\"aut\", \"cre\", \"cph\"))"
    )
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)$authors
  expect_false(res$passed)
  # The finding itself: a check that crashed also comes back failed, with a
  # "Diagnostic errored" issue in place of this one.
  expect_identical(
    res$issues,
    "Authors@R: unfilled template placeholder (\"First\", \"Last\")"
  )
})

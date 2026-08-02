# health_report() had no tests at all, which is how it came to omit an entire
# category. These hold every format to reporting what checktor() found.

policy_pkg <- function(envir = parent.frame()) {
  pkg <- make_temp_dir(envir = envir)
  write_pkg(
    pkg,
    r_code = c(
      "bad.R" = paste(
        "f <- function() {",
        "  browser()",
        "  writeLines('x', 'out.csv')",
        "}",
        sep = "\n"
      )
    )
  )
  pkg
}

test_that("every format reports the CRAN policy findings", {
  r <- checktor(policy_pkg(), verbose = FALSE, progress = FALSE)
  failed <- tidy(r)$check[!tidy(r)$passed]
  expect_true("browser_calls" %in% failed)
  expect_true("file_operations" %in% failed)

  for (fmt in c("markdown", "text", "html")) {
    txt <- paste(health_report(r, format = fmt), collapse = "\n")
    expect_match(txt, "Browser", info = fmt)
    expect_match(txt, "File Operations|File operations", info = fmt)
  }
})

test_that("a report walks every category checktor() runs", {
  # The guard against one format quietly dropping a panel again.
  r <- checktor(policy_pkg(), verbose = FALSE, progress = FALSE)
  categories <- grep("_issues$", names(r), value = TRUE)
  expect_setequal(REPORT_CATEGORIES, categories)
})

test_that("report_findings returns each failing check once, in category order", {
  r <- checktor(policy_pkg(), verbose = FALSE, progress = FALSE)
  found <- report_findings(r)
  checks <- vapply(found, function(f) f$check, character(1))
  failed <- tidy(r)$check[!tidy(r)$passed]

  expect_setequal(checks, failed)
  expect_false(anyDuplicated(checks) > 0L)
  cats <- unique(vapply(found, function(f) f$category, character(1)))
  expect_equal(cats, intersect(REPORT_CATEGORIES, cats))
})

test_that("a report names the checks that did not run", {
  # setup.R turns the gated checks off, the same state as a CI run.
  r <- checktor(policy_pkg(), verbose = FALSE, progress = FALSE)
  expect_true(length(r$metadata$skipped_checks) > 0L)
  for (fmt in c("markdown", "text", "html")) {
    txt <- paste(health_report(r, format = fmt), collapse = "\n")
    expect_match(txt, "did not run", info = fmt)
  }
})

test_that("a clean package gets a clean report in every format", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_true(is_healthy(r))
  for (fmt in c("markdown", "text", "html")) {
    txt <- paste(health_report(r, format = fmt), collapse = "\n")
    expect_match(txt, "clean bill of health", ignore.case = TRUE, info = fmt)
  }
})

test_that("the HTML report escapes markup in a finding", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(c("YEAR: <YEAR>", "COPYRIGHT HOLDER: <COPYRIGHT HOLDER>"),
             file.path(pkg, "LICENSE"))
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  html <- paste(health_report(r, format = "html"), collapse = "\n")
  # An unescaped <YEAR> would be swallowed by a browser as an unknown tag.
  # Both halves are needed: absence alone is also what a report that never
  # mentions the finding at all looks like.
  expect_true(grepl("&lt;YEAR&gt;", html, fixed = TRUE))
  expect_false(grepl("<YEAR>", html, fixed = TRUE))
})

test_that("health_report() writes the file it is given", {
  r <- checktor(policy_pkg(), verbose = FALSE, progress = FALSE)
  out <- file.path(make_temp_dir(), "report.md")
  health_report(r, file = out)
  expect_true(file.exists(out))
  expect_match(paste(readLines(out), collapse = "\n"), "Browser")
})

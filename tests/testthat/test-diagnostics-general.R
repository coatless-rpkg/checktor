# ---- package size ------------------------------------------------------------

test_that("diagnose_package_size excludes .Rbuildignore'd directories", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  # Add a faux .git directory that would inflate size if included.
  big_dir <- file.path(pkg, ".git")
  dir.create(big_dir, recursive = TRUE)
  writeLines(rep("x", 1e5), file.path(big_dir, "huge.txt"))

  # Add it to .Rbuildignore so the matcher excludes it (also matched by
  # the always-skip set).
  writeLines(c("^\\.git$"), file.path(pkg, ".Rbuildignore"))

  res <- diagnose_package_size(pkg, verbose = FALSE)
  # The fake huge file is ~ 200 KB but checked exclusion should keep us well
  # under the 5 MB threshold.
  expect_lt(res$size_mb, 1)
  expect_true(res$passed)
})

test_that("diagnose_package_size still flags genuinely large packages", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # Write a 6 MB file in inst/ that is NOT ignored.
  dir.create(file.path(pkg, "inst"), recursive = TRUE)
  writeBin(raw(6 * 1024 * 1024), file.path(pkg, "inst", "bigdata.bin"))
  res <- diagnose_package_size(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gt(res$size_mb, 5)
})

# ---- URLs --------------------------------------------------------------------

test_that("diagnose_urls flags http:// in DESCRIPTION URL field", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = c("URL: http://example.com"))
  res <- diagnose_urls(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("diagnose_urls accepts https://", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = c("URL: https://example.com"))
  res <- diagnose_urls(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("diagnose_urls ignores http:// localhost", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # Local references in a README:
  writeLines(c("Run http://localhost:8000 to test."),
             file.path(pkg, "README.md"))
  res <- diagnose_urls(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("diagnose_urls flags known URL shorteners", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("See https://bit.ly/abcdef for details.",
             file.path(pkg, "README.md"))
  res <- diagnose_urls(pkg, verbose = FALSE)
  expect_false(res$passed)
})

# Test package_exports() ----

test_that("package_exports(): reads a MULTI-LINE export( block", {
  # The bug that broke everything. The old reader regexed NAMESPACE line by line,
  # so an export( block spanning lines lost every name after the first. On the
  # real `digest` package it returned exactly one entry, the string "AES,"
  # (trailing comma included), when the truth is nine exports -- so digest::digest()
  # itself was reported as unexported.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "export(AES,",
      "       digest,",
      "       digest2int,",
      "       hmac)",
      "S3method(\"[\",foo)",
      "S3method(\"names<-\",foo)",
      "S3method(print,foo)"
    ),
    file.path(pkg, "NAMESPACE")
  )

  ex <- package_exports(pkg)
  expect_true(all(c("AES", "digest", "digest2int", "hmac") %in% ex$names))
  expect_true(all(c("[.foo", "names<-.foo", "print.foo") %in% ex$names))
})

test_that("package_exports(): honours exportPattern()", {
  # A name can be exported without ever being listed.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines('exportPattern("^[^.]")', file.path(pkg, "NAMESPACE"))
  ex <- package_exports(pkg)
  expect_true(name_is_exported("visible_fn", ex))
  expect_false(name_is_exported(".hidden_fn", ex))
})

test_that("package_exports(): returns NULL when it cannot read NAMESPACE", {
  # "Cannot tell" must never become "is unexported". Guessing here is how a check
  # starts accusing a package's flagship function of not existing.
  pkg <- make_temp_dir()
  write_pkg(pkg) # write_pkg writes no NAMESPACE
  expect_false(file.exists(file.path(pkg, "NAMESPACE")))
  expect_null(package_exports(pkg))
  expect_true(name_is_exported("anything", NULL))
})

# Test lab_license() ----

test_that("lab_license(): accepts a standardizable license", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # `MIT + file LICENSE` is only valid when the file it points at exists.
  writeLines(
    c("YEAR: 2026", "COPYRIGHT HOLDER: Jane Doe"),
    file.path(pkg, "LICENSE")
  )
  expect_true(
    lab_license(
      pkg,
      verbose = FALSE,
      desc = c(License = "MIT + file LICENSE")
    )$passed
  )
  expect_true(
    lab_license(
      pkg,
      verbose = FALSE,
      desc = c(License = "GPL (>= 3)")
    )$passed
  )
})

test_that("lab_license(): flags a non-standardizable license", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  res <- lab_license(
    pkg,
    verbose = FALSE,
    desc = c(License = "Do whatever you like")
  )
  expect_false(res$passed)
})

test_that("lab_license(): flags a missing referenced LICENSE file", {
  pkg <- make_temp_dir()
  write_pkg(pkg) # no LICENSE file written
  res <- lab_license(
    pkg,
    verbose = FALSE,
    desc = c(License = "MIT + file LICENSE")
  )
  expect_false(res$passed)
  expect_match(res$issues, "LICENSE", all = FALSE)
})

test_that("lab_license(): flags the full MIT text where R wants the two-line stub", {
  # `MIT + file LICENSE` points at a DCF stub naming the year and holder. The
  # full license text is not DCF, and R CMD check NOTEs "License stub is invalid
  # DCF", which CRAN sends back.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "MIT License",
      "",
      "Copyright (c) 2026 Jane Doe",
      "",
      "Permission is hereby granted, free of charge, to any person obtaining a copy",
      "of this software and associated documentation files (the \"Software\"), to deal"
    ),
    file.path(pkg, "LICENSE")
  )
  res <- lab_license(pkg, verbose = FALSE, desc = c(License = "MIT + file LICENSE"))
  expect_false(res$passed)
  expect_match(res$issues, "License stub is invalid DCF", fixed = TRUE)
})

test_that("lab_license(): flags a stub missing a field its license needs", {
  # BSD 3-clause needs ORGANIZATION too, and an empty field is as good as none.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c("YEAR: 2026", "COPYRIGHT HOLDER: Jane Doe"),
    file.path(pkg, "LICENSE")
  )
  res <- lab_license(pkg, verbose = FALSE, desc = c(License = "BSD_3_clause + file LICENSE"))
  expect_match(res$issues, "missing or empty fields: ORGANIZATION", fixed = TRUE)
  writeLines(c("YEAR: 2026", "COPYRIGHT HOLDER:"), file.path(pkg, "LICENSE"))
  res <- lab_license(pkg, verbose = FALSE, desc = c(License = "MIT + file LICENSE"))
  expect_match(res$issues, "missing or empty fields: COPYRIGHT HOLDER", fixed = TRUE)

  # A LICENSE that is not a stub's is not read as one.
  writeLines("Anything the author likes.", file.path(pkg, "LICENSE"))
  res <- lab_license(pkg, verbose = FALSE, desc = c(License = "GPL-3 | file LICENSE"))
  expect_true(res$passed)
})

# Test lab_license_file_unneeded() ----

test_that("lab_license_file_unneeded(): flags a file pointer on a standard license", {
  for (lic in c(
    "GPL-3 + file LICENSE",
    "GPL (>= 2) + file LICENSE",
    "LGPL-3 + file LICENCE",
    "AGPL-3 + file LICENSE",
    "Apache License 2.0 + file LICENSE",
    "CC0 + file LICENSE"
  )) {
    res <- lab_license_file_unneeded(
      make_temp_dir(),
      verbose = FALSE,
      desc = list(License = lic)
    )
    expect_false(res$passed, info = lic)
    expect_length(res$issues, 1L)
    expect_true(startsWith(res$issues, paste0(lic, ": ")), info = lic)
  }
  res <- lab_license_file_unneeded(
    make_temp_dir(),
    verbose = FALSE,
    desc = list(License = "GPL-3 + file LICENSE")
  )
  expect_identical(
    res$issues,
    paste0(
      "GPL-3 + file LICENSE: GPL-3 is a standard license R knows, so CRAN ",
      "needs neither '+ file LICENSE' nor the file"
    )
  )
})

test_that("lab_license_file_unneeded(): leaves a template license and a plain one alone", {
  for (lic in c(
    "MIT + file LICENSE",
    "BSD_3_clause + file LICENSE",
    "BSD_2_clause + file LICENCE",
    "GPL-3",
    "GPL (>= 2)",
    "file LICENSE",
    "GPL-2 | MIT + file LICENSE",
    "Do whatever you like"
  )) {
    expect_true(
      lab_license_file_unneeded(
        make_temp_dir(),
        verbose = FALSE,
        desc = list(License = lic)
      )$passed,
      info = lic
    )
  }
  expect_true(
    lab_license_file_unneeded(make_temp_dir(), verbose = FALSE, desc = list(Package = "x"))$passed
  )
})

test_that("lab_license_file_unneeded(): judges each alternative of a dual license", {
  res <- lab_license_file_unneeded(
    make_temp_dir(),
    verbose = FALSE,
    desc = list(License = "GPL-3 + file LICENSE | MIT + file LICENSE")
  )
  expect_length(res$issues, 1L)
  expect_match(res$issues, "^GPL-3 \\+ file LICENSE: ")
})

test_that("lab_license_file_unneeded(): runs with the DESCRIPTION panel at policy tier", {
  pkg <- make_temp_dir()
  write_pkg(pkg, license = "GPL-3 + file LICENSE")
  writeLines("Some extra terms.", file.path(pkg, "LICENSE"))
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$license_file_unneeded$passed)
  expect_true(res$license$passed)
  expect_identical(check_severity("license_file_unneeded"), "policy")
})

test_that("lab_license_file_unneeded(): prints the treatment prescribe() gives", {
  out <- paste(
    cli::cli_fmt(lab_license_file_unneeded(
      make_temp_dir(),
      desc = list(License = "GPL-3 + file LICENSE")
    )),
    collapse = " "
  )
  expect_match(out, "R ships the text of standard licenses", fixed = TRUE)
})

# Test lab_license_year() ----

test_that("lab_license_year(): flags an unfilled LICENSE template", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c("YEAR: <YEAR>", "COPYRIGHT HOLDER: <COPYRIGHT HOLDER>"),
    file.path(pkg, "LICENSE")
  )
  res <- lab_license_year(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("lab_license_year(): does not flag an old but filled-in year", {
  # The old rule fired on every package not touched this calendar year. A
  # LICENSE reading `YEAR: 1999` passes R CMD check --as-cran in silence.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c("YEAR: 1999", "COPYRIGHT HOLDER: Jane Doe"),
    file.path(pkg, "LICENSE")
  )
  expect_true(lab_license_year(pkg, verbose = FALSE)$passed)
})

test_that("lab_license_year(): passes when there is no LICENSE file", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_license_year(pkg, verbose = FALSE)$passed)
})

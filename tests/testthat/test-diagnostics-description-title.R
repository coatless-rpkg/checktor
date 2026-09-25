# Test lab_title_length() ----

test_that("lab_title_length(): flags a title longer than 65 characters", {
  pkg <- make_temp_dir()
  write_pkg(pkg, title = paste(rep("Word", 20), collapse = " ")) # > 65 chars
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$title_length$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, title = "Concise Package Title")
  expect_true(
    diagnose_description_issues(pkg_ok, verbose = FALSE)$title_length$passed
  )
})

test_that("lab_title_length(): puts the boundary between 65 and 66 chars", {
  # The other fixtures are 99 and 21 characters, which leaves the threshold free
  # to move anywhere in 22..99 undetected. Pin it exactly.
  #
  # 65 is the width Writing R Extensions says a listing may truncate to, not a
  # limit, so a title of exactly 65 characters shows in full and is not a
  # finding. 375 packages on CRAN sit at exactly 65.
  for (n in c(64L, 65L)) {
    ok <- lab_title_length(make_temp_dir(), verbose = FALSE, desc = c(Title = strrep("W", n)))
    expect_true(ok$passed, info = paste(n, "characters"))
    expect_equal(ok$nchar, n)
  }

  bad <- lab_title_length(make_temp_dir(), verbose = FALSE, desc = c(Title = strrep("W", 66)))
  expect_false(bad$passed)
  expect_equal(length(bad$issues), 1L)
  expect_match(bad$issues, "66 characters", all = FALSE)
  # The message says how much would be lost, not just that it is long.
  expect_match(bad$issues, "last 1 character", all = FALSE)
})

# Test lab_title_case() ----

test_that("lab_title_case(): does not flag a quoted software name", {
  # This is the false positive that made the homegrown word-loop unusable.
  # R's own engine restores single-quoted spans before comparing, so 'shiny'
  # keeps its lowercase s.
  desc <- c(Title = "Extra Diagnostics for 'shiny' and 'rmarkdown' Packages")
  expect_true(lab_title_case(make_temp_dir(), verbose = FALSE, desc = desc)$passed)
})

test_that("lab_title_case(): flags a genuinely non-title-case Title", {
  desc <- c(Title = "A package for running extra checks")
  res <- lab_title_case(make_temp_dir(), verbose = FALSE, desc = desc)
  expect_false(res$passed)
  # The suggestion must carry the corrected string so it can be pasted in.
  expect_match(res$issues, "Running Extra Checks", fixed = TRUE, all = FALSE)
})

test_that("lab_title_case(): accepts a correct Title", {
  desc <- c(Title = "Extra CRAN Diagnostics for R Packages")
  expect_true(lab_title_case(make_temp_dir(), verbose = FALSE, desc = desc)$passed)
})

test_that("lab_title_case(): a quoted package name in Title keeps its own capitalisation", {
  # R's own toTitleCase() restores single-quoted spans, which is why R does not
  # flag 'shiny' and the homegrown word-loop did.
  expect_true(
    lab_title_case(make_temp_dir(),
      verbose = FALSE,
      desc = c(Title = "Extra Diagnostics for 'shiny' and 'rmarkdown' Packages")
    )$passed
  )
})

# Test lab_title_package_name() ----

test_that("lab_title_package_name(): flags a Title that is the package name", {
  for (title in c("toypkg", "Toypkg", " TOYPKG ")) {
    res <- lab_title_package_name(
      make_temp_dir(),
      verbose = FALSE,
      desc = list(Package = "toypkg", Title = title)
    )
    expect_identical(
      res$issues,
      "Title is just the package name: provide a real title",
      info = title
    )
  }
})

test_that("lab_title_package_name(): flags a Title that opens with the name and a colon", {
  for (title in c("toypkg: Fit Simple Models", "Toypkg : Fit Simple Models")) {
    res <- lab_title_package_name(
      make_temp_dir(),
      verbose = FALSE,
      desc = list(Package = "toypkg", Title = title)
    )
    expect_identical(
      res$issues,
      paste0(
        "Title starts with the package name: ", trimws(title),
        " (R drops this NOTE for an update whose Title is unchanged)"
      ),
      info = title
    )
  }
})

test_that("lab_title_package_name(): leaves a name that is an ordinary word alone", {
  # CRAN accepts these routinely: survival's Title is "Survival Analysis".
  cases <- list(
    c("survival", "Survival Analysis"),
    c("bibtex", "Bibtex Parser"),
    c("toypkg", "Fit Simple Models with toypkg"),
    c("toypkg", "toypkgs: Something Else"),
    # The dot in a name is a dot, not any character.
    c("a.b", "aXb: A Title")
  )
  for (x in cases) {
    expect_true(
      lab_title_package_name(
        make_temp_dir(),
        verbose = FALSE,
        desc = list(Package = x[1], Title = x[2])
      )$passed,
      info = x[2]
    )
  }
  expect_true(
    lab_title_package_name(make_temp_dir(), verbose = FALSE, desc = list(Package = "x"))$passed
  )
})

test_that("lab_title_package_name(): runs with the DESCRIPTION panel at policy tier", {
  pkg <- make_temp_dir()
  write_pkg(pkg, package = "toypkg", title = "toypkg: Fit Simple Models")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$title_package_name$passed)
  expect_identical(check_severity("title_package_name"), "policy")
})

# Test lab_title_starts_with_article() ----

test_that("lab_title_starts_with_article(): is NOT part of a default run", {
  # A mis-transplant of CRAN's real rule, whose source requires the literal noun
  # "package" after the article AND applies to the Description field, not the
  # Title. jsonlite ("A Simple and Robust JSON Parser and Generator for R") and
  # curl ("A Modern and Flexible Web Client for R") are on CRAN with such titles.
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "A Modern and Flexible Web Client")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_null(res$title_starts_with_article)

  # Still callable directly.
  expect_false(
    lab_title_starts_with_article(pkg, verbose = FALSE)$passed
  )
})

# Test lab_title_redundant_phrases() ----

test_that("lab_title_redundant_phrases(): flags 'for R' and 'Tools for' patterns", {
  for (bad in c(
    "Statistical Models for R",
    "A Toolkit for Imaging",
    "Tools for Reproducible Reporting"
  )) {
    pkg <- make_temp_dir()
    write_pkg(pkg, title = bad)
    expect_false(
      diagnose_description_issues(
        pkg,
        verbose = FALSE
      )$title_redundant_phrases$passed,
      info = bad
    )
  }

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, title = "Statistical Modeling")
  expect_true(
    diagnose_description_issues(
      pkg_ok,
      verbose = FALSE
    )$title_redundant_phrases$passed
  )
})

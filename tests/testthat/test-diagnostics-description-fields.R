# Test lab_date_format() ----

test_that("lab_date_format(): passes when Date is absent, the preferred case", {
  expect_true(
    lab_date_format(make_temp_dir(), verbose = FALSE, desc = list(Package = "x"))$passed
  )
})

test_that("lab_date_format(): passes on a current ISO-8601 date", {
  today <- format(Sys.Date())
  expect_true(
    lab_date_format(make_temp_dir(), verbose = FALSE, desc = list(Date = today))$passed
  )
})

test_that("lab_date_format(): flags a non-ISO-8601 Date", {
  res <- lab_date_format(make_temp_dir(), verbose = FALSE, desc = list(Date = "Jan 2020"))
  expect_false(res$passed)
  expect_true(any(grepl("ISO 8601", res$issues)))
})

test_that("lab_date_format(): flags a stale Date read from the package file", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "Date: 2000-01-01")
  res <- diagnose_description_issues(pkg, verbose = FALSE)$date_format
  expect_false(res$passed)
  expect_true(any(grepl("month old", res$issues)))
})

test_that("lab_date_format(): flags a future Date", {
  expect_false(
    lab_date_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Date = "2999-01-01")
    )$passed
  )
})

# Test lab_encoding_utf8() ----

test_that("lab_encoding_utf8(): accepts UTF-8 or none", {
  expect_true(
    lab_encoding_utf8(make_temp_dir(), verbose = FALSE, desc = list(Encoding = "UTF-8"))$passed
  )
  expect_true(
    lab_encoding_utf8(make_temp_dir(), verbose = FALSE, desc = list(Package = "x"))$passed
  )
})

test_that("lab_encoding_utf8(): flags any other Encoding, as CRAN incoming does", {
  # R's incoming check compares with "UTF-8" exactly, so latin1, latin2 and
  # even a lower-case utf-8 draw its "Package encoding ... is deprecated" NOTE.
  for (enc in c("latin1", "latin2", "utf-8", "KOI8-R")) {
    res <- lab_encoding_utf8(make_temp_dir(), verbose = FALSE, desc = list(Encoding = enc))
    expect_false(res$passed, info = enc)
    expect_identical(
      res$issues,
      paste0(
        "Encoding is \"", enc, "\"; CRAN's incoming check says package ",
        "encoding '", enc, "' is deprecated and asks for UTF-8"
      ),
      info = enc
    )
  }
})

# Test lab_version_format() ----

test_that("lab_version_format(): passes on ordinary versions and dated ones", {
  expect_true(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = "0.2.0")
    )$passed
  )
  dated <- paste0(format(Sys.Date(), "%Y"), ".1")
  expect_true(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = dated)
    )$passed
  )
})

test_that("lab_version_format(): flags a leading-zero component", {
  res <- lab_version_format(make_temp_dir(),
    verbose = FALSE,
    desc = list(Version = "0.02.0")
  )
  expect_false(res$passed)
  expect_true(any(grepl("leading zero", res$issues)))
})

test_that("lab_version_format(): flags a suspiciously large component", {
  expect_false(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = "9999.1")
    )$passed
  )
})

test_that("lab_version_format(): flags an unparseable version", {
  res <- lab_version_format(make_temp_dir(),
    verbose = FALSE,
    desc = list(Version = "not.a.version")
  )
  expect_false(res$passed)
  expect_true(any(grepl("not a valid", res$issues)))
})

test_that("lab_version_format(): exempts dated and dev versions", {
  # a calendar-versioned package from a prior year, a zero-padded month, and the
  # ubiquitous .9000 development suffix are all legitimate, not oversized.
  expect_true(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = "2025.4")
    )$passed
  )
  expect_true(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = "2026.01")
    )$passed
  )
  expect_true(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = "0.2.0.9000")
    )$passed
  )
})

# Test lab_description_fields() ----

test_that("lab_description_fields(): accepts R's fields and the forms it allows", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = c(
    "URL: https://example.org",
    "BugReports: https://example.org/issues",
    "Imports: stats",
    "Suggests: testthat (>= 3.0.0)",
    "VignetteBuilder: knitr",
    "Additional_repositories: https://example.org/drat",
    "Roxygen: list(markdown = TRUE)",
    "RoxygenNote: 7.3.2",
    "Config/testthat/edition: 3",
    "Config/Needs/website: pkgdown",
    "X-CRAN-Comment: Orphaned.",
    "VCS/git: https://example.org/repo.git",
    "Language: en-GB",
    "biocViews: Software"
  ))
  res <- lab_description_fields(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_identical(res$issues, character(0))
})

test_that("lab_description_fields(): flags Remotes, which CRAN does not know", {
  d <- list(Package = "x", Remotes = "user/otherpkg")
  res <- lab_description_fields(make_temp_dir(), verbose = FALSE, desc = d)
  expect_false(res$passed)
  expect_identical(
    res$issues,
    paste0(
      "Remotes: not a DESCRIPTION field R knows; CRAN installs dependencies ",
      "from CRAN and Bioconductor only, so remove it before submitting"
    )
  )
})

test_that("lab_description_fields(): names the field a typo was meant to be", {
  d <- list(
    Package = "x", Bugreports = "https://example.org/issues",
    Import = "stats", Suggest = "testthat", URLs = "https://example.org"
  )
  res <- lab_description_fields(make_temp_dir(), verbose = FALSE, desc = d)
  expect_identical(
    res$issues,
    c(
      "Bugreports: not a DESCRIPTION field R knows; did you mean BugReports?",
      "Import: not a DESCRIPTION field R knows; did you mean Imports?",
      "Suggest: not a DESCRIPTION field R knows; did you mean Suggests?",
      "URLs: not a DESCRIPTION field R knows; did you mean URL?"
    )
  )
  res <- lab_description_fields(
    make_temp_dir(),
    verbose = FALSE,
    desc = list(Package = "x", Frobnicate = "yes")
  )
  expect_identical(res$issues, "Frobnicate: not a DESCRIPTION field R knows")
})

test_that("lab_description_fields(): knows every field R's incoming check knows", {
  # The list is copied from tools:::.get_standard_DESCRIPTION_fields() rather
  # than called through `:::`, so this holds the copy to R.
  expect_setequal(
    STANDARD_DESCRIPTION_FIELDS,
    tools:::.get_standard_DESCRIPTION_fields()
  )
})

test_that("lab_description_fields(): runs with the DESCRIPTION panel at policy tier", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "Remotes: user/otherpkg")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$description_fields$passed)
  expect_identical(check_severity("description_fields"), "policy")
})

# Test lab_description_placeholders() ----

test_that("lab_description_placeholders(): flags the usethis template", {
  d <- list(
    Title = "What the Package Does (One Line, Title Case)",
    Description = "What the package does (one paragraph)."
  )
  res <- lab_description_placeholders(make_temp_dir(), verbose = FALSE, desc = d)
  expect_false(res$passed)
  expect_identical(
    res$issues,
    c(
      "Title is template text: What the Package Does (One Line, Title Case)",
      "Description is template text: What the package does (one paragraph)."
    )
  )
})

test_that("lab_description_placeholders(): flags the package.skeleton() template", {
  d <- list(
    Title = "What the Package Does (Short Line)",
    Description = "More about what it does (maybe more than one line).",
    Author = "Who wrote it",
    Maintainer = "Who to complain to <yourfault@somewhere.net>"
  )
  res <- lab_description_placeholders(make_temp_dir(), verbose = FALSE, desc = d)
  expect_identical(
    sub(":.*", "", res$issues),
    c(
      "Title is template text", "Description is template text",
      "Author is template text", "Maintainer is template text"
    )
  )
  d <- list(Maintainer = "The package maintainer <m@example.org>")
  expect_false(
    lab_description_placeholders(make_temp_dir(), verbose = FALSE, desc = d)$passed
  )
})

test_that("lab_description_placeholders(): passes a filled-in DESCRIPTION", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_description_placeholders(pkg, verbose = FALSE)$passed)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$description_placeholders$passed)
  expect_identical(check_severity("description_placeholders"), "policy")
})

# Test lab_description_file() ----

test_that("lab_description_file(): passes a DESCRIPTION R can read", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  res <- lab_description_file(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_length(res$issues, 0L)
})

test_that("lab_description_file(): flags a line that is neither field nor continuation", {
  res <- lab_description_file(unparseable_pkg(), verbose = FALSE)
  expect_false(res$passed)
  expect_length(res$issues, 1L)
  expect_match(res$issues, "^DESCRIPTION does not parse: ")
  # read.dcf()'s own reason, which quotes the start of the offending line.
  expect_match(res$issues, "this line is not a f", fixed = TRUE)
})

test_that("lab_description_file(): flags a blank line that splits the file", {
  # read.dcf() reads the text after a blank line as a second record. R's own
  # reader refuses that file, while checktor used to keep the first record and
  # read on, losing every field after the blank line.
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = c("", "Suggests: testthat"))
  res <- lab_description_file(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(
    res$issues,
    "DESCRIPTION contains a blank line, which splits it into more than one record"
  )
})

test_that("lab_description_file(): flags a missing DESCRIPTION", {
  skip_if_tempdir_in_package()
  res <- lab_description_file(make_temp_dir(), verbose = FALSE)
  expect_false(res$passed)
  expect_identical(res$issues, "DESCRIPTION file not found")
})

test_that("lab_description_file(): gives the reason R cannot open DESCRIPTION", {
  # read.dcf() stops with "cannot open the connection" and leaves the reason in
  # a warning, which used to reach the console while the issue said only that.
  pkg <- unopenable_pkg("directory")
  expect_no_warning(res <- lab_description_file(pkg, verbose = FALSE))
  expect_false(res$passed)
  expect_identical(res$issues, "DESCRIPTION is a directory, not a file")

  skip_on_os("windows") # a mode-000 file is not portable
  pkg <- unopenable_pkg("no_permission")
  skip_if(
    file.access(file.path(pkg, "DESCRIPTION"), 4L) == 0L,
    "this user can read a file with no read permission"
  )
  expect_no_warning(res <- lab_description_file(pkg, verbose = FALSE))
  expect_identical(
    res$issues,
    "DESCRIPTION cannot be read (permission denied)"
  )
})

test_that("lab_description_file(): gives the same reason in any language", {
  # The reason comes from the file system, not from the wording of R's
  # warnings, which a translated session words differently: in German the
  # directory was reported as "does not parse: kann Verbindung nicht öffnen".
  # local_language() sets LANGUAGE and resets R's message cache, as
  # Sys.setLanguage() does, and puts both back when the test ends.
  withr::local_language("de")
  pkg <- unopenable_pkg("directory")
  expect_no_warning(res <- lab_description_file(pkg, verbose = FALSE))
  expect_identical(res$issues, "DESCRIPTION is a directory, not a file")

  skip_on_os("windows") # a mode-000 file is not portable
  pkg <- unopenable_pkg("no_permission")
  skip_if(
    file.access(file.path(pkg, "DESCRIPTION"), 4L) == 0L,
    "this user can read a file with no read permission"
  )
  expect_no_warning(res <- lab_description_file(pkg, verbose = FALSE))
  expect_identical(
    res$issues,
    "DESCRIPTION cannot be read (permission denied)"
  )
})

test_that("lab_description_file(): takes desc like the other DESCRIPTION checks", {
  expect_identical(
    names(formals(lab_description_file)),
    c("path", "verbose", "desc")
  )
  # The question is about the file, so parsed fields handed in do not answer it.
  res <- lab_description_file(unparseable_pkg(),
    verbose = FALSE,
    desc = list(Package = "fine")
  )
  expect_false(res$passed)
  expect_match(res$issues, "^DESCRIPTION does not parse: ")
})

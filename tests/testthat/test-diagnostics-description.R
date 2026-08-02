# Regression tests for the DESCRIPTION-file diagnostics, especially that
# multi-line fields (Description, Title) are read in full via read.dcf.

test_that("description_length reads continuation lines, not just the first line", {
  pkg <- make_temp_dir()
  long_desc <- paste(
    "First sentence with enough words to fool nobody.",
    "    Second continuation sentence with even more words.",
    "    Third line continuing to make sure word counting picks it up.",
    sep = "\n"
  )
  write_pkg(pkg, description = long_desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$description_length$passed)
  expect_gte(res$description_length$words, 20L)
  expect_gte(res$description_length$sentences, 2L)
})

test_that("description_length still flags genuinely short descriptions", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Short.")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$description_length$passed)
})

test_that("software_names_formatting inspects continuation lines of Description", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Provides utilities.",
    "    Builds on ggplot2 (without quotes) and dplyr too.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$software_names$passed)
  expect_true(any(grepl("ggplot2", res$software_names$issues)))
})

test_that("software_names_formatting accepts properly quoted names", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Wraps 'ggplot2' and 'dplyr' for convenience.")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$software_names$passed)
})

test_that("software_names_formatting does NOT flag the bare letter R", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = "A package for R users that integrates with 'ggplot2'."
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$software_names$passed)
})

test_that("software_names_formatting flags an unquoted WebAssembly", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Runs R code in a WebAssembly runtime.")
  res <- lab_software_names(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_true(any(grepl("WebAssembly", res$issues)))

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, description = "Runs R code in a 'WebAssembly' runtime.")
  expect_true(
    lab_software_names(pkg_ok, verbose = FALSE)$passed
  )
})

test_that("language_names flags bare programming-language names", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Bridges R with Python and an SQL backend.")
  res <- lab_language_names(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_true(any(grepl("Python", res$issues)))
  expect_true(any(grepl("SQL", res$issues)))
})

test_that("language_names accepts quoted names and does not flag bare R", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Bridges R with 'Python' and an 'SQL' backend.")
  expect_true(lab_language_names(pkg, verbose = FALSE)$passed)
})

test_that("language_names is a distinct policy check from software_names", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Bridges R with Python and 'ggplot2'.")
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  # Python flags language_names (policy), ggplot2 is quoted so software_names passes.
  expect_false(r$description_issues$language_names$passed)
  expect_true(r$description_issues$software_names$passed)
  expect_true("description.language_names" %in% failed_checks(r))
})

test_that("language_names flags C++ but never matches inside a larger token", {
  # "C++" carries regex metacharacters; quoting it clears the flag.
  bad <- make_temp_dir()
  write_pkg(bad, description = "Exposes a C++ engine to R.")
  res <- lab_language_names(bad, verbose = FALSE)
  expect_false(res$passed)
  expect_true(any(grepl("C++", res$issues, fixed = TRUE)))

  ok <- make_temp_dir()
  write_pkg(ok, description = "Exposes a 'C++' engine to R.")
  expect_true(lab_language_names(ok, verbose = FALSE)$passed)

  # SQL inside PostgreSQL, and Java inside JavaScript, must not be flagged.
  edge <- make_temp_dir()
  write_pkg(edge, description = "Reads a PostgreSQL dump with a 'JavaScript' viewer.")
  expect_true(lab_language_names(edge, verbose = FALSE)$passed)
})

test_that("language_names covers statistical-computing environments", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Imports data from MATLAB and SAS into R.")
  res <- lab_language_names(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_true(any(grepl("MATLAB", res$issues)))
  expect_true(any(grepl("SAS", res$issues)))
})

test_that("language_names covers scripting, markup and data formats", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Renders Markdown, reads YAML, and drives Tcl widgets.")
  res <- lab_language_names(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_true(any(grepl("Markdown", res$issues)))
  expect_true(any(grepl("YAML", res$issues)))
  expect_true(any(grepl("Tcl", res$issues)))

  # TeX must not match inside LaTeX.
  ok <- make_temp_dir()
  write_pkg(ok, description = "Builds a manual with 'LaTeX' output.")
  expect_true(lab_language_names(ok, verbose = FALSE)$passed)
})

test_that("description_quoted_quotes flags double-quoted software names", {
  # The check only inspects DOUBLE-quoted spans, so a single-quoted fixture
  # exits before is_software_name() is ever consulted and proves nothing about
  # the vocabulary. Double quotes are what put SOFTWARE_NAMES under test.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste0(
      "Builds links for \"WebAssembly\" (\"WASM\") and \"webR\" apps, ",
      "including \"Shinylive\" bundles."
    )
  )
  res <- lab_description_quoted_quotes(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 4L)
  expect_match(res$issues, "WebAssembly", all = FALSE)
  expect_match(res$issues, "WASM", all = FALSE)
  expect_match(res$issues, "webR", all = FALSE)
  expect_match(res$issues, "Shinylive", all = FALSE)
})

test_that("description_quoted_quotes leaves scare-quoted English alone", {
  # Double-quoted ordinary jargon IS what double quotes are reserved for; only
  # a recognised software name is a finding.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste0(
      "Fits models for so-called \"labeled\" designs and the \"no choice\" ",
      "variant used in discrete-choice work."
    )
  )
  expect_true(lab_description_quoted_quotes(pkg, verbose = FALSE)$passed)
})

test_that("quoted WebAssembly/WASM/webR are recognised, not scare-quoted", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = "Builds links for 'WebAssembly' ('WASM') and 'webR' apps."
  )
  expect_true(lab_description_quoted_quotes(pkg, verbose = FALSE)$passed)
})

# ---- title_length ------------------------------------------------------------

test_that("title_length flags a title longer than 65 characters", {
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

test_that("title_length puts the boundary between 65 and 66 characters", {
  # The other fixtures are 99 and 21 characters, which leaves the threshold free
  # to move anywhere in 22..99 undetected. Pin it exactly.
  #
  # 65 is the width Writing R Extensions says a listing may truncate to, not a
  # limit, so a title of exactly 65 characters shows in full and is not a
  # finding. 375 packages on CRAN sit at exactly 65.
  for (n in c(64L, 65L)) {
    ok <- lab_title_length(verbose = FALSE, desc = c(Title = strrep("W", n)))
    expect_true(ok$passed, info = paste(n, "characters"))
    expect_equal(ok$nchar, n)
  }

  bad <- lab_title_length(verbose = FALSE, desc = c(Title = strrep("W", 66)))
  expect_false(bad$passed)
  expect_equal(length(bad$issues), 1L)
  expect_match(bad$issues, "66 characters", all = FALSE)
  # The message says how much would be lost, not just that it is long.
  expect_match(bad$issues, "last 1 character", all = FALSE)
})

# ---- description_function_quotes ---------------------------------------------

test_that("description_function_quotes flags single-quoted function names", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      "Wraps the 'lm()' interface for users.",
      "It does a number of helpful things here."
    )
  )
  # Not part of a run any more: WRE says single quotes are for non-English usage
  # INCLUDING other packages, an inclusive list, so a quoted function name breaks
  # no rule. Still callable directly.
  expect_false(
    lab_description_function_quotes(pkg, verbose = FALSE)$passed
  )
  expect_null(
    diagnose_description_issues(
      pkg,
      verbose = FALSE
    )$description_function_quotes
  )
})

test_that("description_function_quotes accepts quoted software names", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      "Provides an interface to 'ggplot2' graphics.",
      "It does a number of helpful things here."
    )
  )
  expect_true(
    lab_description_function_quotes(pkg, verbose = FALSE)$passed
  )
})

test_that("authors_field is OK when Authors@R is present, fails otherwise", {
  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok)
  expect_true(
    diagnose_description_issues(pkg_ok, verbose = FALSE)$authors$passed
  )

  pkg_legacy <- make_temp_dir()
  write_pkg(
    pkg_legacy,
    authors_r = NULL,
    author = "A. Tester",
    maintainer = "A. Tester <a@example.com>"
  )
  expect_false(
    diagnose_description_issues(pkg_legacy, verbose = FALSE)$authors$passed
  )
})

test_that("acronym detection knows common abbreviations and reads continuations", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Provides bindings to the OS for HTTP work.", # OS in unexplained set
    "    Includes XYZ helpers for fun.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  # XYZ should be flagged; OS is in the common-abbreviations list.
  expect_false(res$acronyms$passed)
  expect_true("XYZ" %in% res$acronyms$issues)
  expect_false("OS" %in% res$acronyms$issues)
  expect_false("HTTP" %in% res$acronyms$issues)
})

test_that("acronym check treats 'expansion (ACRONYM)' as explained (#5)", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Calculate and plot r2 coefficients between principal component",
    "    analysis (PCA) components and covariates. The idea is to search",
    "    for components which are explained by the covariates.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$acronyms$passed)
  expect_false("PCA" %in% res$acronyms$issues)
})

test_that("acronym check reads a gloss whose expansion is a quoted software name", {
  # software_names requires a software name to be single-quoted, so the standard
  # gloss is "'WebAssembly' (WASM)". Anchoring the gloss to a word character put
  # the closing quote in the way, and checktor reported an acronym as unexplained
  # for obeying its own policy check.
  for (q in c("'WebAssembly'", "‘WebAssembly’", "\"WebAssembly\"")) {
    res <- lab_acronyms(
      verbose = FALSE,
      desc = c(Description = paste0("Creates links for ", q, " (WASM) documents."))
    )
    expect_true(res$passed, info = q)
  }
  # A bare acronym with no expansion in front of it is still reported.
  bare <- lab_acronyms(
    verbose = FALSE,
    desc = c(Description = "Creates links for WASM documents.")
  )
  expect_false(bare$passed)
  expect_true("WASM" %in% bare$issues)
})

test_that("acronym check treats 'ACRONYM (expansion)' as explained", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Runs PCA (principal component analysis) over supplied matrices and",
    "    returns the resulting components for downstream modelling work.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$acronyms$passed)
  expect_false("PCA" %in% res$acronyms$issues)
})

test_that("acronym check still flags genuinely unexplained acronyms", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Provides FOOBAR utilities for the analysis of tabular data and the",
    "    production of summaries across many datasets and output formats.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$acronyms$passed)
  expect_true("FOOBAR" %in% res$acronyms$issues)
})

# ---- authors: template placeholders (the pcaR2 false negative) ----------------

test_that("authors_field flags an unfilled usethis template", {
  # pcaR2 shipped exactly this and checktor's presence-only check passed it, even
  # though it is a hard CRAN rejection. R CMD check says nothing: the field IS
  # present, so it has nothing to complain about.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    authors_r = paste0(
      "person(\"First\", \"Last\", , \"january.weiner@gmail.com\", ",
      "role = c(\"aut\", \"cre\", \"cph\"))"
    )
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)$authors
  expect_false(res$passed)
  expect_true(any(grepl("placeholder", res$issues)))
})

test_that("authors_field flags a placeholder email and Your Name", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    authors_r = paste0(
      "person(\"Your Name\", , , \"you@example.com\", role = c(\"aut\", \"cre\"))"
    )
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)$authors
  expect_false(res$passed)
  # Both placeholders must be named. The email detector alone satisfies
  # `passed == FALSE`, so without this the "Your Name" entry could vanish from
  # the placeholder list unnoticed.
  expect_match(res$issues, "Your Name", all = FALSE)
  expect_match(res$issues, "you@example.com", all = FALSE)
})

test_that("authors_field does not invent placeholders in a real name", {
  # "Firstname Lastly" contains the placeholder words as substrings; the word
  # boundaries in the matcher are what keep this a pass.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    authors_r = paste0(
      "person(\"Firstname\", \"Lastly\", email = \"f.lastly@university.edu\", ",
      "role = c(\"aut\", \"cre\"))"
    )
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)$authors
  expect_true(res$passed)
  expect_equal(length(res$issues), 0L)
})

test_that("authors_field passes a real, filled-in Authors@R", {
  pkg <- make_temp_dir()
  write_pkg(pkg) # helper default is a real name/email
  expect_true(diagnose_description_issues(pkg, verbose = FALSE)$authors$passed)
})

# --- title_case (restored, now delegating to tools::toTitleCase) ------------

test_that("lab_title_case does not flag a quoted software name", {
  # This is the false positive that made the homegrown word-loop unusable.
  # R's own engine restores single-quoted spans before comparing, so 'shiny'
  # keeps its lowercase s.
  desc <- c(Title = "Extra Diagnostics for 'shiny' and 'rmarkdown' Packages")
  expect_true(lab_title_case(verbose = FALSE, desc = desc)$passed)
})

test_that("lab_title_case flags a genuinely non-title-case Title", {
  desc <- c(Title = "A package for running extra checks")
  res <- lab_title_case(verbose = FALSE, desc = desc)
  expect_false(res$passed)
  # The suggestion must carry the corrected string so it can be pasted in.
  expect_match(res$issues, "Running Extra Checks", fixed = TRUE, all = FALSE)
})

test_that("lab_title_case accepts a correct Title", {
  desc <- c(Title = "Extra CRAN Diagnostics for R Packages")
  expect_true(lab_title_case(verbose = FALSE, desc = desc)$passed)
})

# --- license (restored, now delegating to tools::analyze_license) -----------

test_that("lab_license accepts a standardizable license", {
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

test_that("lab_license flags a non-standardizable license", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  res <- lab_license(
    pkg,
    verbose = FALSE,
    desc = c(License = "Do whatever you like")
  )
  expect_false(res$passed)
})

test_that("lab_license flags a missing referenced LICENSE file", {
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

# --- description_starts_with (restored, broadened) --------------------------

test_that("lab_description_starts_with flags CRAN's forbidden openers", {
  for (bad in c(
    "This package provides tools for X.",
    "A package that does X.",
    "In this package we do X."
  )) {
    res <- lab_description_starts_with(
      verbose = FALSE,
      desc = c(Description = bad)
    )
    expect_false(res$passed, info = bad)
  }
})

test_that("lab_description_starts_with flags a lowercase initial", {
  # R's own descr_bad_initial rule, which checktor previously lacked.
  res <- lab_description_starts_with(
    verbose = FALSE,
    desc = c(Description = "runs extra diagnostics on R packages.")
  )
  expect_false(res$passed)
})

test_that("lab_description_starts_with accepts a well-formed Description", {
  expect_true(
    lab_description_starts_with(
      verbose = FALSE,
      desc = c(Description = "Runs extra diagnostics on R packages.")
    )$passed
  )
})

# --- license_year (rebuilt: template placeholders, not year staleness) ------

test_that("lab_license_year flags an unfilled LICENSE template", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c("YEAR: <YEAR>", "COPYRIGHT HOLDER: <COPYRIGHT HOLDER>"),
    file.path(pkg, "LICENSE")
  )
  res <- lab_license_year(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("lab_license_year does not flag an old but filled-in year", {
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

test_that("lab_license_year passes when there is no LICENSE file", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_license_year(pkg, verbose = FALSE)$passed)
})

test_that("description_length measures words, not sentences", {
  # renderthis ships a complete 31-word single-sentence Description. Demanding
  # "2+ sentences" has no authority and flagged it.
  one_sentence <- paste(
    "Render slides to different formats, including 'html', 'pdf', 'png', 'gif',",
    "'pptx', and 'mp4', as well as a 'social' output, a 'png' of the first slide",
    "re-sized for sharing on social media."
  )
  expect_true(
    lab_description_length(
      verbose = FALSE,
      desc = c(Description = one_sentence)
    )$passed
  )
})

test_that("description_length still flags a Description that says nothing", {
  res <- lab_description_length(
    verbose = FALSE,
    desc = c(Description = "Does stuff.")
  )
  expect_false(res$passed)
})

# ---- date_format -------------------------------------------------------------

test_that("date_format passes when Date is absent (the preferred case)", {
  expect_true(
    lab_date_format(verbose = FALSE, desc = list(Package = "x"))$passed
  )
})

test_that("date_format passes on a current ISO-8601 date", {
  today <- format(Sys.Date())
  expect_true(
    lab_date_format(verbose = FALSE, desc = list(Date = today))$passed
  )
})

test_that("date_format flags a non-ISO-8601 Date", {
  res <- lab_date_format(verbose = FALSE, desc = list(Date = "Jan 2020"))
  expect_false(res$passed)
  expect_true(any(grepl("ISO 8601", res$issues)))
})

test_that("date_format flags a stale Date read from the package file", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "Date: 2000-01-01")
  res <- diagnose_description_issues(pkg, verbose = FALSE)$date_format
  expect_false(res$passed)
  expect_true(any(grepl("month old", res$issues)))
})

test_that("date_format flags a future Date", {
  expect_false(
    lab_date_format(
      verbose = FALSE,
      desc = list(Date = "2999-01-01")
    )$passed
  )
})

# ---- encoding_utf8 -----------------------------------------------------------

test_that("encoding_utf8 accepts the portable set (UTF-8, latin1, latin2) or none", {
  for (enc in c("UTF-8", "utf-8", "latin1", "latin2")) {
    expect_true(
      lab_encoding_utf8(
        verbose = FALSE,
        desc = list(Encoding = enc)
      )$passed,
      info = enc
    )
  }
  expect_true(
    lab_encoding_utf8(verbose = FALSE, desc = list(Package = "x"))$passed
  )
})

test_that("encoding_utf8 flags a non-portable Encoding", {
  res <- lab_encoding_utf8(
    verbose = FALSE,
    desc = list(Encoding = "KOI8-R")
  )
  expect_false(res$passed)
  expect_true(any(grepl("portable", res$issues)))
})

# ---- version_format ----------------------------------------------------------

test_that("version_format passes on ordinary versions and dated ones", {
  expect_true(
    lab_version_format(
      verbose = FALSE,
      desc = list(Version = "0.2.0")
    )$passed
  )
  dated <- paste0(format(Sys.Date(), "%Y"), ".1")
  expect_true(
    lab_version_format(
      verbose = FALSE,
      desc = list(Version = dated)
    )$passed
  )
})

test_that("version_format flags a leading-zero component", {
  res <- lab_version_format(
    verbose = FALSE,
    desc = list(Version = "0.02.0")
  )
  expect_false(res$passed)
  expect_true(any(grepl("leading zero", res$issues)))
})

test_that("version_format flags a suspiciously large component", {
  expect_false(
    lab_version_format(
      verbose = FALSE,
      desc = list(Version = "9999.1")
    )$passed
  )
})

test_that("version_format flags an unparseable version", {
  res <- lab_version_format(
    verbose = FALSE,
    desc = list(Version = "not.a.version")
  )
  expect_false(res$passed)
  expect_true(any(grepl("not a valid", res$issues)))
})

test_that("version_format exempts dated (prior-year, zero-padded) and dev versions", {
  # a calendar-versioned package from a prior year, a zero-padded month, and the
  # ubiquitous .9000 development suffix are all legitimate, not oversized.
  expect_true(
    lab_version_format(
      verbose = FALSE,
      desc = list(Version = "2025.4")
    )$passed
  )
  expect_true(
    lab_version_format(
      verbose = FALSE,
      desc = list(Version = "2026.01")
    )$passed
  )
  expect_true(
    lab_version_format(
      verbose = FALSE,
      desc = list(Version = "0.2.0.9000")
    )$passed
  )
})

# ---- authors_field structural validity ---------------------------------------

test_that("authors_field passes a well-formed Authors@R", {
  aar <- "person('Jane', 'Doe', email = 'jane@example.org', role = c('aut', 'cre'))"
  expect_true(
    lab_authors(
      verbose = FALSE,
      desc = list(`Authors@R` = aar)
    )$passed
  )
})

test_that("authors_field flags Authors@R with no maintainer (cre)", {
  aar <- "person('Jane', 'Doe', role = 'aut')"
  res <- lab_authors(verbose = FALSE, desc = list(`Authors@R` = aar))
  expect_false(res$passed)
  expect_true(any(grepl("cre", res$issues)))
})

test_that("authors_field flags a person with no name", {
  aar <- "person(role = c('aut', 'cre'))"
  res <- lab_authors(verbose = FALSE, desc = list(`Authors@R` = aar))
  expect_false(res$passed)
  expect_true(any(grepl("no name", res$issues)))
})

test_that("authors_field flags an Authors@R that does not parse", {
  res <- lab_authors(
    verbose = FALSE,
    desc = list(`Authors@R` = "person('Jane',,")
  )
  expect_false(res$passed)
  expect_true(any(grepl("does not parse", res$issues)))
})

# ---- identifier_format -------------------------------------------------------

test_that("identifier_format passes a valid ORCID and no-identifier case", {
  ok <- "person('J', 'D', role = 'cre', comment = c(ORCID = '0000-0002-1825-0097'))"
  expect_true(
    lab_identifier_format(
      verbose = FALSE,
      desc = list(`Authors@R` = ok)
    )$passed
  )
  none <- "person('J', 'D', role = 'cre')"
  expect_true(
    lab_identifier_format(
      verbose = FALSE,
      desc = list(`Authors@R` = none)
    )$passed
  )
})

test_that("identifier_format flags an ORCID that fails its checksum", {
  bad <- "person('J', 'D', role = 'cre', comment = c(ORCID = '0000-0002-1825-0090'))"
  res <- lab_identifier_format(
    verbose = FALSE,
    desc = list(`Authors@R` = bad)
  )
  expect_false(res$passed)
  expect_true(any(grepl("ORCID", res$issues)))
})

test_that("identifier_format accepts an X check-digit and a URL-wrapped ORCID", {
  xd <- "person('J', 'D', role = 'cre', comment = c(ORCID = '0000-0002-1694-233X'))"
  expect_true(
    lab_identifier_format(
      verbose = FALSE,
      desc = list(`Authors@R` = xd)
    )$passed
  )
  url <- "person('J', 'D', role = 'cre', comment = c(ORCID = 'https://orcid.org/0000-0002-1694-233X'))"
  expect_true(
    lab_identifier_format(
      verbose = FALSE,
      desc = list(`Authors@R` = url)
    )$passed
  )
})

test_that("identifier_format validates ROR ids and ignores free-text comments", {
  good <- "person('J', 'D', role = 'cre', comment = c(ROR = '05dxps055'))"
  expect_true(
    lab_identifier_format(
      verbose = FALSE,
      desc = list(`Authors@R` = good)
    )$passed
  )
  bad <- "person('J', 'D', role = 'cre', comment = c(ROR = 'nope'))"
  res <- lab_identifier_format(
    verbose = FALSE,
    desc = list(`Authors@R` = bad)
  )
  expect_false(res$passed)
  expect_true(any(grepl("ROR", res$issues)))
  free <- "person('J', 'D', role = 'cre', comment = 'maintainer since 2020')"
  expect_true(
    lab_identifier_format(
      verbose = FALSE,
      desc = list(`Authors@R` = free)
    )$passed
  )
})

test_that("authors_field flags a person with no role", {
  aar <- "c(person('Jane', 'Doe', role = 'cre'), person('No', 'Role'))"
  res <- lab_authors(verbose = FALSE, desc = list(`Authors@R` = aar))
  expect_false(res$passed)
  expect_true(any(grepl("no role", res$issues)))
})

test_that("authors_field reports a field that evaluates to a non-person", {
  res <- lab_authors(
    verbose = FALSE,
    desc = list(`Authors@R` = "list(1, 2)")
  )
  expect_false(res$passed)
  expect_true(any(grepl("does not (parse|evaluate)", res$issues)))
})

test_that("Authors@R is not executed while diagnosing (no arbitrary code)", {
  # checktor lints other people's packages; a malicious Authors@R must not run.
  marker <- tempfile()
  on.exit(unlink(marker), add = TRUE)
  aar <- sprintf('system(paste0("touch ", shQuote("%s")))', marker)
  res <- lab_authors(verbose = FALSE, desc = list(`Authors@R` = aar))
  expect_false(file.exists(marker)) # the command did not run
  expect_false(res$passed) # and the field is reported, not silently accepted
})

# ---- spelling ----------------------------------------------------------------

test_that("lab_spelling flags DESCRIPTION words and honours a whitelist", {
  skip_if_not(
    nzchar(Sys.which("aspell")) || nzchar(Sys.which("hunspell")),
    "no spell-check backend"
  )
  old <- options(checktor.spelling = TRUE)
  on.exit(options(old), add = TRUE)
  desc <- "Build a WASM REPL for WebAssembly workflows and more."

  pkg <- make_temp_dir()
  write_pkg(pkg, description = desc)
  res <- lab_spelling(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_true(all(c("WASM", "REPL", "WebAssembly") %in% res$issues))

  # accepted via Config/checktor/acronyms
  pkg2 <- make_temp_dir()
  write_pkg(
    pkg2,
    description = desc,
    extra = "Config/checktor/acronyms: WASM, REPL, WebAssembly"
  )
  expect_true(lab_spelling(pkg2, verbose = FALSE)$passed)

  # accepted via a .aspell/ dictionary
  pkg3 <- make_temp_dir()
  write_pkg(pkg3, description = desc)
  dir.create(file.path(pkg3, ".aspell"))
  saveRDS(
    c("WASM", "REPL", "WebAssembly"),
    file.path(pkg3, ".aspell", "words.rds")
  )
  expect_true(lab_spelling(pkg3, verbose = FALSE)$passed)
})

test_that("spelling_accepted_words gathers every whitelist mechanism", {
  # The detection test above is gated behind a backend that no CI leg installs,
  # so the whitelist plumbing is pinned here instead: no aspell/hunspell needed.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = c(
      "Config/checktor/acronyms: WebAssembly",
      "Config/checktor/software_names: Shinylive"
    )
  )
  dir.create(file.path(pkg, ".aspell"))
  saveRDS("WASM", file.path(pkg, ".aspell", "words.rds"))
  dir.create(file.path(pkg, "inst"))
  writeLines("REPL", file.path(pkg, "inst", "WORDLIST"))

  # One word per source, so dropping any single source changes the answer.
  expect_setequal(
    spelling_accepted_words(pkg),
    c("WASM", "REPL", "WebAssembly", "Shinylive")
  )
})

test_that("spelling_accepted_words is empty for a package with no whitelist", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_equal(spelling_accepted_words(pkg), character(0))
})

test_that("lab_spelling reports a skip, not a pass, when turned off", {
  # A skipped check that reads as a passing one is exactly the failure mode the
  # skipped-result contract exists to prevent: the printed summary would drop
  # spelling from "checks did not run".
  old <- options(checktor.spelling = FALSE)
  on.exit(options(old), add = TRUE)
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Build a WASM REPL for WebAssembly.")
  res <- lab_spelling(pkg, verbose = FALSE)
  expect_true(res$skipped)
  expect_true(res$passed)
  expect_equal(length(res$issues), 0L)
})

test_that("lab_spelling reports a skip when no backend is installed", {
  old <- options(checktor.spelling = TRUE)
  on.exit(options(old), add = TRUE)
  # Empty the PATH so Sys.which() finds neither aspell nor hunspell, which is
  # the state every CI leg actually runs in.
  old_path <- Sys.getenv("PATH")
  Sys.setenv(PATH = "")
  on.exit(Sys.setenv(PATH = old_path), add = TRUE)
  skip_if(
    nzchar(Sys.which("aspell")) || nzchar(Sys.which("hunspell")),
    "backend still reachable with an empty PATH"
  )
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Build a WASM REPL for WebAssembly.")
  res <- lab_spelling(pkg, verbose = FALSE)
  expect_true(res$skipped)
  expect_match(res$skip_reason, "backend")
})

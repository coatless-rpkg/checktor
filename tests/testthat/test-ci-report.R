# ci_report() has to produce something the forge can actually parse, so these
# check the shapes rather than only that a string came back.

ci_pkg <- function(envir = parent.frame()) {
  pkg <- make_temp_dir(envir = envir)
  write_pkg(
    pkg,
    r_code = c("a.R" = "f <- function() {\n  x <- T\n  otherpkg:::helper()\n}")
  )
  pkg
}

# A package carrying one finding in each tier, so a severity filter has something
# to actually filter: set.seed() is policy, T is robustness, a two-word
# Description is opinion.
tiered_pkg <- function(envir = parent.frame()) {
  pkg <- make_temp_dir(envir = envir)
  write_pkg(
    pkg,
    description = "Too short.",
    r_code = "f <- function() {\n  set.seed(42)\n  x <- T\n  x\n}"
  )
  pkg
}

# setup.R pins the spelling backend and the URL fetcher off, so exactly these two
# checks do not run in the suite. The skipped tests assert the note verbatim, so
# adding another `console`/`backend` check means updating this vector too.
CI_SKIPPED <- c("spelling", "url_liveness")

test_that("a finding keeps its file and line whatever label it carries", {
  # The parser used to read only "a.R:2", so a labelled finding lost its location
  # and could not be pointed at.
  r <- checktor(ci_pkg(), verbose = FALSE, progress = FALSE)
  di <- issues(r)
  located <- di[!is.na(di$file), ]
  expect_true("tf_usage" %in% located$check)
  expect_true("internal_ns" %in% located$check) # reported as "a.R:3 (pkg:::fn)"
  expect_equal(located$line[located$check == "internal_ns"], 3L)
})

test_that("github annotations name a path a forge can open", {
  r <- checktor(ci_pkg(), verbose = FALSE, progress = FALSE)
  out <- ci_report(r, format = "github", file = NULL)
  expect_true(any(grepl("^::(error|warning|notice) file=", out)))
  # The path is repo-relative, not the bare file name a check reports.
  expect_true(any(grepl("file=R/[^,]+\\.R,line=2", out)))
  expect_true(any(grepl("title=checktor", out, fixed = TRUE)))
})

test_that("the gitlab report is valid JSON in the shape GitLab reads", {
  skip_if_not_installed("jsonlite")
  r <- checktor(ci_pkg(), verbose = FALSE, progress = FALSE)
  f <- file.path(make_temp_dir(), "cq.json")
  ci_report(r, format = "gitlab", file = f)

  parsed <- jsonlite::fromJSON(f)
  expect_true(all(c("description", "check_name", "fingerprint", "severity",
                    "location") %in% names(parsed)))
  expect_true(all(parsed$severity %in% c("blocker", "major", "minor", "info", "critical")))
  expect_true(all(nzchar(parsed$fingerprint)))
  # ...and distinct, or GitLab folds every finding into the one entry. Rendering
  # the same object twice cannot show this: a constant is stable too.
  expect_equal(length(unique(parsed$fingerprint)), nrow(parsed))
  # A fingerprint has to be stable, or every run looks like a new finding.
  f2 <- file.path(make_temp_dir(), "cq2.json")
  ci_report(r, format = "gitlab", file = f2)
  expect_identical(readLines(f), readLines(f2))
})

test_that("the checkstyle report is valid XML", {
  r <- checktor(ci_pkg(), verbose = FALSE, progress = FALSE)
  f <- file.path(make_temp_dir(), "cs.xml")
  ci_report(r, format = "checkstyle", file = f)

  doc <- xml2::read_xml(f)
  expect_gt(length(xml2::xml_find_all(doc, "//file")), 0L)
  errs <- xml2::xml_find_all(doc, "//error")
  expect_gt(length(errs), 0L)
  expect_true(all(xml2::xml_attr(errs, "severity") %in%
                    c("error", "warning", "info")))
})

test_that("the sarif report is valid JSON at version 2.1.0", {
  skip_if_not_installed("jsonlite")
  r <- checktor(ci_pkg(), verbose = FALSE, progress = FALSE)
  f <- file.path(make_temp_dir(), "out.sarif")
  ci_report(r, format = "sarif", file = f)

  parsed <- jsonlite::fromJSON(f)
  expect_equal(parsed$version, "2.1.0")
  expect_equal(parsed$runs$tool$driver$name, "checktor")
  expect_gt(nrow(parsed$runs$results[[1]]), 0L)
})

test_that("severity maps to each forge's own words", {
  expect_equal(ci_severity("policy", "github"), "error")
  expect_equal(ci_severity("opinion", "github"), "notice")
  expect_equal(ci_severity("policy", "gitlab"), "blocker")
  expect_equal(ci_severity("opinion", "checkstyle"), "info")
  expect_equal(ci_severity("robustness", "sarif"), "warning")
  # An unknown tier is treated as a real finding rather than dropped.
  expect_equal(ci_severity("something_new", "github"), "error")
})

test_that("the forge is detected from the variables each one sets", {
  withr_env <- function(vars, code) {
    old <- Sys.getenv(names(vars), unset = NA)
    do.call(Sys.setenv, as.list(vars))
    on.exit({
      for (i in seq_along(vars)) {
        if (is.na(old[[i]])) {
          Sys.unsetenv(names(vars)[[i]])
        } else {
          do.call(Sys.setenv, stats::setNames(list(old[[i]]), names(vars)[[i]]))
        }
      }
    })
    force(code)
  }
  withr_env(c(GITHUB_ACTIONS = "true"), expect_equal(detect_ci(), "github"))
  withr_env(c(GITLAB_CI = "true"), expect_equal(detect_ci(), "gitlab"))
  withr_env(c(TF_BUILD = "True"), expect_equal(detect_ci(), "azure"))
})

test_that("a clean package reports nothing at all", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  # This used to skip when the fixture was dirty, which turned a check that had
  # started over-flagging the baseline into silence instead of a failure.
  expect_true(is_healthy(r))
  expect_length(
    ci_report(r, format = "github", file = NULL, severity = "policy",
              skipped = FALSE),
    0L
  )
})

test_that("severity reports the tiers asked for and no others", {
  r <- checktor(tiered_pkg(), verbose = FALSE, progress = FALSE)

  policy <- ci_report(r, format = "text", file = NULL, severity = "policy",
                      skipped = FALSE)
  expect_length(policy, 1L)
  expect_match(policy, "seed_setting")
  expect_match(policy, "[policy]", fixed = TRUE)

  opinion <- ci_report(r, format = "text", file = NULL, severity = "opinion",
                       skipped = FALSE)
  expect_length(opinion, 1L)
  expect_match(opinion, "description_length")

  both <- ci_report(r, format = "text", file = NULL,
                    severity = c("policy", "robustness"), skipped = FALSE)
  expect_equal(sort(sub(".* \\[.*\\] ([^ ]+) -.*", "\\1", both)),
               c("seed_setting", "tf_usage"))
})

test_that("a mistyped severity tier errors instead of reading as clean", {
  r <- checktor(tiered_pkg(), verbose = FALSE, progress = FALSE)
  expect_error(ci_report(r, format = "text", file = NULL, severity = "opinions"))
})

test_that("a check that did not run is named once in the log formats", {
  r <- checktor(ci_pkg(), verbose = FALSE, progress = FALSE)
  expect_equal(r$metadata$skipped_checks, CI_SKIPPED)

  gh <- ci_report(r, format = "github", file = NULL)
  note <- grep("did not run", gh, value = TRUE)
  # One aggregate line, not one per check: GitHub caps annotations per step, and
  # a check that never ran must not crowd out one that found something.
  expect_length(note, 1L)
  expect_equal(
    note,
    "::notice title=checktor%3A skipped::2 checks did not run: spelling, url_liveness"
  )

  az <- grep("did not run", ci_report(r, format = "azure", file = NULL), value = TRUE)
  expect_length(az, 1L)
  expect_match(az, "spelling, url_liveness", fixed = TRUE)

  txt <- grep("did not run", ci_report(r, format = "text", file = NULL), value = TRUE)
  expect_length(txt, 1L)
  expect_match(txt, "^skipped: 2 checks did not run: spelling, url_liveness$")
})

test_that("skipped = FALSE leaves the note out entirely", {
  r <- checktor(ci_pkg(), verbose = FALSE, progress = FALSE)
  out <- ci_report(r, format = "github", file = NULL, skipped = FALSE)
  expect_false(any(grepl("did not run", out)))
  expect_length(out, 2L) # the two findings, and nothing else
})

test_that("the skipped note stays out of the artifact formats", {
  # gitlab/checkstyle/sarif documents are consumed by a machine, so the note goes
  # to the job log rather than becoming a finding with no location.
  r <- checktor(ci_pkg(), verbose = FALSE, progress = FALSE)
  dir <- make_temp_dir()
  for (fmt in c("gitlab", "checkstyle", "sarif")) {
    f <- file.path(dir, paste0(fmt, ".out"))
    ci_report(r, format = fmt, file = f)
    expect_false(any(grepl("did not run", readLines(f))))
  }
})

test_that("nothing to report still writes a valid empty artifact", {
  skip_if_not_installed("jsonlite")
  # GitLab cannot clear the findings a previous run left on the branch without a
  # fresh report, so an empty one still has to be written and still has to parse.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  dir <- make_temp_dir()

  gl <- file.path(dir, "cq.json")
  ci_report(r, format = "gitlab", file = gl, severity = "policy")
  expect_length(jsonlite::fromJSON(gl), 0L)

  cs <- file.path(dir, "cs.xml")
  ci_report(r, format = "checkstyle", file = cs, severity = "policy")
  doc <- xml2::read_xml(cs)
  expect_length(xml2::xml_find_all(doc, "//error"), 0L)

  sf <- file.path(dir, "out.sarif")
  ci_report(r, format = "sarif", file = sf, severity = "policy")
  parsed <- jsonlite::fromJSON(sf)
  expect_equal(parsed$version, "2.1.0")
  expect_length(parsed$runs$results[[1]], 0L)
})

test_that("a finding with no location is still reported somewhere openable", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Too short.")
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  out <- ci_report(r, format = "text", file = NULL)
  # DESCRIPTION findings carry no line, so they are reported against the file.
  expect_true(any(grepl("^DESCRIPTION:1", out)))
})

test_that("a multi-line finding stays one line in the line-oriented formats", {
  # register_check() means a message is arbitrary text, so this is reachable
  # rather than theoretical. A raw newline would split one Azure logging command
  # into two lines, leaving the tail as plain output, and would turn one text
  # finding into two.
  pkg <- ci_pkg()
  register_check(
    name = "multiline_probe",
    category = "code",
    severity = "policy",
    fn = function(path, verbose = TRUE) {
      checktor_check_result(FALSE, "a.R:1", "first;part]here\nsecond part 100%")
    }
  )
  on.exit(unregister_check("multiline_probe"), add = TRUE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  for (fmt in c("azure", "text")) {
    out <- ci_report(r, format = fmt, file = NULL)
    hit <- grep("multiline_probe", out, value = TRUE)
    expect_length(hit, 1L)
    expect_false(grepl("\n", hit, fixed = TRUE), info = fmt)
  }
  # Azure keeps the escape rather than dropping the second line outright.
  az <- grep("multiline_probe", ci_report(r, format = "azure", file = NULL),
             value = TRUE)
  expect_match(az, "%0A", fixed = TRUE)
  expect_match(az, "second part", fixed = TRUE)
})

test_that("azure escapes the characters that delimit its own command", {
  # `;` separates properties and `]` closes the block, so a property carrying
  # either would be misparsed. The message body sits after `]` and keeps them.
  expect_equal(escape_azure_property("a;b]c"), "a%3Bb%5Dc")
  expect_equal(escape_azure_data("a;b]c"), "a;b]c")
  expect_equal(escape_azure_property("a\nb"), "a%0Ab")
  expect_equal(flatten_lines("a\r\n  b"), "a b")
})

test_that("special characters do not break a format", {
  # A finding carrying <YEAR> or a quote would otherwise produce invalid XML.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(c("YEAR: <YEAR>", "COPYRIGHT HOLDER: <COPYRIGHT HOLDER>"),
             file.path(pkg, "LICENSE"))
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  f <- file.path(make_temp_dir(), "cs.xml")
  ci_report(r, format = "checkstyle", file = f)
  expect_no_error(xml2::read_xml(f))
})

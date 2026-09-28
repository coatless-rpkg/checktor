# Helpers used across the test suite. Auto-loaded by testthat from helper-*.R.

# Creates an empty unique directory that is deleted when the *caller* exits.
# Returns the path. withr owns the teardown, so the fixture does not depend on
# defer_cleanup(), which is code under test.
make_temp_dir <- function(envir = parent.frame()) {
  withr::local_tempdir(pattern = "checktor-test-", .local_envir = envir)
}

# Skips a test whose premise is that nothing above tempdir() is a package. That
# holds on every usual machine, but not when TMPDIR points inside a package tree.
skip_if_tempdir_in_package <- function() {
  dir <- normalizePath(tempdir(), winslash = "/")
  repeat {
    if (file.exists(file.path(dir, "DESCRIPTION"))) {
      skip("tempdir() sits inside a package tree")
    }
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      return(invisible())
    }
    dir <- parent
  }
}

# Writes a minimal but valid package skeleton under `path`. Optional fields
# override the defaults; r_code adds a single R/test.R file.
write_pkg <- function(
  path,
  package = "testpkg",
  title = "Test Package for Health Checks",
  description = NULL,
  authors_r = "person('A', 'Tester', email = 'a@example.com', role = c('aut','cre','cph'))",
  license = "GPL-3",
  author = NULL,
  maintainer = NULL,
  r_code = "test_fn <- function() TRUE",
  rd_files = NULL,
  news = TRUE,
  cran_comments = TRUE,
  extra = NULL
) {
  dir.create(file.path(path, "R"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(path, "man"), recursive = TRUE, showWarnings = FALSE)

  if (is.null(description)) {
    description <- paste0(
      "A test package created by the checktor test suite. It exists ",
      "only to exercise diagnostics with controlled inputs that have ",
      "known properties."
    )
  }

  lines <- c(
    paste0("Package: ", package),
    paste0("Title: ", title),
    "Version: 0.0.1"
  )
  if (!is.null(authors_r)) {
    lines <- c(lines, paste0("Authors@R: ", authors_r))
  }
  if (!is.null(author)) {
    lines <- c(lines, paste0("Author: ", author))
  }
  if (!is.null(maintainer)) {
    lines <- c(lines, paste0("Maintainer: ", maintainer))
  }
  lines <- c(
    lines,
    paste0("Description: ", description),
    paste0("License: ", license),
    "Encoding: UTF-8"
  )
  if (!is.null(extra)) {
    lines <- c(lines, extra)
  }

  writeLines(lines, file.path(path, "DESCRIPTION"))

  if (!is.null(r_code)) {
    # A list, or a named character vector, maps file names to code.
    if (is.list(r_code) || !is.null(names(r_code))) {
      for (nm in names(r_code)) {
        writeLines(r_code[[nm]], file.path(path, "R", nm))
      }
    } else if (is.character(r_code)) {
      writeLines(r_code, file.path(path, "R", "test.R"))
    }
  }

  if (!is.null(rd_files)) {
    for (nm in names(rd_files)) {
      writeLines(rd_files[[nm]], file.path(path, "man", nm))
    }
  }

  # Standard CRAN-prep files (on by default) so a baseline fixture is clean
  # for the general NEWS/cran-comments checks. Pass FALSE to omit them.
  if (isTRUE(news)) {
    writeLines(
      c("# testpkg 0.0.1", "", "* Initial release."),
      file.path(path, "NEWS.md")
    )
  }
  if (isTRUE(cran_comments)) {
    writeLines(
      c("## Test environments", "* local"),
      file.path(path, "cran-comments.md")
    )
  }

  invisible(path)
}

# Package builders shared by several test files. They live here rather than at
# the top of a test file so that neither shuffling a file nor moving a test can
# separate a test from its fixture.

# `...` goes to write_pkg(), e.g. `extra = "Suggests: dplyr"`.
rd_pkg <- function(example, ..., envir = parent.frame()) {
  pkg <- make_temp_dir(envir = envir)
  write_pkg(
    pkg,
    rd_files = list(
      "f.Rd" = c(
        "\\name{f}", "\\alias{f}", "\\title{F}", "\\description{d}",
        "\\value{x}", "\\examples{", example, "}"
      )
    ),
    ...
  )
  pkg
}

script_pkg <- function(lines, dir, file, envir = parent.frame()) {
  pkg <- make_temp_dir(envir = envir)
  write_pkg(pkg)
  dir.create(file.path(pkg, dir), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, file.path(pkg, dir, file))
  pkg
}

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

# A package whose DESCRIPTION R cannot read: the last line is neither a field nor
# an indented continuation, so read.dcf(), and with it R CMD build and INSTALL,
# stops on it.
unparseable_pkg <- function(envir = parent.frame()) {
  pkg <- make_temp_dir(envir = envir)
  write_pkg(pkg, extra = "this line is not a field")
  pkg
}

# A package whose DESCRIPTION is there but cannot be opened: a directory in its
# place, or a file nobody may read. The mode is put back before the directory is
# removed, since withr runs the deferred calls last in, first out.
unopenable_pkg <- function(kind = c("directory", "no_permission"), envir = parent.frame()) {
  kind <- match.arg(kind)
  pkg <- make_temp_dir(envir = envir)
  write_pkg(pkg)
  desc <- file.path(pkg, "DESCRIPTION")
  if (kind == "directory") {
    unlink(desc)
    dir.create(desc)
  } else {
    Sys.chmod(desc, "000")
    withr::defer(Sys.chmod(desc, "644"), envir = envir)
  }
  pkg
}

# A roxygen-managed package: NAMESPACE carries the banner, so the check engages.
write_roxy_pkg <- function(pkg, r_code, namespace) {
  write_pkg(pkg, r_code = r_code)
  writeLines(
    c("# Generated by roxygen2: do not edit by hand", namespace),
    file.path(pkg, "NAMESPACE")
  )
  invisible(pkg)
}

write_unexported_rd <- function(pkg, examples) {
  dir.create(file.path(pkg, "man"), showWarnings = FALSE)
  writeLines(
    c(
      "\\name{helper}",
      "\\alias{helper}",
      "\\title{Helper}",
      "\\description{A helper.}",
      "\\value{NULL}",
      paste0("\\examples{", examples, "}")
    ),
    file.path(pkg, "man", "helper.Rd")
  )
}

# An alias beginning with a regex metacharacter used to become part of a pattern,
# so `[.reproclass` stopped the check with "invalid regular expression" (#18).
write_operator_rd <- function(pkg, aliases, examples) {
  dir.create(file.path(pkg, "man"), showWarnings = FALSE)
  writeLines(
    c(
      paste0("\\name{", aliases[[1]], "}"),
      paste0("\\alias{", aliases, "}"),
      "\\title{Methods}",
      "\\description{Operator methods.}",
      "\\value{An object.}",
      paste0("\\examples{", examples, "}")
    ),
    file.path(pkg, "man", "ops.Rd")
  )
}

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

# lab_rd_bibliography() looks cited keys up in R's own bibliography, which R 4.6.0
# added; on an older R it is skipped, so a test that needs a finding skips too.
skip_without_r_bibliography <- function() {
  testthat::skip_if(is.null(r_bibliography_keys()), "R's bibliography needs R 4.6.0")
}

# A package whose man/f.Rd cites with R's bibliography macros. `description` is
# the text of its \description{}, on line 4 of f.Rd, and `references` the body of
# its \references{}. `refs` maps a file name under the package root, such as
# "inst/REFERENCES.bib", to its lines. `...` goes to write_pkg().
bib_pkg <- function(
  description,
  references = "\\bibshow{*}",
  refs = list("inst/REFERENCES.bib" = BIB_SMITH),
  ...,
  envir = parent.frame()
) {
  pkg <- make_temp_dir(envir = envir)
  write_pkg(
    pkg,
    rd_files = list(
      "f.Rd" = c(
        "\\name{f}", "\\alias{f}", "\\title{F}",
        paste0("\\description{", description, "}"),
        "\\value{x}",
        if (!is.null(references)) paste0("\\references{", references, "}")
      )
    ),
    ...
  )
  for (nm in names(refs)) {
    dir.create(dirname(file.path(pkg, nm)), recursive = TRUE, showWarnings = FALSE)
    writeLines(refs[[nm]], file.path(pkg, nm))
  }
  pkg
}

BIB_SMITH <- c(
  "@Article{smith2020,",
  "  author = {John Smith},",
  "  title = {A Paper},",
  "  journal = {J Stat},",
  "  year = {2020}",
  "}"
)

# A package with an inst/CITATION holding `lines`. `...` goes to write_pkg().
citation_pkg <- function(lines, ..., envir = parent.frame()) {
  pkg <- make_temp_dir(envir = envir)
  write_pkg(pkg, ...)
  dir.create(file.path(pkg, "inst"), showWarnings = FALSE)
  writeLines(lines, file.path(pkg, "inst", "CITATION"), useBytes = TRUE)
  pkg
}

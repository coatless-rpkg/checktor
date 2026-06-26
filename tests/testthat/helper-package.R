# Helpers used across the test suite. Auto-loaded by testthat from helper-*.R.

# Creates an empty unique directory and registers its deletion with on.exit()
# on the *caller's* frame. Returns the path.
make_temp_dir <- function(envir = parent.frame()) {
  path <- tempfile(pattern = "checktor-test-")
  dir.create(path, recursive = TRUE)
  defer_cleanup(path, envir = envir)
  path
}

# Writes a minimal but valid package skeleton under `path`. Optional fields
# override the defaults; r_code adds a single R/test.R file.
write_pkg <- function(path,
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
                      extra = NULL) {
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
  if (!is.null(extra)) lines <- c(lines, extra)

  writeLines(lines, file.path(path, "DESCRIPTION"))

  if (!is.null(r_code)) {
    if (is.list(r_code)) {
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
    writeLines(c("# testpkg 0.0.1", "", "* Initial release."),
               file.path(path, "NEWS.md"))
  }
  if (isTRUE(cran_comments)) {
    writeLines(c("## Test environments", "* local"),
               file.path(path, "cran-comments.md"))
  }

  invisible(path)
}

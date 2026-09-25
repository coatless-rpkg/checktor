#' Diagnose DESCRIPTION File Issues
#'
#' Runs diagnostics against the package DESCRIPTION file. Fields are parsed
#' with [base::read.dcf()] so that multi-line fields like `Description` and
#' `Title` are inspected in full, not just their first physical line.
#'
#' @param path Character. Path to the R package directory. Default: `"."`.
#' @param verbose Logical. Whether to print diagnostic output. Default: `TRUE`.
#'
#' @return
#' List containing one named element per check. Each element is a list with at
#' least `passed`, `issues`, and `message` (see [checktor_check_result()]).
#' When the `DESCRIPTION` is missing or R cannot read it, `description_file`
#' fails, and every check that reads the parsed fields, registered ones
#' included, is reported as skipped with the reason "DESCRIPTION could not be
#' read", since it has nothing to examine.
#'
#' @seealso
#' [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt",
#'                                       show_content = FALSE)
#' results <- diagnose_description_issues(pkg_path, verbose = FALSE)
#' issues(results)     # description-field problems, if any
diagnose_description_issues <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  # Share each parse among this panel's checks; see R/cache.R.
  local_run_cache()
  if (verbose) {
    cli::cli_h2("DESCRIPTION File Health Check")
  }

  desc_file <- file.path(path, "DESCRIPTION")
  desc <- if (file.exists(desc_file)) {
    tryCatch(read_description(desc_file), error = function(e) NULL)
  }

  # Each check that takes a `desc` argument reads the parsed fields rather than
  # the file. The checks come from the table in R/registry.R.
  checks <- builtin_checks_for("description", desc = desc)
  registered <- registered_checks_for("description", desc = desc)

  # A DESCRIPTION R cannot read used to end this category early with no checks in
  # it. Nothing counts a category, only its checks, so checktor() called such a
  # package healthy although R cannot build or install it. `description_file`
  # reports it and counts like any other check. Every check that reads the fields
  # could not run, so each is reported as skipped under its own name, registered
  # checks included, and a clean result elsewhere never hides one. license_year
  # reads LICENSE alone and runs as usual.
  if (is.null(desc)) {
    skip_as <- function(message) {
      force(message)
      function(p, v) {
        checktor_skipped_result(message, "DESCRIPTION could not be read")
      }
    }
    for (nm in names(DESCRIPTION_FIELD_CHECKS)) {
      checks[[nm]] <- skip_as(DESCRIPTION_FIELD_CHECKS[[nm]])
    }
    registered <- lapply(stats::setNames(nm = names(registered)), skip_as)
  }
  run_checks(c(checks, registered), path, verbose)
}

# Returns a named list of DESCRIPTION fields, with multi-line fields collapsed.
# Using read.dcf folds continuation lines into a single string per field.
#
# It refuses what R's own reader, tools:::.read_description(), refuses, so a file
# checktor reads is one R CMD build and INSTALL will read too. The errors name
# the file, because a user calling a lab_*() function directly sees them as is.
read_description <- function(desc_file) {
  # One handler: tryCatch() nests several, so an error raised in the first would
  # be caught again by the second.
  raw <- tryCatch(read_dcf_quietly(desc_file), error = function(e) {
    what <- if (inherits(e, "checktor_unopenable")) {
      "DESCRIPTION "
    } else {
      "DESCRIPTION does not parse: "
    }
    stop(what, conditionMessage(e), call. = FALSE)
  })
  if (nrow(raw) == 0L) {
    stop("DESCRIPTION has no records", call. = FALSE)
  }
  # read.dcf() takes a blank line as the end of a record and reads on, so the
  # fields after it become a second record. R stops on that file; keeping the
  # first record would quietly drop every field after the blank line.
  if (nrow(raw) > 1L) {
    stop(
      "DESCRIPTION contains a blank line, which splits it into more than one record",
      call. = FALSE
    )
  }
  as.list(raw[1L, ])
}

# Resolve the DESCRIPTION for a check that may be called either directly by a
# user (who has a path) or from diagnose_description_issues() (which has already
# parsed it once). Mirrors the `parsed = NULL` convention the code checks use.
#
# A `desc` comes back as the named list read_description() returns, which is
# what the checks read. `desc` is documented as what read.dcf() returns, a
# one-row matrix whose field names are column names, so desc[["Title"]] on it is
# a subscript error; so is a missing field on a named vector. As a list, a
# missing field is NULL.
resolve_description <- function(path, desc) {
  if (is.matrix(desc)) {
    desc <- if (nrow(desc) > 0L) desc[1L, ] else list()
  }
  if (!is.null(desc)) {
    return(as.list(desc))
  }
  desc_file <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_file)) {
    cli::cli_abort("No {.file DESCRIPTION} found at {.path {path}}")
  }
  read_description(desc_file)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# `desc` is a named list from read_description() or resolve_description(), or a
# named character vector. `desc[["Nope"]]` on a vector is a subscript error, not
# NULL, so any code that may be handed one and reads a field it does not itself
# require must go through this.
dcf_field <- function(desc, field) {
  if (!field %in% names(desc)) {
    return(NULL)
  }
  desc[[field]]
}

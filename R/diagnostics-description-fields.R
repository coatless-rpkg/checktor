# DESCRIPTION checks on the file itself and its field formats.

#' Diagnose a DESCRIPTION File R Cannot Read
#'
#' Flags a `DESCRIPTION` that is missing or that R cannot read: a line that is
#' neither a `Field: value` pair nor an indented continuation, or a blank line
#' that splits the file in two. `R CMD build` and `R CMD INSTALL` both stop on
#' such a file, so the package cannot be built or installed. A `DESCRIPTION`
#' R cannot open at all fails with the reason, a directory in its place or a
#' file without read permission, which is found from the file system and so
#' reads the same in any language. Every other `DESCRIPTION` check reads the
#' parsed fields, so while this one fails they are reported as skipped.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", specifies the format of a Debian Control File:
#' "Fields start with an ASCII name immediately followed by a colon" and
#' "Continuation lines ... start with a space or tab". R reads it with
#' [base::read.dcf()] and refuses a file that yields more than one record. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @inheritParams lab_description_fields
#' @param desc Present for signature parity with the other DESCRIPTION checks;
#'   this check asks whether R can read the `DESCRIPTION` file itself, so it
#'   reads the file and ignores `desc`.
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/unparseable_description.txt",
#'                                  show_content = FALSE)
#' lab_description_file(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_description_file <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc_file <- file.path(path, "DESCRIPTION")
  issues <- if (!file.exists(desc_file)) {
    "DESCRIPTION file not found"
  } else {
    tryCatch(
      {
        read_description(desc_file)
        character(0)
      },
      error = function(e) conditionMessage(e)
    )
  }
  report_check(
    issues,
    verbose,
    check_label("description_file"),
    "{.file DESCRIPTION} parses",
    "R cannot read {.file DESCRIPTION}",
    treatment = paste("Treatment:", treatments$description_file$treatment)
  )
}

# The DESCRIPTION fields R knows, copied from
# tools:::.get_standard_DESCRIPTION_fields() (R 4.6.1) rather than called
# through `:::`. A test holds the copy to R.
STANDARD_DESCRIPTION_FIELDS <- c(
  "Package", "Version", "Priority", "Depends", "Imports", "LinkingTo",
  "Suggests", "Enhances", "License", "License_is_FOSS",
  "License_restricts_use", "OS_type", "Archs", "MD5sum",
  "NeedsCompilation", "Additional_repositories", "Author", "Authors@R",
  "Biarch", "BugReports", "BuildKeepEmpty", "BuildManual",
  "BuildResaveData", "BuildVignettes", "Built", "ByteCompile",
  "Classification/ACM", "Classification/ACM-2012", "Classification/JEL",
  "Classification/MSC", "Classification/MSC-2010", "Collate",
  "Collate.unix", "Collate.windows", "Contact", "Copyright", "Date",
  "Description", "Encoding", "KeepSource", "Language", "LazyData",
  "LazyDataCompression", "LazyLoad", "MailingList", "Maintainer", "Note",
  "Packaged", "RdMacros", "StagedInstall", "SysDataCompression",
  "SystemRequirements", "Title", "Type", "URL", "UseLTO",
  "VignetteBuilder", "ZipData", "Repository", "Path", "Date/Publication",
  "LastChangedDate", "LastChangedRevision", "Revision", "RcmdrModels",
  "RcppModules", "Roxygen", "Acknowledgements", "Acknowledgments",
  "biocViews"
)

# The field-name prefixes R's incoming check lets through, as it writes them.
DESCRIPTION_FIELD_PREFIXES <- c(
  "X-CRAN", "X-schema.org", "Repository/R-Forge", "VCS/", "Config/"
)

#' Diagnose DESCRIPTION Fields R Does Not Know
#'
#' Flags a `DESCRIPTION` field that is not one of the fields R knows, which is
#' how CRAN's incoming check reads it. The usual one is `Remotes`, which
#' `devtools` and `pak` read but CRAN does not, since CRAN installs
#' dependencies from CRAN and Bioconductor alone. The others are typos such as
#' `Bugreports`, `Import`, `Suggest` or `URLs`, which R ignores, so the field
#' meant is silently missing; the finding names the field that was probably
#' meant.
#'
#' The fields R allows beyond its own list are allowed here too: any
#' `Config/` field, such as `Config/testthat/edition`, and fields starting
#' `X-CRAN`, `X-schema.org`, `Repository/R-Forge` or `VCS/`, and a standard
#' field name followed by `Note`, such as `RoxygenNote`.
#'
#' @section Source:
#' The
#' [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' run by `R CMD check --as-cran` NOTEs "Unknown, possibly misspelled, fields in
#' DESCRIPTION". The
#' [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' says "The strong dependencies ... should be available from CRAN or the
#' Bioconductor software repository", which is why a `Remotes` field has no
#' place in a submission. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/description_fields_bad.txt",
#'                                  show_content = FALSE)
#' lab_description_fields(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_description_fields <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  fields <- names(desc)
  prefix <- paste0("^(", paste(DESCRIPTION_FIELD_PREFIXES, collapse = "|"), ")")
  unknown <- fields[
    !fields %in% STANDARD_DESCRIPTION_FIELDS &
      !grepl(prefix, fields) &
      !fields %in% paste0(STANDARD_DESCRIPTION_FIELDS, "Note")
  ]
  issues <- vapply(
    unknown,
    function(field) {
      what <- paste0(field, ": not a DESCRIPTION field R knows")
      if (identical(field, "Remotes")) {
        return(paste0(
          what, "; CRAN installs dependencies from CRAN and Bioconductor only, ",
          "so remove it before submitting"
        ))
      }
      # A near miss is a typo: R ignores the field, so the one meant is missing.
      d <- utils::adist(tolower(field), tolower(STANDARD_DESCRIPTION_FIELDS))[1L, ]
      best <- which.min(d)
      if (d[best] <= 2L && d[best] < nchar(field) / 3) {
        what <- paste0(what, "; did you mean ", STANDARD_DESCRIPTION_FIELDS[best], "?")
      }
      what
    },
    "",
    USE.NAMES = FALSE
  )
  report_check(
    issues,
    verbose,
    check_label("description_fields"),
    "Every DESCRIPTION field is one R knows",
    "DESCRIPTION fields R does not know",
    treatment = paste("Treatment:", treatments$description_fields$treatment)
  )
}

# The template text usethis and package.skeleton() leave in a DESCRIPTION, as
# R's incoming check tests for it: a field and a test on its value. Title and
# Description are compared in lower case, Author and Maintainer as written.
DESCRIPTION_PLACEHOLDERS <- list(
  Title = function(x) startsWith(tolower(x), "what the package does"),
  Description = function(x) {
    startsWith(tolower(x), "what the package does") ||
      startsWith(tolower(x), "more about what it does")
  },
  Author = function(x) x == "Who wrote it",
  Maintainer = function(x) {
    startsWith(x, "Who to complain to") || startsWith(x, "The package maintainer")
  }
)

#' Diagnose Template Text Left in DESCRIPTION
#'
#' Flags a `Title`, `Description`, `Author` or `Maintainer` that still holds the
#' text a package template wrote: the `usethis` template's "What the Package
#' Does (One Line, Title Case)" and "What the package does (one paragraph).",
#' and `package.skeleton()`'s "What the Package Does (Short Line)", "More about
#' what it does (maybe more than one line).", "Who wrote it" and "Who to
#' complain to". It applies R's own tests, so it flags what CRAN flags. A
#' template `Authors@R` is [lab_authors()]'s to report.
#'
#' @section Source:
#' The
#' [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' run by `R CMD check --as-cran` NOTEs "DESCRIPTION fields with placeholder
#' content". [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file)
#' asks for a `Title` and `Description` that describe the package. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/description_placeholders_bad.txt",
#'                                  show_content = FALSE)
#' lab_description_placeholders(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_description_placeholders <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  issues <- character(0)
  for (field in names(DESCRIPTION_PLACEHOLDERS)) {
    value <- desc_value(desc, field)
    if (is.null(value)) {
      next
    }
    value <- trimws(gsub("[\n\t]", " ", value))
    if (isTRUE(DESCRIPTION_PLACEHOLDERS[[field]](value))) {
      issues <- c(issues, paste0(field, " is template text: ", value))
    }
  }
  report_check(
    issues,
    verbose,
    check_label("description_placeholders"),
    "No template text left in DESCRIPTION",
    "DESCRIPTION still holds template text",
    treatment = paste(
      "Treatment:",
      treatments$description_placeholders$treatment
    )
  )
}

#' Diagnose the DESCRIPTION Date Field
#'
#' Flags a `Date` field that is not ISO 8601 `yyyy-mm-dd`, is over a month old, or lies in the future. Mirrors the CRAN incoming check; an absent `Date` field (the common, preferred case) passes.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says "the 'yyyy-mm-dd' format of the
#' ISO 8601 standard is strongly recommended"; the
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' also flags a stale or future date. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/date_format_bad.txt",
#'                                  show_content = FALSE)
#' lab_date_format(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_date_format <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  date <- desc_value(desc, "Date")
  issues <- character(0)
  if (!is.null(date)) {
    date <- trimws(date)
    dd <- as.Date(date, "%Y-%m-%d")
    if (is.na(dd)) {
      issues <- paste0("Date is not in ISO 8601 yyyy-mm-dd format: ", date)
    } else if (dd < Sys.Date() - 31) {
      issues <- paste0("Date is over a month old: ", date)
    } else if (dd > Sys.Date() + 7) {
      issues <- paste0("Date is in the future: ", date)
    }
  }
  report_check(
    issues,
    verbose,
    check_label("date_format"),
    "{.field Date} field is absent or current",
    "DESCRIPTION Date field problem",
    treatment = paste("Treatment:", treatments$date_format$treatment),
    level = "warning"
  )
}

#' Diagnose a DESCRIPTION Encoding Other Than UTF-8
#'
#' Flags an `Encoding` that is anything but exactly `UTF-8`, which is the test
#' CRAN's incoming check applies. `latin1` and `latin2` are still legal R, but
#' CRAN NOTEs them as deprecated, and the comparison is case-sensitive, so a
#' lower-case `utf-8` is NOTEd too. An absent `Encoding` passes.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says a non-ASCII DESCRIPTION "should contain an
#' 'Encoding' field"; the
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' run by `R CMD check --as-cran` NOTEs any value but `UTF-8` with "Package
#' encoding '...' is deprecated. Please change to UTF-8 for non-ASCII content."
#' See `vignette("check-sources", package = "checktor")` for how every check
#' maps to its source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/encoding_utf8_bad.txt",
#'                                  show_content = FALSE)
#' lab_encoding_utf8(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_encoding_utf8 <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  enc <- dcf_field(desc, "Encoding")
  issues <- character(0)
  # R's own test, from tools:::.check_package_CRAN_incoming:
  #     if (!is.na(enc <- meta["Encoding"]) && (enc != "UTF-8"))
  # An exact, case-sensitive comparison. latin1 and latin2 are portable in the
  # sense Writing R Extensions uses, but CRAN now calls them deprecated.
  # A blank Encoding is not UTF-8 either, and R flags it, so this reads the
  # field as written rather than through desc_value(), which takes blank as
  # absent.
  if (!is.null(enc) && !is.na(enc) && !identical(trimws(enc), "UTF-8")) {
    enc <- trimws(enc)
    issues <- paste0(
      "Encoding is \"", enc, "\"; CRAN's incoming check says package ",
      "encoding '", enc, "' is deprecated and asks for UTF-8"
    )
  }
  report_check(
    issues,
    verbose,
    check_label("encoding_utf8"),
    "{.field Encoding} is UTF-8 or unset",
    "Encoding other than UTF-8 declared",
    treatment = paste("Treatment:", treatments$encoding_utf8$treatment),
    level = "warning"
  )
}

#' Diagnose the DESCRIPTION Version Field
#'
#' Flags a `Version` with a leading-zero component or a suspiciously large one, mirroring CRAN's `version_with_leading_zeroes` and `version_with_large_components` incoming checks. A calendar-year component (e.g. a dated `2026.01` version) is exempt.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says a `Version` is "a sequence of at
#' least two ... non-negative integers"; the
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' flags a leading zero or an implausible value. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/version_format_bad.txt",
#'                                  show_content = FALSE)
#' lab_version_format(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_version_format <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  ver <- desc_value(desc, "Version")
  issues <- character(0)
  if (!is.null(ver)) {
    ver <- trimws(ver)
    if (grepl("(^|[.-])0[0-9]+", ver) && !grepl("^[0-9]{4}[.-][0-9]{2}", ver)) {
      issues <- c(
        issues,
        paste0("Version has a component with a leading zero: ", ver)
      )
    }
    comps <- tryCatch(unlist(package_version(ver)), error = function(e) NULL)
    if (is.null(comps)) {
      issues <- c(
        issues,
        paste0("Version is not a valid package version: ", ver)
      )
    } else {
      # A component is only "suspiciously large" if it is neither a plausible
      # calendar year (a dated version such as 2025.4) nor the .9000-series dev
      # suffix that usethis::use_dev_version() appends. checktor runs on packages
      # under development, so flagging a bare 0.1.0.9000 would be noise.
      this_year <- as.integer(format(Sys.Date(), "%Y"))
      is_year <- comps >= 1900 & comps <= this_year + 1L
      is_dev <- seq_along(comps) == length(comps) & comps >= 9000
      if (any(comps >= 1234 & !is_year & !is_dev)) {
        issues <- c(
          issues,
          paste0("Version has a suspiciously large component: ", ver)
        )
      }
    }
  }
  report_check(
    issues,
    verbose,
    check_label("version_format"),
    "{.field Version} is well formed",
    "DESCRIPTION Version field problem",
    treatment = paste("Treatment:", treatments$version_format$treatment)
  )
}

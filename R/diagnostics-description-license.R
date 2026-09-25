# License field and LICENSE file checks.

# License validity, delegated to tools::analyze_license() plus the "+ file LICENSE"
# rule. R CMD check does report these, but only once you run the full check; this
# is the same information in the pre-flight, and analyze_license() is R's own
# parser rather than a regex over the field.
#' Diagnose the License Field
#'
#' Flags a `License` that [tools::analyze_license()] cannot standardize, and a `+ file LICENSE` pointing at a file that does not exist. For MIT and the BSD licenses it also reads that file as `R CMD check` does: it must be the stub of `YEAR` and `COPYRIGHT HOLDER` fields (and `ORGANIZATION` for BSD 3-clause), so the full license text in its place is reported, as R's "License stub is invalid DCF" NOTE.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' treats an invalid or unrecognised `License` field as a rejection. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/license_bad.txt",
#'                                  show_content = FALSE)
#' lab_license(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_license <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  lic <- desc_value(desc, "License")
  issues <- character(0)

  if (is.null(lic)) {
    issues <- "No License field in DESCRIPTION"
  } else {
    a <- tryCatch(tools::analyze_license(lic), error = function(e) NULL)
    if (!is.null(a) && !isTRUE(a$is_standardizable)) {
      issues <- c(
        issues,
        paste0(
          "License '",
          lic,
          "' is not a standardizable CRAN license"
        )
      )
    }
    # A template licence (MIT, BSD) carries no copyright holder of its own, so it
    # must point at a LICENSE file naming one.
    needs_file <- grepl("\\b(MIT|BSD_2_clause|BSD_3_clause)\\b", lic)
    points_at_file <- grepl("\\+\\s*file\\s+LICEN[CS]E", lic)
    if (needs_file && !points_at_file) {
      issues <- c(
        issues,
        paste0(
          "License '",
          lic,
          "' is a template and needs '+ file LICENSE'"
        )
      )
    }
    if (
      points_at_file &&
        !any(file.exists(file.path(path, c("LICENSE", "LICENCE"))))
    ) {
      issues <- c(
        issues,
        "License points at a LICENSE file that does not exist"
      )
    }
    issues <- c(issues, license_stub_issues(a, path))
  }

  report_check(
    issues,
    verbose,
    check_label("license"),
    "License field looks valid",
    "License field problems",
    treatment = paste("Treatment:", treatments$license$treatment)
  )
}

# MIT and BSD point at a stub, a DCF file of the fields the template leaves
# open, and plain R CMD check reads it as tools:::.check_package_license() does.
# The full license text in its place, as GitHub and most editors write it, is not
# DCF, so R NOTEs "License stub is invalid DCF" and CRAN sends it back.
license_stub_issues <- function(a, path) {
  components <- a$extensions$components
  pointers <- a$pointers
  if (length(components) == 0L || length(pointers) == 0L) {
    return(character(0))
  }
  fields <- if (any(grepl("^BSD[ _]3", components))) {
    c("YEAR", "COPYRIGHT HOLDER", "ORGANIZATION")
  } else if (any(grepl("^(MIT|BSD[ _]2)", components))) {
    c("YEAR", "COPYRIGHT HOLDER")
  }
  file <- file.path(path, pointers[[1L]])
  if (is.null(fields) || !utils::file_test("-f", file)) {
    return(character(0))
  }
  stub <- tryCatch(read.dcf(file, fields = fields), error = function(e) NULL)
  if (is.null(stub)) {
    return(paste0(
      pointers[[1L]], " is not the stub '", paste(components, collapse = "', '"),
      "' points at (R CMD check: \"License stub is invalid DCF.\"). Write only ",
      paste0(fields, ": ...", collapse = " and "), ", and keep any full ",
      "license text in a file .Rbuildignore excludes, such as LICENSE.md"
    ))
  }
  empty <- is.na(stub) | !nzchar(stub)
  if (!any(empty)) {
    return(character(0))
  }
  paste0(
    pointers[[1L]], " has a stub record with missing or empty fields: ",
    paste(fields[colSums(empty) > 0L], collapse = ", ")
  )
}

# The licenses whose R template leaves the year and copyright holder to a
# LICENSE file, as named in tools:::.license_component_is_for_stub_and_ok()'s
# `fields_for_stubs` (R 4.6.1). For these '+ file LICENSE' is required, not
# redundant.
LICENSE_STUB_BASES <- c(
  "MIT License", "MIT",
  "BSD 2-clause License", "BSD_2_clause",
  "BSD 3-clause License", "BSD_3_clause"
)

#' Diagnose an Unneeded LICENSE File Pointer
#'
#' Flags `+ file LICENSE` added to a standard license R knows, such as
#' `GPL-3 + file LICENSE`, `LGPL-3 + file LICENSE` or
#' `Apache License 2.0 + file LICENSE`. MIT and the BSD licenses are templates
#' that need a `LICENSE` file naming the year and copyright holder, so they are
#' left alone, as is a bare `file LICENSE`. Each alternative of a dual license
#' such as `GPL-3 + file LICENSE | MIT + file LICENSE` is judged on its own.
#'
#' A `LICENSE` that adds attribution requirements or other restrictions is
#' the exception CRAN allows. Explain it in `cran-comments.md` and allow the
#' finding with `Config/checktor/allow: license_file_unneeded`.
#'
#' @section Source:
#' The CRAN Cookbook's
#' [LICENSE files](https://contributor.r-project.org/cran-cookbook/description_issues.html#license-files)
#' recipe gives the reviewers' text: "We do not need \"+ file LICENSE\" and the
#' file as these are part of R. This is only needed in case of attribution
#' requirements or other possible restrictions. Hence please omit it." R agrees
#' in two places. `R CMD check` NOTEs "License components with restrictions not
#' permitted" for a license that takes no extension, such as `GPL (>= 2)` or
#' Apache, and the
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' NOTEs "License components with restrictions and base license permitting
#' such" for one that does, such as `GPL-3`. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return
#' @seealso [lab_license()] for a license R cannot read; [checktor()], which
#'   runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/license_file_unneeded_bad.txt",
#'                                  show_content = FALSE)
#' lab_license_file_unneeded(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_license_file_unneeded <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  lic <- desc_value(desc, "License")
  issues <- character(0)
  if (!is.null(lic)) {
    components <- trimws(strsplit(gsub("[\n\t]", " ", lic), "|", fixed = TRUE)[[1L]])
    pointer <- "[[:space:]]*\\+[[:space:]]*file[[:space:]]+LICEN[CS]E[[:space:]]*$"
    for (component in components[grepl(pointer, components)]) {
      base <- trimws(sub(pointer, "", component))
      if (!nzchar(base)) {
        next
      }
      # A base R cannot read is lab_license()'s to report.
      a <- tryCatch(tools::analyze_license(base), error = function(e) NULL)
      if (is.null(a) || !isTRUE(a$is_standardizable)) {
        next
      }
      if (base %in% LICENSE_STUB_BASES || a$standardization %in% LICENSE_STUB_BASES) {
        next
      }
      issues <- c(
        issues,
        paste0(
          component, ": ", base, " is a standard license R knows, so CRAN ",
          "needs neither '+ file LICENSE' nor the file"
        )
      )
    }
  }
  report_check(
    issues,
    verbose,
    check_label("license_file_unneeded"),
    "No '+ file LICENSE' on a standard license",
    "'+ file LICENSE' on a standard license",
    treatment = paste("Treatment:", treatments$license_file_unneeded$treatment)
  )
}

# The LICENSE file's own contents.
#
# The previous rule flagged any LICENSE whose latest year was not the current year.
# No authority supports that: a LICENSE reading `YEAR: 1999` passes
# R CMD check --as-cran in silence, and tools:::.check_package_license only checks
# that the fields EXIST. It fired on every package not touched this calendar year.
#
# What is real, and what nothing else checks, is an unfilled template. usethis
# writes `YEAR` and `COPYRIGHT HOLDER` for you, but a hand-written LICENSE often
# still carries `<YEAR>` / `<COPYRIGHT HOLDER>` placeholders, and CRAN policy does
# require copyright ownership to be clear and unambiguous.
#' Diagnose an Unfilled LICENSE Template
#'
#' Flags a `LICENSE` file still carrying template placeholders such as `<YEAR>` or `<COPYRIGHT HOLDER>`.
#'
#' @section Source:
#' The CRAN Cookbook covers the file itself under
#' [LICENSE files](https://contributor.r-project.org/cran-cookbook/description_issues.html#license-files).
#' An unfilled template, with `<YEAR>` or `<COPYRIGHT HOLDER>` left in, leaves a
#' placeholder, and no binding rule names it, which is why this sits at
#' `robustness` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/license_year_bad.LICENSE",
#'                                  show_content = FALSE)
#' lab_license_year(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_license_year <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  license_file <- Filter(file.exists, file.path(path, c("LICENSE", "LICENCE")))
  if (length(license_file) == 0L) {
    return(pass_result(check_label("license_year")))
  }
  content <- safe_read_lines(license_file[[1L]])
  if (length(content) == 0L) {
    # An empty file prints no summary, so the result is built here.
    return(checktor_check_result(
      FALSE,
      "LICENSE file is empty",
      check_label("license_year")
    ))
  }
  flat <- paste(content, collapse = "\n")

  issues <- character(0)
  placeholders <- c(
    "<YEAR>",
    "<COPYRIGHT HOLDER>",
    "<copyright holders>",
    "YOUR NAME",
    "Your Name",
    "[year]",
    "[fullname]"
  )
  for (ph in placeholders) {
    if (grepl(ph, flat, fixed = TRUE)) {
      issues <- c(
        issues,
        paste0(
          "LICENSE has an unfilled template placeholder: ",
          ph
        )
      )
    }
  }
  # A stub with no holder at all is lab_license()'s to report, as R does.

  report_check(
    issues,
    verbose,
    check_label("license_year"),
    "LICENSE file is filled in",
    "LICENSE file has unfilled placeholders",
    treatment = paste("Treatment:", treatments$license_year$treatment)
  )
}

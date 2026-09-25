# License field and LICENSE file checks.

# License validity, delegated to tools::analyze_license() plus the "+ file LICENSE"
# rule. R CMD check does report these, but only once you run the full check; this
# is the same information in the pre-flight, and analyze_license() is R's own
# parser rather than a regex over the field.
#' Diagnose the License Field
#'
#' Flags a `License` that [tools::analyze_license()] cannot standardize, and a `+ file LICENSE` pointing at a file that does not exist.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' treats an invalid or unrecognised `License` field as a rejection. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
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
  lic <- desc[["License"]]
  issues <- character(0)

  if (is.null(lic) || !nzchar(lic)) {
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
  }

  emit_issue_summary(
    issues,
    verbose,
    "License field looks valid",
    "License field problems",
    "Treatment: Use a standardizable license, and add '+ file LICENSE' for MIT/BSD"
  )
  checktor_check_result(length(issues) == 0L, issues, "License check")
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
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
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
  lic <- dcf_field(desc, "License")
  issues <- character(0)
  if (!is.null(lic) && !is.na(lic) && nzchar(trimws(lic))) {
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
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No '+ file LICENSE' on a standard license",
    "'+ file LICENSE' on a standard license",
    paste0(
      "Treatment: CRAN asks: \"We do not need '+ file LICENSE' and the file as ",
      "these are part of R. Hence please omit it.\" Drop both, unless LICENSE ",
      "adds attribution requirements or other restrictions"
    )
  )
  checktor_check_result(passed, issues, "License file pointer check")
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
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/license_year_bad.LICENSE",
#'                                  show_content = FALSE)
#' lab_license_year(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_license_year <- function(path, verbose) {
  path <- find_package_root(path)
  license_file <- Filter(file.exists, file.path(path, c("LICENSE", "LICENCE")))
  if (length(license_file) == 0L) {
    return(checktor_check_result(TRUE, character(0), "License file check"))
  }
  content <- safe_read_lines(license_file[[1L]])
  if (length(content) == 0L) {
    return(checktor_check_result(
      FALSE,
      "LICENSE file is empty",
      "License file check"
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
  # A DCF-style LICENSE (what usethis writes for MIT/BSD) must name a holder.
  if (grepl("^YEAR:", flat) && !grepl("COPYRIGHT HOLDER:\\s*\\S", flat)) {
    issues <- c(issues, "LICENSE has no COPYRIGHT HOLDER")
  }

  emit_issue_summary(
    issues,
    verbose,
    "LICENSE file is filled in",
    "LICENSE file has unfilled placeholders",
    "Treatment: Replace the template placeholders with the real year and holder"
  )
  checktor_check_result(length(issues) == 0L, issues, "License file check")
}

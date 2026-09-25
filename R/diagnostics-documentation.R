#' Diagnose Documentation Issues
#'
#' Runs diagnostics on package documentation to identify common issues that
#' can cause CRAN submission problems or a poor user experience.
#'
#' @details
#' This function checks for:
#' - Missing `\value` tags in function documentation
#' - Exported functions missing an `\examples` section
#' - Roxygen2 usage
#' - Example structure (appropriate use of `\dontrun{}`)
#' - Examples that use Suggested packages without a guard
#'
#' `.Rd` files are parsed structurally via [tools::parse_Rd()] so analyses
#' look at sections by their `Rd_tag` rather than grepping LaTeX text.
#'
#' @param path Character. Path to package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return
#' List of [checktor_check_result()] objects plus a `passed` named logical
#' vector summarizing pass/fail per check.
#'
#' @seealso [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("documentation_examples/missing_value_tag.Rd",
#'                                       show_content = FALSE)
#' doc_results <- diagnose_documentation_issues(pkg_path, verbose = FALSE)
#' summary(doc_results)
#' issues(doc_results)
diagnose_documentation_issues <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  begin_category("documentation", path, verbose)
  run_category("documentation", path, verbose)
}

# Heuristics for "Rd files we should NOT require to have \value{}".
# Data, class, methods, and package-level topics, plus re-export pages.
is_non_function_rd_obj <- function(rd) {
  doctype <- extract_rd_section(rd, "\\docType")
  if (!is.null(doctype)) {
    dt <- trimws(collect_rd_text(doctype))
    if (dt %in% c("data", "class", "package", "methods")) return(TRUE)
  }
  # Package-level: any \alias ending in -package.
  if (any(grepl("-package$", rd_aliases(rd)))) {
    return(TRUE)
  }
  # Re-export pages
  "reexports" %in% rd_section_texts(rd, "\\name")
}

# Keywords that exempt a topic from needing \value{}: internal pages, and the
# graphics topics R's own checks exempt.
VALUE_EXEMPT_KEYWORDS <- c("internal", "aplot", "hplot", "device", "dynamic")

# Whether the help page `rd_file` needs a \value{} and lacks one, for
# lab_value_tags(). A page that does not parse needs nothing.
rd_needs_value <- function(rd_file) {
  rd <- read_rd_quietly(rd_file)
  if (is.null(rd)) {
    return(FALSE)
  }
  tags <- rd_tags(rd)
  doctype <- tolower(trimws(
    collect_rd_text(extract_rd_section(rd, "\\docType"))
  ))
  if (doctype %in% c("data", "class", "package")) {
    return(FALSE)
  }
  keywords <- tolower(rd_section_texts(rd, "\\keyword"))
  if (any(keywords %in% VALUE_EXEMPT_KEYWORDS)) {
    return(FALSE)
  }
  documents_function <- any(tags %in% c("\\usage", "\\arguments"))
  documents_function && !("\\value" %in% tags)
}

#' Diagnose Missing Value Tags in Documentation
#'
#' Walks `.Rd` files via [tools::parse_Rd()] and reports topics that are
#' missing a `\value{}` section. Data, class, methods, package-level, and
#' re-export topics are skipped (they don't need `\value{}`).
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Documenting-functions),
#' under "Documenting functions", describes `\value{}`, and the CRAN Cookbook keeps
#' the recipe reviewers cite under
#' [Missing value-tags in .Rd-files](https://contributor.r-project.org/cran-cookbook/docs_issues.html#missing-value-tags-in-.rd-files),
#' but `R CMD check` does not require it, so checktor keeps this at `opinion` tier.
#' See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `missing`,
#'   `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/missing_value_tag.Rd",
#'                                  show_content = FALSE)
#' lab_value_tags(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_value_tags <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  if (length(rd_files) == 0L) {
    if (verbose) {
      cli::cli_alert_info("No .Rd files found")
    }
    return(pass_result(check_label("value_tags")))
  }

  # Walk each .Rd with tools::parse_Rd() rather than tools::checkRdContents(),
  # whose `missing_value` output postdates checktor's R floor: a diagnostic must
  # not change its verdict with the R version running it. A topic needs a \value
  # only if it documents a function, meaning it has a \usage or \arguments
  # section and is not a data, class or package topic, nor a \keyword{internal}
  # or graphics topic. R CMD check does NOT surface missing \value as a NOTE, so
  # this stays an extra-CRAN check.
  hit <- vapply(rd_files, rd_needs_value, logical(1))
  missing_value <- sort(basename(rd_files[hit]))

  report_check(
    missing_value,
    verbose,
    check_label("value_tags"),
    "All function documentation has {.code \\value} tags",
    "Missing {.code \\value} tags",
    missing = missing_value
  )
}

#' Diagnose Stale Generated Documentation
#'
#' Flags a package whose `NAMESPACE` and `man/` no longer match the roxygen
#' comments they were generated from, i.e. you edited roxygen and forgot to run
#' `devtools::document()`.
#'
#' Two signals, both deliberately clock-free:
#'
#' - A name tagged `@export` in a roxygen block that does not appear in
#'   `NAMESPACE`. This is the real cost of a forgotten `document()` call: the
#'   function is not exported, so users cannot call it, and `R CMD check` says
#'   nothing because a package is free to export whatever it likes.
#' - An `.Rd` file whose roxygen2 backlink names a source file that no longer
#'   exists, which is the orphan left behind when a source file is renamed or
#'   deleted without re-documenting.
#'
#' File modification times are deliberately not used. `git` does not preserve
#' them, so on a fresh clone every file carries roughly the checkout time in
#' arbitrary order, and an mtime comparison would pass or fail at random in CI.
#'
#' The check is skipped entirely unless `NAMESPACE` carries the roxygen2
#' "do not edit by hand" banner, so a hand-managed package is never flagged.
#'
#' @section Source:
#' The CRAN Cookbook covers the roxygen2 side of this under
#' [Repeated Rejections of Issues in Manuals](https://contributor.r-project.org/cran-cookbook/docs_issues.html#repeated-rejections-of-issues-in-manuals-if-using-roxygen2),
#' where documentation is regenerated rather than hand-edited. A function tagged
#' `@export` that never reached `NAMESPACE` is not actually exported, and no binding
#' rule names it, which is why this sits at `robustness` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/roxygen_usage_bad.R",
#'                                  show_content = FALSE)
#' # NAMESPACE as roxygen2 wrote it before rescale01() was tagged @export
#' writeLines("# Generated by roxygen2: do not edit by hand",
#'            file.path(pkg, "NAMESPACE"))
#' lab_roxygen_usage(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_roxygen_usage <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  r_files <- list_r_files(path)
  if (length(r_files) == 0L) {
    return(pass_result(check_label("roxygen_usage")))
  }

  # Only meaningful for a roxygen-managed package. A hand-written NAMESPACE is
  # nobody's business but its author's.
  ns_lines <- safe_read_lines(file.path(path, "NAMESPACE"))
  if (!any(grepl("Generated by roxygen2", ns_lines, fixed = TRUE))) {
    return(pass_result(check_label("roxygen_usage")))
  }

  issues <- character(0)

  # Signal 1: tagged @export in roxygen, absent from NAMESPACE.
  declared <- roxygen_exported_names(read_r_xml(path))
  if (length(declared) > 0L) {
    ex <- package_exports(path)
    if (is.null(ex)) {
      return(pass_result(check_label("roxygen_usage")))
    } # cannot read NAMESPACE: cannot judge drift
    hit <- vapply(names(declared), name_is_exported, logical(1), ex = ex)
    missing <- declared[!hit]
    if (length(missing) > 0L) {
      issues <- c(
        issues,
        paste0(
          names(missing),
          " is tagged @export in ",
          unname(missing),
          " but is absent from NAMESPACE"
        )
      )
    }
  }

  # Signal 2: an Rd pointing back at a source file that is gone.
  #
  # This is the one .Rd scan that reads man/ whole rather than through
  # list_rd_files(). Every other check asks what CRAN will see; this one asks
  # whether your working tree is in sync with roxygen, and a topic held back
  # from the tarball is still a topic document() maintains. Leaving out the
  # .Rbuildignore'd files here would just stop reporting stale ones.
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
  for (rd in rd_files) {
    head_lines <- utils::head(safe_read_lines(rd), 3L)
    backlink <- grep(
      "^%\\s*Please edit documentation in ",
      head_lines,
      value = TRUE
    )
    if (length(backlink) == 0L) {
      next
    } # hand-written Rd
    srcs <- sub("^%\\s*Please edit documentation in ", "", backlink[[1L]])
    srcs <- trimws(strsplit(srcs, ",", fixed = TRUE)[[1L]])
    gone <- srcs[!file.exists(file.path(path, srcs))]
    if (length(gone) > 0L) {
      issues <- c(
        issues,
        paste0(
          basename(rd),
          " documents ",
          paste(gone, collapse = ", "),
          ", which no longer exists"
        )
      )
    }
  }

  report_check(
    issues,
    verbose,
    check_label("roxygen_usage"),
    "Generated documentation is up to date",
    "Generated documentation is out of sync with roxygen",
    treatment = paste("Treatment:", treatments$roxygen_usage$treatment),
    level = "warning"
  )
}

#' Diagnose General Package Issues
#'
#' Runs general diagnostics on package structure and content that don't fit
#' into specific code, documentation, or DESCRIPTION categories.
#'
#' @details
#' This function checks:
#'
#' - Package size, measured against the files that would go into the
#'   tarball (`.Rbuildignore` and standard scratch dirs are excluded), with
#'   a 5 MB warning threshold matching CRAN's recommendation.
#' - `http://` URLs and URL shorteners, offline. `R CMD check --as-cran` does
#'   fetch every URL, but only with a network and only under `--as-cran`; this
#'   is the fast local pass.
#' - Presence of a `NEWS` file documenting user-facing changes.
#' - Relative links in the `README` that would break on CRAN.
#' - A package that exports code but has no examples, no tests and no
#'   vignettes to exercise it.
#' - An `inst/CITATION` that uses the old-style `citEntry()` or `personList()`,
#'   or calls `packageDescription()`, `library()` or `require()`.
#'
#' [lab_cran_comments_file()] is intentionally not part of this default
#' run, since a `cran-comments.md` is a workflow convention rather than a CRAN
#' requirement; call it directly to opt in.
#'
#' @param path Character. Path to package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return List of [checktor_check_result()] objects plus a `passed` summary.
#'
#' @seealso [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' general_results <- diagnose_general_issues(pkg_path, verbose = FALSE)
#' general_results$package_size$size_mb
diagnose_general_issues <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  begin_category("general", path, verbose)
  run_category("general", path, verbose)
}

#' Diagnose Package Size
#'
#' Estimates the size of the source package that would be sent to CRAN
#' (files matched by `.Rbuildignore`, plus standard scratch directories like
#' `.git`, `.Rproj.user`, are excluded). Warns at the 5 MB threshold.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' limits the size of the built tarball. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`,
#'   and `size_mb`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' # About 7 MB of data that gzip cannot shrink much
#' dir.create(file.path(pkg, "inst", "extdata"), recursive = TRUE)
#' writeBin(sin(seq_len(1e6) * 1.1), file.path(pkg, "inst", "extdata", "series.bin"))
#' lab_package_size(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_package_size <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  all_files <- list.files(
    path,
    recursive = TRUE,
    full.names = FALSE,
    all.files = TRUE,
    no.. = TRUE
  )
  ignore <- build_ignore_matcher(path)
  keep <- !ignore(all_files)
  all_files <- all_files[keep]

  full <- file.path(path, all_files)

  # CRAN's 5 MB limit is on the GZIPPED TARBALL, not the source tree. Summing raw
  # bytes over-reports any package whose bulk is compressible text -- built vignette
  # HTML, minified JS, SVG, CSV -- by two or three times. Measured against the real
  # tarballs CRAN ships: billboarder is 6.3 MB on disk and 2.93 MB as a tarball,
  # readepi 5.9 MB and 1.57 MB. Every package_size finding in the audit was a false
  # positive produced by this one mistake.
  #
  # Compressing each file independently still misses the cross-file redundancy that
  # a real tar.gz exploits, so this remains a slight OVER-estimate. That is the safe
  # direction for a limit check, and it is far closer than the raw sum.
  compressed_size <- function(f) {
    n <- file.size(f)
    if (is.na(n) || n == 0) {
      return(0)
    }
    # A file R cannot open counts at its size on disk, without a warning.
    raw_bytes <- tryCatch(
      suppressWarnings(readBin(f, what = "raw", n = n)),
      error = function(e) NULL
    )
    if (is.null(raw_bytes)) {
      return(n)
    }
    length(memCompress(raw_bytes, type = "gzip"))
  }
  size_mb <- sum(vapply(full, compressed_size, numeric(1))) / (1024^2)

  passed <- size_mb <= 5
  issues <- if (passed) {
    character(0)
  } else {
    paste0(
      "Package size ",
      round(size_mb, 2),
      " MB (compressed) exceeds 5 MB"
    )
  }

  if (verbose) {
    if (passed) {
      cli::cli_alert_success(
        "Package size: {.val {round(size_mb, 2)} MB} (under 5 MB limit)"
      )
    } else {
      cli::cli_alert_warning(
        "Package size: {.val {round(size_mb, 2)} MB} (over 5 MB recommended limit)"
      )
      cli::cli_text(
        paste0("{.emph Treatment: ", treatments$package_size$treatment, "}")
      )
    }
  }
  checktor_check_result(
    passed,
    issues,
    check_label("package_size"),
    size_mb = size_mb
  )
}

#' Diagnose a Missing NEWS File
#'
#' CRAN expects packages (especially on resubmission) to document user-facing
#' changes in a `NEWS` file. Accepts `NEWS.md`, `NEWS`, or `NEWS.Rd` at the
#' package root or under `inst/`.
#'
#' @section Source:
#' No formal rule. A `NEWS` file is expected but not required, a convention
#' which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' invisible(file.remove(file.path(pkg, "NEWS.md")))
#' lab_news_file(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_news_file <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  candidates <- file.path(
    path,
    c(
      "NEWS.md",
      "NEWS",
      "NEWS.Rd",
      file.path("inst", c("NEWS.md", "NEWS", "NEWS.Rd"))
    )
  )
  has_news <- any(file.exists(candidates))
  issues <- if (has_news) {
    character(0)
  } else {
    "No NEWS file found (add NEWS.md to document user-facing changes)"
  }
  report_check(
    issues,
    verbose,
    check_label("news_file"),
    "NEWS file found",
    "No NEWS file found",
    treatment = paste("Treatment:", treatments$news_file$treatment),
    level = "warning"
  )
}

#' Diagnose a Package Nothing Exercises
#'
#' Flags a package that exports something but ships no `\examples` in any help
#' page, no tests and no vignettes, so a check runs none of its code. CRAN's
#' incoming check raises this as a WARNING, which is an automatic rejection.
#'
#' The conditions are R's own. An example counts even when all of it sits in
#' `\dontrun{}`, because R still writes it out. A test counts only as a file
#' directly in `tests/` ending in `.R`, `.r` or `.Rin`, since that is what
#' `R CMD check` runs: a `tests/testthat/` folder without the `tests/testthat.R`
#' driver is never run, and the finding says so. Files `.Rbuildignore` excludes do
#' not count, since they are not in the tarball. A package with no `R/`
#' directory, or whose `NAMESPACE` exports nothing, passes. So does one whose
#' `NAMESPACE` is missing or cannot be parsed, since its exports are then unknown.
#'
#' @section Source:
#' The [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' (`R CMD check --as-cran`) reports "checking for code which exercises the
#' package ... WARNING" with "No examples, no tests, no vignettes" when all three
#' are missing and the `NAMESPACE` exports anything. `devtools::check()` turns the
#' incoming check off by default, so the WARNING is usually first seen at
#' win-builder or on submission. The
#' [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' asks that "the checks that are left do exercise all the features of the
#' package". See `vignette("check-sources", package = "checktor")` for how every
#' check maps to its source.
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("general_examples/code_exercised_bad.R",
#'                                  show_content = FALSE)
#' # The scenario's function is exported, as roxygen2 would record it
#' writeLines("export(tidy_values)", file.path(pkg, "NAMESPACE"))
#' lab_code_exercised(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_code_exercised <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  # R asks only of a package with code in R/ that exports something. With no
  # readable NAMESPACE the exports are unknown, so there is nothing to judge.
  if (!dir.exists(file.path(path, "R"))) {
    return(pass_result(check_label("code_exercised")))
  }
  ex <- package_exports(path)
  if (is.null(ex) || (length(ex$names) == 0L && length(ex$patterns) == 0L)) {
    return(pass_result(check_label("code_exercised")))
  }

  if (package_has_examples(path)) {
    return(pass_result(check_label("code_exercised")))
  }
  # R CMD check runs the scripts directly in tests/, nothing deeper.
  if (length(list_included_files(path, "tests", "\\.(r|R|Rin)$")) > 0L) {
    return(pass_result(check_label("code_exercised")))
  }
  if (package_has_vignettes(path)) {
    return(pass_result(check_label("code_exercised")))
  }

  issue <- paste(
    "The package exports code but has no examples, no tests and no vignettes,",
    "so R CMD check --as-cran WARNs 'No examples, no tests, no vignettes'"
  )
  nested <- list_included_files(path, "tests", "\\.[rR]$", recursive = TRUE)
  if (length(nested) > 0L) {
    issue <- paste0(
      issue,
      ". The files under tests/ are never run without a driver such as ",
      "tests/testthat.R (usethis::use_testthat())"
    )
  }

  report_check(
    issue,
    verbose,
    check_label("code_exercised"),
    "The package has examples, tests or vignettes",
    "Nothing exercises the package's code",
    treatment = paste("Treatment:", treatments$code_exercised$treatment),
    level = "warning"
  )
}

# Does any help page the tarball includes carry an \examples section? R writes
# one out whatever it holds, \dontrun{} included, so its presence is what counts.
# A page that does not parse counts as having one: the check must not accuse a
# package on the strength of a file it could not read.
package_has_examples <- function(path) {
  for (file in list_rd_files(path)) {
    rd <- suppressWarnings(read_rd_quietly(file))
    if (is.null(rd) || !is.null(extract_rd_section(rd, "\\examples"))) {
      return(TRUE)
    }
  }
  FALSE
}

# Vignette sources in the tarball, for any of the engines CRAN packages use:
# Sweave, knitr, Quarto and R.rsp. R looks in vignettes/, or in inst/doc for an
# old package without one.
VIGNETTE_SOURCE_PATTERN <-
  "\\.([RrSs](nw|tex|md|markdown|rst|html|asciidoc)|qmd|rsp|asis)$"

package_has_vignettes <- function(path) {
  subdir <- if (dir.exists(file.path(path, "vignettes"))) {
    "vignettes"
  } else {
    file.path("inst", "doc")
  }
  length(list_included_files(path, subdir, VIGNETTE_SOURCE_PATTERN)) > 0L
}

#' Diagnose a Missing cran-comments.md File
#'
#' A `cran-comments.md` file carries the submission notes CRAN reviewers read
#' (test environments, R CMD check results, downstream-dependency notes). Its
#' absence is flagged so it can be added before submission.
#'
#' This check is opt-in: it is **not** part of the default [checktor()] /
#' [diagnose_general_issues()] run, because a `cran-comments.md` is a workflow
#' convention rather than a CRAN requirement. Call it directly to use it.
#'
#' @section Source:
#' No formal rule. A `cran-comments.md` is a submission-workflow convention
#' rather than a CRAN requirement, which is why this check is opt-in and not
#' part of a default run. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' invisible(file.remove(file.path(pkg, "cran-comments.md")))
#' lab_cran_comments_file(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_cran_comments_file <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  has_it <- file.exists(file.path(path, "cran-comments.md"))
  issues <- if (has_it) {
    character(0)
  } else {
    "No cran-comments.md file with submission notes"
  }
  report_check(
    issues,
    verbose,
    check_label("cran_comments_file"),
    "cran-comments.md found",
    "No cran-comments.md found",
    treatment = paste("Treatment:", treatments$cran_comments_file$treatment),
    level = "warning"
  )
}

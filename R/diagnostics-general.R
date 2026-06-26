#' Diagnose General Package Issues
#'
#' Runs general diagnostics on package structure and content that don't fit
#' into specific code, documentation, or DESCRIPTION categories.
#'
#' @details
#' This function checks:
#'
#' - Package size — measured against the files that would ship in the
#'   tarball (`.Rbuildignore` and standard scratch dirs are excluded), with
#'   a 5 MB warning threshold matching CRAN's recommendation.
#' - Invalid or problematic URLs in package files.
#' - Presence of a `NEWS` file documenting user-facing changes.
#' - Relative links in the `README` that would break on CRAN.
#'
#' [diagnose_cran_comments_file()] is intentionally not part of this default
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
  if (verbose) {
    cli::cli_h2("General Health Check")
  }

  run_checks(list(
    package_size  = diagnose_package_size,
    urls          = diagnose_urls,
    news_file     = diagnose_news_file,
    readme_links  = diagnose_readme_relative_links
  ), path, verbose)
}

#' Diagnose Package Size
#'
#' Estimates the size of the source package that would be shipped to CRAN
#' (files matched by `.Rbuildignore`, plus standard scratch directories like
#' `.git`, `.Rproj.user`, are excluded). Warns at the 5 MB threshold.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`,
#'   and `size_mb`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' diagnose_package_size(pkg_path, verbose = FALSE)$size_mb
diagnose_package_size <- function(path, verbose = TRUE) {
  all_files <- list.files(path, recursive = TRUE, full.names = FALSE,
                          all.files = TRUE, no.. = TRUE)
  ignore <- build_ignore_matcher(path)
  keep <- !ignore(all_files)
  all_files <- all_files[keep]

  full <- file.path(path, all_files)
  info <- file.info(full)
  size_mb <- sum(info$size, na.rm = TRUE) / (1024^2)

  passed <- size_mb <= 5
  issues <- if (passed) character(0) else paste0(
    "Package size ", round(size_mb, 2), " MB exceeds 5 MB"
  )

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
        "{.emph Treatment: Reduce package size or document in cran-comments.md}"
      )
    }
  }
  checktor_check_result(passed, issues, "Package size check", size_mb = size_mb)
}

#' Diagnose URL Issues in Package Files
#'
#' Checks common package files for `http://` URLs (should usually be
#' `https://`) and known URL shortener domains.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt",
#'                                       show_content = FALSE)
#' issues(diagnose_urls(pkg_path, verbose = FALSE))
diagnose_urls <- function(path, verbose = TRUE) {
  rd_files <- list.files(file.path(path, "man"),
                         pattern = "\\.Rd$", full.names = TRUE)
  vignette_files <- list.files(file.path(path, "vignettes"),
                               pattern = "\\.(Rmd|qmd|md)$", full.names = TRUE)
  text_files <- c(
    file.path(path, "DESCRIPTION"),
    file.path(path, "README.md"),
    file.path(path, "README.Rmd"),
    vignette_files
  )
  text_files <- text_files[file.exists(text_files)]

  if (length(text_files) == 0L && length(rd_files) == 0L) {
    return(checktor_check_result(TRUE, character(0), "URLs check"))
  }

  http_re      <- "http://(?!localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0)"
  shortener_re <- "\\b(bit\\.ly|tinyurl\\.com|goo\\.gl|t\\.co|ow\\.ly)\\b"

  issues <- character(0)
  for (file in text_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0L) next
    if (any(grepl(http_re, content, perl = TRUE))) {
      issues <- c(issues,
                  paste0(basename(file), ": http:// URL (should be https://)"))
    }
    if (any(grepl(shortener_re, content, perl = TRUE))) {
      issues <- c(issues,
                  paste0(basename(file), ": URL shortener (may redirect)"))
    }
  }

  # Rd files: parse and collect prose text so URLs in macros/sections are
  # caught but Rd markup itself isn't matched.
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) next
    text <- collect_rd_text(rd)
    if (!nzchar(text)) next
    if (grepl(http_re, text, perl = TRUE)) {
      issues <- c(issues,
                  paste0(basename(file), ": http:// URL (should be https://)"))
    }
    if (grepl(shortener_re, text, perl = TRUE)) {
      issues <- c(issues,
                  paste0(basename(file), ": URL shortener (may redirect)"))
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No obvious URL issues found",
    "Potential URL issues",
    level = "warning"
  )
  checktor_check_result(passed, issues, "URLs check")
}

#' Diagnose a Missing NEWS File
#'
#' CRAN expects packages (especially on resubmission) to document user-facing
#' changes in a `NEWS` file. Accepts `NEWS.md`, `NEWS`, or `NEWS.Rd` at the
#' package root or under `inst/`.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' file.remove(file.path(pkg_path, "NEWS.md"))   # demonstrate the failing case
#' issues(diagnose_news_file(pkg_path, verbose = FALSE))
diagnose_news_file <- function(path, verbose = TRUE) {
  candidates <- file.path(
    path,
    c("NEWS.md", "NEWS", "NEWS.Rd",
      file.path("inst", c("NEWS.md", "NEWS", "NEWS.Rd")))
  )
  has_news <- any(file.exists(candidates))
  issues <- if (has_news) character(0) else
    "No NEWS file found (add NEWS.md to document user-facing changes)"
  emit_issue_summary(
    issues, verbose,
    "NEWS file found",
    "No NEWS file found",
    "Treatment: Add a NEWS.md documenting changes per version (usethis::use_news_md())",
    level = "warning"
  )
  checktor_check_result(has_news, issues, "NEWS file check")
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
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' file.remove(file.path(pkg_path, "cran-comments.md"))  # failing case
#' issues(diagnose_cran_comments_file(pkg_path, verbose = FALSE))
diagnose_cran_comments_file <- function(path, verbose = TRUE) {
  has_it <- file.exists(file.path(path, "cran-comments.md"))
  issues <- if (has_it) character(0) else
    "No cran-comments.md file with submission notes"
  emit_issue_summary(
    issues, verbose,
    "cran-comments.md found",
    "No cran-comments.md found",
    "Treatment: Add cran-comments.md with submission notes (usethis::use_cran_comments())",
    level = "warning"
  )
  checktor_check_result(has_it, issues, "cran-comments file check")
}

# Pull link/image targets out of README text. Handles markdown `](target)`
# and `<a href=...>` / `<img src=...>` HTML attributes. Returns raw targets.
extract_link_targets <- function(text) {
  md <- regmatches(text, gregexpr("\\]\\([^)]+\\)", text, perl = TRUE))[[1L]]
  md <- sub("^\\]\\(", "", md)
  md <- sub("\\)$", "", md)
  md <- sub("\\s+[\"'].*$", "", md)          # strip optional link title
  html <- regmatches(
    text,
    gregexpr("(?:href|src)\\s*=\\s*[\"'][^\"']+[\"']", text, perl = TRUE)
  )[[1L]]
  html <- sub(".*[\"']([^\"']+)[\"']$", "\\1", html)
  trimws(c(md, html))
}

# TRUE for targets that are NOT package-relative file links: absolute URLs
# (any scheme), protocol-relative `//host`, in-page anchors `#sec`, or empty.
is_external_or_anchor <- function(tgt) {
  tgt <- trimws(tgt)
  !nzchar(tgt) ||
    grepl("^[A-Za-z][A-Za-z0-9+.-]*:", tgt) ||
    grepl("^//", tgt) ||
    grepl("^#", tgt)
}

#' Diagnose Relative Links in the README
#'
#' Relative links in `README.md`/`README.Rmd` render on GitHub but break on
#' CRAN when the target is not shipped in the built tarball. This flags
#' relative links whose target is missing on disk or excluded by
#' `.Rbuildignore` (and therefore absent after `R CMD build`). Relative links
#' to files that do ship (e.g. `man/figures/logo.png`) are not flagged.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' writeLines("See [the guide](docs/guide.md) for details.",
#'            file.path(pkg_path, "README.md"))
#' issues(diagnose_readme_relative_links(pkg_path, verbose = FALSE))
diagnose_readme_relative_links <- function(path, verbose = TRUE) {
  readmes <- file.path(path, c("README.md", "README.Rmd"))
  readmes <- readmes[file.exists(readmes)]
  if (length(readmes) == 0L) {
    return(checktor_check_result(TRUE, character(0),
                                 "README relative-links check"))
  }

  ignore <- build_ignore_matcher(path)
  issues <- character(0)
  for (file in readmes) {
    content <- safe_read_lines(file)
    if (length(content) == 0L) next
    text <- paste(content, collapse = "\n")
    for (tgt in extract_link_targets(text)) {
      if (is_external_or_anchor(tgt)) next
      rel <- trimws(sub("[#?].*$", "", tgt))   # drop fragment/query
      if (!nzchar(rel)) next
      local <- file.path(path, rel)
      if (!file.exists(local) && !dir.exists(local)) {
        issues <- c(issues, paste0(basename(file),
                                   ": relative link to missing file '", rel, "'"))
      } else if (isTRUE(ignore(rel))) {
        issues <- c(issues, paste0(basename(file),
                                   ": relative link to .Rbuildignore'd file '",
                                   rel, "' (won't ship to CRAN)"))
      }
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "README relative links resolve to shipped files",
    "README has relative links that may break on CRAN",
    "Treatment: Use full URLs, or ensure the target ships (not in .Rbuildignore)",
    level = "warning"
  )
  checktor_check_result(passed, issues, "README relative-links check")
}

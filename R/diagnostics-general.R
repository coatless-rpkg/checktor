#' Diagnose General Package Issues
#'
#' Runs general diagnostics on package structure and content that don't fit
#' into specific code, documentation, or DESCRIPTION categories.
#'
#' @details
#' This function checks:
#'
#' - Package size, measured against the files that would ship in the
#'   tarball (`.Rbuildignore` and standard scratch dirs are excluded), with
#'   a 5 MB warning threshold matching CRAN's recommendation.
#' - `http://` URLs and URL shorteners, offline. `R CMD check --as-cran` does
#'   fetch every URL, but only with a network and only under `--as-cran`; this
#'   is the fast local pass.
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
  path <- find_package_root(path)
  if (verbose) {
    cli::cli_h2("General Health Check")
  }

  run_checks(
    c(
      list(
        package_size = diagnose_package_size,
        urls = diagnose_urls,
        url_liveness = diagnose_url_liveness,
        news_file = diagnose_news_file,
        readme_links = diagnose_readme_relative_links
      ),
      registered_checks_for("general")
    ),
    path,
    verbose
  )
}

#' Diagnose Package Size
#'
#' Estimates the size of the source package that would be shipped to CRAN
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
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' diagnose_package_size(pkg_path, verbose = FALSE)$size_mb
diagnose_package_size <- function(path, verbose = TRUE) {
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
    raw_bytes <- tryCatch(readBin(f, what = "raw", n = n), error = function(e) {
      NULL
    })
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
        "{.emph Treatment: Reduce package size or document in cran-comments.md}"
      )
    }
  }
  checktor_check_result(passed, issues, "Package size check", size_mb = size_mb)
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
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' file.remove(file.path(pkg_path, "NEWS.md"))   # demonstrate the failing case
#' issues(diagnose_news_file(pkg_path, verbose = FALSE))
diagnose_news_file <- function(path, verbose = TRUE) {
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
  emit_issue_summary(
    issues,
    verbose,
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
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' file.remove(file.path(pkg_path, "cran-comments.md"))  # failing case
#' issues(diagnose_cran_comments_file(pkg_path, verbose = FALSE))
diagnose_cran_comments_file <- function(path, verbose = TRUE) {
  path <- find_package_root(path)
  has_it <- file.exists(file.path(path, "cran-comments.md"))
  issues <- if (has_it) {
    character(0)
  } else {
    "No cran-comments.md file with submission notes"
  }
  emit_issue_summary(
    issues,
    verbose,
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
  md <- sub("\\s+[\"'].*$", "", md) # strip optional link title
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
#' @section Source:
#' No formal rule. A relative README link whose target is excluded from the
#' tarball breaks on the package page, which is why this sits at `robustness`
#' tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
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
  path <- find_package_root(path)
  readmes <- file.path(path, c("README.md", "README.Rmd"))
  readmes <- readmes[file.exists(readmes)]
  if (length(readmes) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "README relative-links check"
    ))
  }

  ignore <- build_ignore_matcher(path)
  issues <- character(0)
  for (file in readmes) {
    content <- safe_read_lines(file)
    if (length(content) == 0L) {
      next
    }
    text <- paste(content, collapse = "\n")
    for (tgt in extract_link_targets(text)) {
      if (is_external_or_anchor(tgt)) {
        next
      }
      rel <- trimws(sub("[#?].*$", "", tgt)) # drop fragment/query
      if (!nzchar(rel)) {
        next
      }
      local <- file.path(path, rel)
      if (!file.exists(local) && !dir.exists(local)) {
        issues <- c(
          issues,
          paste0(basename(file), ": relative link to missing file '", rel, "'")
        )
      } else if (isTRUE(ignore(rel))) {
        issues <- c(
          issues,
          paste0(
            basename(file),
            ": relative link to .Rbuildignore'd file '",
            rel,
            "' (won't ship to CRAN)"
          )
        )
      }
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "README relative links resolve to shipped files",
    "README has relative links that may break on CRAN",
    "Treatment: Use full URLs, or ensure the target ships (not in .Rbuildignore)",
    level = "warning"
  )
  checktor_check_result(passed, issues, "README relative-links check")
}

#' Diagnose URL Issues in Package Files
#'
#' Flags `http://` URLs (which should almost always be `https://`) and known URL
#' shortener domains, across DESCRIPTION, README, vignettes and the `.Rd` files.
#'
#' This is a fast, **offline** pre-flight. `R CMD check --as-cran` does fetch every
#' URL and report status codes and redirect targets, but only with a network and
#' only under `--as-cran`, which is the slow end of the loop. This catches the two
#' problems you can find without leaving the room, before you spend ten minutes on
#' a full check.
#'
#' Literal spans are skipped, so documenting the string `http://` inside `\verb{}`,
#' `\code{}` or a fenced markdown block is not mistaken for linking to it.
#'
#' @section Source:
#' No formal rule. Preferring `https://` is good advice, but CRAN's NOTE is
#' about broken URLs rather than the scheme, which is why this sits at `opinion`
#' tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
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
  path <- find_package_root(path)
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
  vignette_files <- list.files(
    file.path(path, "vignettes"),
    pattern = "\\.(Rmd|qmd|md)$",
    full.names = TRUE
  )
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

  http_re <- "http://(?!localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0)[^\\s\"'>)\\]]*"
  shortener_re <- "\\bhttps?://(bit\\.ly|tinyurl\\.com|goo\\.gl|t\\.co|ow\\.ly)/[^\\s\"'>)\\]]*"

  report <- function(file, text) {
    out <- character(0)
    http <- unlist(regmatches(text, gregexpr(http_re, text, perl = TRUE)))
    for (u in unique(http)) {
      out <- c(out, paste0(basename(file), ": ", u, " (use https://)"))
    }
    short <- unlist(regmatches(text, gregexpr(shortener_re, text, perl = TRUE)))
    for (u in unique(short)) {
      out <- c(
        out,
        paste0(basename(file), ": ", u, " (URL shortener; use the real target)")
      )
    }
    out
  }

  issues <- character(0)
  for (file in text_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0L) {
      next
    }
    # A fenced code block in a README or vignette is a literal span, exactly like
    # \verb{} in Rd: a package that DOCUMENTS `http://` is not linking to it.
    content <- drop_fenced_code(content)
    issues <- c(issues, report(file, paste(content, collapse = "\n")))
  }

  rd_literal_spans <- c("\\verb", "\\code")
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    text <- collect_rd_text(rd, skip = rd_literal_spans)
    if (!nzchar(text)) {
      next
    }
    issues <- c(issues, report(file, text))
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No obvious URL issues found",
    "Potential URL issues",
    "Treatment: Switch to https://, and replace shorteners with the real target",
    level = "warning"
  )
  checktor_check_result(passed, issues, "URLs check")
}

# Drop fenced code blocks (``` ... ```) from markdown-ish text. They are literal
# spans: text inside them is being shown, not linked.
drop_fenced_code <- function(lines) {
  fence <- grepl("^\\s*```", lines)
  if (!any(fence)) {
    return(lines)
  }
  inside <- cumsum(fence) %% 2L == 1L
  lines[!(inside | fence)]
}

# A seam over R's own URL checker so the network fetch can be stubbed in tests.
# It returns the check_url_db data frame that tools::check_package_urls() builds.
fetch_url_db <- function(path) {
  tools::check_package_urls(path)
}

#' Diagnose Broken and Redirecting URLs (Opt-In, Network)
#'
#' Fetches every URL in the package -- DESCRIPTION, `.Rd` files, and vignettes --
#' and reports the ones that fail: 404s, other error statuses, and redirects that
#' ought to point at their final target. This is exactly what
#' `R CMD check --as-cran` does, through the same base R machinery
#' ([tools::check_package_urls()]); checktor simply surfaces it as a check so you
#' can run it without a full `--as-cran` pass and without depending on the
#' `urlchecker` package.
#'
#' Because it needs a network and is comparatively slow, it is **opt-in** and does
#' nothing until you enable it:
#'
#' ```r
#' options(checktor.url_check = TRUE)
#' checktor(".")
#' ```
#'
#' With the option unset -- or when the fetch cannot run, such as offline -- it
#' passes quietly, exactly as CRAN's own URL check does without connectivity. For
#' the fast, offline half (flagging `http://` and URL shorteners without leaving
#' the room) see [diagnose_urls()].
#'
#' @section Source:
#' The [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' run by `R CMD check --as-cran` fetches URLs and NOTEs 404s and redirects; it
#' is opt-in here because it needs a network. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' # Opt in first, then run against a package directory (needs a network):
#' \dontrun{
#' options(checktor.url_check = TRUE)
#' diagnose_url_liveness(".")
#' }
diagnose_url_liveness <- function(path, verbose = TRUE) {
  path <- find_package_root(path)
  # Opt-in: it needs a network and is slow, so it stays off unless asked for.
  if (!isTRUE(getOption("checktor.url_check", FALSE))) {
    return(checktor_check_result(TRUE, character(0), "URL liveness check"))
  }

  db <- tryCatch(
    suppressWarnings(suppressMessages(fetch_url_db(path))),
    error = function(e) NULL
  )
  # No DESCRIPTION, no URLs, or the fetch itself failed (e.g. offline): the
  # honest result is "nothing to report", not a wall of false failures.
  if (is.null(db) || !is.data.frame(db) || nrow(db) == 0L) {
    return(checktor_check_result(TRUE, character(0), "URL liveness check"))
  }

  col <- function(nm) {
    v <- db[[nm]]
    if (is.null(v)) {
      return(rep("", nrow(db)))
    }
    v <- as.character(v)
    v[is.na(v)] <- ""
    v
  }
  from <- col("From")
  status <- col("Status")
  message <- col("Message")
  new_target <- col("New")

  issues <- trimws(sprintf(
    "%s: %s -- %s%s%s",
    ifelse(nzchar(from), from, "DESCRIPTION"),
    col("URL"),
    ifelse(nzchar(status), status, "unreachable"),
    ifelse(nzchar(message), paste0(" ", message), ""),
    ifelse(nzchar(new_target), paste0(" -> ", new_target), "")
  ))

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "All URLs resolved cleanly",
    "URLs that failed to resolve",
    "Treatment: Fix or remove broken URLs; point redirects at their final target",
    level = "warning"
  )
  checktor_check_result(passed, issues, "URL liveness check")
}

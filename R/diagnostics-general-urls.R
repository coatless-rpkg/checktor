# General checks on the links and URLs in the package's files.

# Pull link/image targets out of README text. Handles markdown `](target)`
# and `<a href=...>` / `<img src=...>` HTML attributes. Returns raw targets.
#
# A destination written bare cannot contain whitespace; one that does is
# `<pointy bracketed>` or it is not a destination. That check is what tells a
# real link from a stray `](` in prose, and it is deliberately kept even though
# strip_markdown_code() already removes the usual source of those.
extract_link_targets <- function(text) {
  md <- regmatches(text, gregexpr("\\]\\([^)]+\\)", text, perl = TRUE))[[1L]]
  md <- sub("^\\]\\(", "", md)
  md <- sub("\\)$", "", md)
  md <- sub("\\s+[\"'].*$", "", md) # strip optional link title
  md <- trimws(md)
  pointy <- grepl("^<.*>$", md)
  md[pointy] <- sub("^<(.*)>$", "\\1", md[pointy])
  md <- md[pointy | !grepl("[[:space:]]", md)]
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
#' CRAN when the target is not included in the built tarball. This flags
#' relative links whose target is missing on disk or excluded by
#' `.Rbuildignore` (and therefore absent after `R CMD build`). Relative links
#' to files that are included (e.g. `man/figures/logo.png`) are not flagged.
#'
#' Only what a renderer turns into a link counts. Fenced code blocks, inline
#' code spans and HTML comments are left out of the scan, so a setup chunk
#' calling `knitr::opts_chunk[["set"]](...)` is read as the code it is rather
#' than as a link to a file named after its arguments.
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
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' # A relative link to a file the package does not have
#' writeLines("See [the guide](docs/guide.md) for details.",
#'            file.path(pkg, "README.md"))
#' lab_readme_links(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_readme_links <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  readmes <- file.path(path, c("README.md", "README.Rmd"))
  readmes <- readmes[file.exists(readmes)]
  if (length(readmes) == 0L) {
    return(pass_result(check_label("readme_links")))
  }

  ignore <- build_ignore_matcher(path)
  issues <- character(0)
  for (file in readmes) {
    content <- safe_read_lines(file)
    if (length(content) == 0L) {
      next
    }
    text <- strip_markdown_code(content)
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

  report_check(
    issues,
    verbose,
    check_label("readme_links"),
    "README relative links resolve to files in the package",
    "README has relative links that may break on CRAN",
    treatment = paste("Treatment:", treatments$readme_links$treatment),
    level = "warning"
  )
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
#' pkg <- example_diagnose_scenario("description_examples/bad_description.txt",
#'                                  show_content = FALSE)
#' lab_urls(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_urls <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  # Every vignette source R builds, Sweave and R.rsp included: an .Rnw vignette
  # links with \url{http://...} as readily as an .Rmd one.
  vignette_files <- list_included_files(path, "vignettes", VIGNETTE_SOURCE_PATTERN)
  text_files <- c(
    file.path(path, "DESCRIPTION"),
    file.path(path, "README.md"),
    file.path(path, "README.Rmd"),
    vignette_files
  )
  text_files <- text_files[file.exists(text_files)]

  if (length(text_files) == 0L && length(rd_files) == 0L) {
    return(pass_result(check_label("urls")))
  }

  # A URL ends at whitespace, a quote, a closing bracket or brace, or a backtick,
  # so the closing brace of a LaTeX \url{} or \href{} is not part of it.
  http_re <- "http://(?!localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0)[^\\s\"'>)\\]}`]*"
  shortener_re <- "\\bhttps?://(bit\\.ly|tinyurl\\.com|goo\\.gl|t\\.co|ow\\.ly)/[^\\s\"'>)\\]}`]*"

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
    rd <- read_rd_quietly(file)
    if (is.null(rd)) {
      next
    }
    text <- collect_rd_text(rd, skip = rd_literal_spans)
    if (!nzchar(text)) {
      next
    }
    issues <- c(issues, report(file, text))
  }

  report_check(
    issues,
    verbose,
    check_label("urls"),
    "No obvious URL issues found",
    "Potential URL issues",
    treatment = paste("Treatment:", treatments$urls$treatment),
    level = "warning"
  )
}

# Drop fenced code blocks from markdown-ish text. They are literal spans: text
# inside them is being shown, not linked.
#
# This counted backtick fences off against each other in pairs, which a README
# quoting markdown inside a ````-fence puts out of step: from the inner fence on,
# every code block read as prose and every paragraph read as code. It shares
# blank_fenced_code() with the README link scan now, so both know a tilde fence
# and a nested one.
drop_fenced_code <- function(lines) {
  blank_fenced_code(sub("\r+$", "", lines))
}

# A seam over R's own URL checker so the network fetch can be stubbed in tests.
# It returns the check_url_db data frame that tools::check_package_urls() builds,
# which is why the package needs R 4.5.0, the release that added it.
fetch_url_db <- function(path) {
  tools::check_package_urls(path)
}

#' Diagnose Broken and Redirecting URLs
#'
#' Fetches every URL in the package, across DESCRIPTION, `.Rd` files and
#' vignettes, and reports the ones that fail: 404s, other error statuses, and
#' redirects that ought to point at their final target. This is what
#' `R CMD check --as-cran` does, through the same base R machinery
#' ([tools::check_package_urls()]), so you can see those findings without a full
#' `--as-cran` pass and without depending on the `urlchecker` package.
#'
#' It runs by default when you are working at the console, since that is when a
#' broken link is worth knowing about and a pause for the network is fine. It stays
#' off in scripts, in continuous integration and under `R CMD check`, where a slow
#' or unreachable network would make results depend on the machine rather than the
#' package. Set the option either way to decide for yourself:
#'
#' ```r
#' options(checktor.url_check = TRUE)   # always check
#' options(checktor.url_check = FALSE)  # never check
#' ```
#'
#' Without a network nothing can be fetched, so the check is reported as skipped
#' rather than as passing. For the offline half, which flags `http://` links
#' and URL shorteners without leaving the room, see [lab_urls()].
#'
#' @section Source:
#' The [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' run by `R CMD check --as-cran` fetches URLs and NOTEs 404s and redirects. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' # Needs a network: it asks every URL the package lists whether it answers,
#' # so it is not run here. The scenario lists one page that exists and one that
#' # does not, and the missing one is reported with its 404. Outside an
#' # interactive session the check is skipped unless
#' # options(checktor.url_check = TRUE) turns it on.
#' \dontrun{
#' pkg <- example_diagnose_scenario("general_examples/url_liveness_bad.txt",
#'                                  show_content = FALSE)
#' lab_url_liveness(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
#' }
lab_url_liveness <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  # On at the console, off in scripts, CI and R CMD check, where a slow or missing
  # network would make the result depend on the machine rather than the package.
  # It also keeps examples and tests from reaching the network during a check.
  if (!isTRUE(getOption("checktor.url_check", interactive()))) {
    return(checktor_skipped_result(
      check_label("url_liveness"),
      "runs at the console; set options(checktor.url_check = TRUE) to always run it"
    ))
  }

  db <- tryCatch(
    suppressWarnings(suppressMessages(fetch_url_db(path))),
    error = function(e) NULL
  )
  # The fetch itself failed, so nothing was examined. Reporting a pass here would
  # make being offline -- or a change under the fetch -- read exactly like a
  # package whose every URL resolved.
  if (is.null(db) || !is.data.frame(db)) {
    return(checktor_skipped_result(
      check_label("url_liveness"),
      "the URL fetch did not complete, so no URL was checked"
    ))
  }
  # No DESCRIPTION or no URLs at all: there is genuinely nothing to be wrong.
  if (nrow(db) == 0L) {
    return(pass_result(check_label("url_liveness")))
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
  status <- col("Status")

  # A row whose status is not an HTTP code means R could not reach the host, which
  # says something about this machine rather than about the package. When that is
  # true of every row there is no working connection, so report nothing rather than
  # calling every link broken. A lone unreachable host among reachable ones is a
  # real finding and still counts.
  unreachable <- !grepl("^[0-9]+$", status)
  if (all(unreachable)) {
    return(checktor_skipped_result(
      check_label("url_liveness"),
      "no network reachable, so no URL could be checked"
    ))
  }

  from <- col("From")
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

  report_check(
    issues,
    verbose,
    check_label("url_liveness"),
    "All URLs resolved cleanly",
    "URLs that failed to resolve",
    treatment = paste("Treatment:", treatments$url_liveness$treatment),
    level = "warning"
  )
}

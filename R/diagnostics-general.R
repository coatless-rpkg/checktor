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
  if (verbose) {
    cli::cli_h2("General Health Check")
  }

  run_checks(
    c(
      list(
        package_size = lab_package_size,
        urls = lab_urls,
        url_liveness = lab_url_liveness,
        news_file = lab_news_file,
        readme_links = lab_readme_links,
        code_exercised = lab_code_exercised,
        citation_file = lab_citation_file
      ),
      registered_checks_for("general")
    ),
    path,
    verbose
  )
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
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' lab_package_size(pkg_path, verbose = FALSE)$size_mb
lab_package_size <- function(path, verbose = TRUE) {
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
#' issues(lab_news_file(pkg_path, verbose = FALSE))
lab_news_file <- function(path, verbose = TRUE) {
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
#' pkg_path <- example_diagnose_scenario(
#'   "general_examples/code_exercised_bad.R",
#'   show_content = FALSE
#' )
#' # The scenario's function is exported, as roxygen2 would record it
#' writeLines("export(tidy_values)", file.path(pkg_path, "NAMESPACE"))
#' issues(lab_code_exercised(pkg_path, verbose = FALSE))
lab_code_exercised <- function(path, verbose = TRUE) {
  path <- find_package_root(path)
  pass <- function() {
    checktor_check_result(TRUE, character(0), "Code exercised check")
  }

  # R asks only of a package with code in R/ that exports something. With no
  # readable NAMESPACE the exports are unknown, so there is nothing to judge.
  if (!dir.exists(file.path(path, "R"))) {
    return(pass())
  }
  ex <- package_exports(path)
  if (is.null(ex) || (length(ex$names) == 0L && length(ex$patterns) == 0L)) {
    return(pass())
  }

  if (package_has_examples(path)) {
    return(pass())
  }
  # R CMD check runs the scripts directly in tests/, nothing deeper.
  if (length(list_included_files(path, "tests", "\\.(r|R|Rin)$")) > 0L) {
    return(pass())
  }
  if (package_has_vignettes(path)) {
    return(pass())
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

  emit_issue_summary(
    issue,
    verbose,
    "The package has examples, tests or vignettes",
    "Nothing exercises the package's code",
    paste(
      "Treatment: Add {.code @examples} to exported functions, tests",
      "({.code usethis::use_testthat()}) or a vignette"
    ),
    level = "warning"
  )
  checktor_check_result(FALSE, issue, "Code exercised check")
}

# Does any help page the tarball includes carry an \examples section? R writes
# one out whatever it holds, \dontrun{} included, so its presence is what counts.
# A page that does not parse counts as having one: the check must not accuse a
# package on the strength of a file it could not read.
package_has_examples <- function(path) {
  for (file in list_rd_files(path)) {
    rd <- tryCatch(
      suppressWarnings(tools::parse_Rd(file)),
      error = function(e) NULL
    )
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

#' Diagnose Old-Style or Unsafe Calls in inst/CITATION
#'
#' Flags an `inst/CITATION` that calls the old-style `citEntry()` (use
#' `bibentry()`) or `personList()` and `as.personList()` (use `c()` on `person`
#' objects), or that calls `packageDescription()`, `library()` or `require()`.
#' R passes the file a `meta` object holding the package's DESCRIPTION, so it
#' needs none of those, and each assumes the package is already installed.
#'
#' As in R, the fallback
#' `if (!exists("meta") || is.null(meta)) meta <- packageDescription("pkg")`
#' is exempt: a top-level `if` with exactly that condition and no `else`. The file is parsed and never run, so a name in a
#' comment or a string is not a call. A CITATION that does not parse is reported,
#' with the line R stops at. A CITATION that `.Rbuildignore` excludes is not in
#' the tarball and is not read.
#'
#' @section Source:
#' The [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' (`R CMD check --as-cran`) NOTEs "Package CITATION file contains call(s) to
#' old-style citEntry(). Please use bibentry() instead." and "... old-style
#' personList() or as.personList(). Please use c() on person objects instead.",
#' and lists calls to `packageDescription`, `library` and `require`.
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#CITATION-files),
#' under "CITATION files", says "It is desirable (and essential for CRAN) that the
#' CITATION file does not contain calls to functions such as packageDescription
#' which assume the package is installed in a library tree on the package search
#' path." `devtools::check()` turns the incoming check off by default. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario(
#'   "general_examples/citation_file_bad.CITATION",
#'   show_content = FALSE
#' )
#' issues(lab_citation_file(pkg_path, verbose = FALSE))
lab_citation_file <- function(path, verbose = TRUE) {
  path <- find_package_root(path)
  file <- list_included_files(path, "inst", "^CITATION$")
  if (length(file) == 0L) {
    return(checktor_check_result(TRUE, character(0), "CITATION file check"))
  }
  rel <- "inst/CITATION"
  lines <- citation_lines(file, path)

  # Parse only; never evaluate. parse_text_xml() says only whether it parsed, so
  # the reason comes from a plain parse() of the same text.
  err <- tryCatch(
    {
      parse(text = lines, keep.source = FALSE)
      NULL
    },
    error = function(e) conditionMessage(e)
  )
  issues <- if (!is.null(err)) {
    # R words the position "<text>:3:5: unexpected symbol" for a syntax error
    # and "invalid multibyte character in parser (<input>:1:20)" for an encoding
    # one. Either way the finding leads with the file, line and column.
    first <- strsplit(err, "\n", fixed = TRUE)[[1]][[1]]
    pos <- "<(text|input)>:([0-9]+:[0-9]+)"
    at <- regmatches(first, regexec(pos, first))[[1]]
    reason <- trimws(gsub(paste0("\\(?", pos, "\\)?:? ?"), "", first))
    if (length(at) == 3L) {
      lc <- strsplit(at[[3]], ":", fixed = TRUE)[[1]]
      sprintf(
        "%s:%s (does not parse: %s at column %s)",
        rel,
        lc[[1]],
        reason,
        lc[[2]]
      )
    } else {
      paste0(rel, " (does not parse: ", reason, ")")
    }
  } else {
    citation_call_issues(parse_text_xml(lines), rel)
  }

  emit_issue_summary(
    issues,
    verbose,
    "inst/CITATION uses bibentry() and the meta object",
    if (is.null(err)) {
      "inst/CITATION has calls CRAN asks to replace"
    } else {
      "inst/CITATION does not parse"
    },
    if (is.null(err)) {
      paste(
        "Treatment: Use {.code bibentry()} and {.code c()} on {.code person()}",
        "objects, and read the DESCRIPTION through {.code meta}"
      )
    } else {
      "Treatment: Fix the syntax error so R can read the citation"
    },
    level = "warning"
  )
  checktor_check_result(length(issues) == 0L, issues, "CITATION file check")
}

# The CITATION's lines as UTF-8. R reads the file in the package's declared
# Encoding, so a latin1 package's CITATION is re-encoded rather than rejected.
citation_lines <- function(file, path) {
  lines <- safe_read_lines(file)
  desc <- file.path(path, "DESCRIPTION")
  enc <- tryCatch(
    unname(read_dcf_quietly(desc, fields = "Encoding")[1L, "Encoding"]),
    error = function(e) NA_character_
  )
  if (!is.na(enc) && !toupper(enc) %in% c("UTF-8", "UTF8")) {
    converted <- iconv(lines, from = enc, to = "UTF-8")
    if (!anyNA(converted)) lines <- converted
  }
  lines
}

# What each flagged call should become.
CITATION_CALL_ADVICE <- c(
  citEntry = "is old-style; use bibentry()",
  personList = "is old-style; use c() on person objects",
  as.personList = "is old-style; use c() on person objects",
  packageDescription = paste(
    "assumes the package is installed; read the DESCRIPTION from the `meta`",
    "object R passes to the file"
  ),
  library = "assumes the package is installed; a CITATION file loads nothing",
  require = "assumes the package is installed; a CITATION file loads nothing"
)

# The exempt fallback, as R tests it: a top-level `if`, with no else, whose
# condition is `!exists("meta") || is.null(meta)`. Compared token by token, with
# the string requoted in double quotes, which is what R's deparse() comparison
# amounts to: spacing and quote style do not matter, anything else does.
META_FALLBACK <- '! exists ( "meta" ) || is.null ( meta )'
META_FALLBACK_TOKENS <- strsplit(META_FALLBACK, " ", fixed = TRUE)[[1]]

is_meta_fallback <- function(expr) {
  if (
    length(xml2::xml_find_all(expr, "./IF")) != 1L ||
      length(xml2::xml_find_all(expr, "./ELSE")) > 0L
  ) {
    return(FALSE)
  }
  cond <- xml2::xml_find_first(
    expr,
    "./OP-LEFT-PAREN/following-sibling::expr[1]"
  )
  tokens <- xml2::xml_find_all(cond, ".//*[not(*)]")
  text <- xml2::xml_text(tokens)
  str <- xml2::xml_name(tokens) == "STR_CONST"
  text[str] <- paste0('"', unquote_name(text[str]), '"')
  identical(text, META_FALLBACK_TOKENS)
}

citation_call_issues <- function(xml, rel) {
  if (is.null(xml)) {
    return(character(0))
  }
  top <- xml2::xml_find_all(xml, "/exprlist/expr")
  exempt <- xml2::xml_path(top[vapply(top, is_meta_fallback, logical(1))])

  funs <- names(CITATION_CALL_ADVICE)
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[",
    paste0("text() = '", funs, "'", collapse = " or "),
    "]"
  )
  nodes <- xml2::xml_find_all(xml, xpath)
  fn <- xml2::xml_text(nodes)
  in_fallback <- vapply(
    nodes,
    function(n) {
      owner <- xml2::xml_find_first(n, "ancestor::expr[parent::exprlist]")
      xml2::xml_path(owner) %in% exempt
    },
    logical(1)
  )
  # The fallback excuses the calls that assume an installed package, which is all
  # R lets it excuse; an old-style call is old-style wherever it sits.
  keep <- !(in_fallback & fn %in% c("packageDescription", "library", "require"))
  nodes <- nodes[keep]
  fn <- fn[keep]
  if (length(fn) == 0L) {
    return(character(0))
  }
  # "file:line (label)", the shape issues() and ci_report() read a location from.
  sprintf(
    "%s:%s (%s() %s)",
    rel,
    xml2::xml_attr(nodes, "line1"),
    fn,
    unname(CITATION_CALL_ADVICE[fn])
  )
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
#' issues(lab_cran_comments_file(pkg_path, verbose = FALSE))
lab_cran_comments_file <- function(path, verbose = TRUE) {
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
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' writeLines("See [the guide](docs/guide.md) for details.",
#'            file.path(pkg_path, "README.md"))
#' issues(lab_readme_links(pkg_path, verbose = FALSE))
lab_readme_links <- function(path, verbose = TRUE) {
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

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "README relative links resolve to files in the package",
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
#' issues(lab_urls(pkg_path, verbose = FALSE))
lab_urls <- function(path, verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  vignette_files <- list_included_files(path, "vignettes", "\\.(Rmd|qmd|md)$")
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

  http_re <- "http://(?!localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0)[^\\s\"'>)\\]`]*"
  shortener_re <- "\\bhttps?://(bit\\.ly|tinyurl\\.com|goo\\.gl|t\\.co|ow\\.ly)/[^\\s\"'>)\\]`]*"

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
#' # Needs a network, so this is not run automatically:
#' \dontrun{
#' lab_url_liveness(".")
#' }
lab_url_liveness <- function(path, verbose = TRUE) {
  path <- find_package_root(path)
  # On at the console, off in scripts, CI and R CMD check, where a slow or missing
  # network would make the result depend on the machine rather than the package.
  # It also keeps examples and tests from reaching the network during a check.
  if (!isTRUE(getOption("checktor.url_check", interactive()))) {
    return(checktor_skipped_result(
      "URL liveness check",
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
      "URL liveness check",
      "the URL fetch did not complete, so no URL was checked"
    ))
  }
  # No DESCRIPTION or no URLs at all: there is genuinely nothing to be wrong.
  if (nrow(db) == 0L) {
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
  status <- col("Status")

  # A row whose status is not an HTTP code means R could not reach the host, which
  # says something about this machine rather than about the package. When that is
  # true of every row there is no working connection, so report nothing rather than
  # calling every link broken. A lone unreachable host among reachable ones is a
  # real finding and still counts.
  unreachable <- !grepl("^[0-9]+$", status)
  if (all(unreachable)) {
    return(checktor_skipped_result(
      "URL liveness check",
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

# Checks on how the Description cites references (DOIs, arXiv ids, links).

# CRAN's incoming rules for links in the Description, copied from
# tools:::.check_package_CRAN_incoming (R 4.6.1) rather than called through
# `:::`. R joins the alternatives of a rule with "|" and applies them, case
# sensitive or not as given here, to each line of strwrap(Description). A test
# holds `r_patterns` to R's own source. `label` opens the finding, and R's own
# message is the one its NOTE prints.
DESCRIPTION_REFERENCE_RULES <- list(
  bad_urls = list(
    r_patterns = "(^|[^</\"])https?://",
    ignore_case = FALSE,
    label = "URL not enclosed in angle brackets (<...>)",
    r_message = "Please enclose URLs in angle brackets (<...>)."
  ),
  bad_dois = list(
    r_patterns = c("https?:.*doi.org/", "(^|[^<])doi:", "<doi[^:]", "<10[.]"),
    ignore_case = TRUE,
    label = "DOI not written as <doi:prefix/suffix>",
    r_message = "Please write DOIs as <doi:prefix/suffix>."
  ),
  replace_by_doi = list(
    r_patterns = "<https?:.*/10\\.\\d{4,}/.*?>",
    ignore_case = TRUE,
    label = "Publisher link to a DOI, which CRAN asks to see as <doi:prefix/suffix>",
    r_message = paste(
      "Please use permanent DOI markup for linking to publications as in",
      "<doi:prefix/suffix>."
    )
  ),
  bad_arxiv = list(
    r_patterns = c(
      "<(arXiv|arxiv):(([[:alpha:].-]+/)?[[:digit:].]+)(v[[:digit:]]+)?([[:space:]]*\\[[^]]+\\])?>",
      "https?://arxiv.org",
      "(^|[^<])arxiv:",
      "<arxiv[^:]"
    ),
    ignore_case = TRUE,
    label = "arXiv reference, which CRAN asks to see as its arXiv DOI",
    r_message = paste(
      "Please refer to arXiv e-prints via their arXiv DOI",
      "<doi:10.48550/arXiv.YYMM.NNNNN>."
    )
  )
)

# The whitespace-delimited text around each match of `pattern` in `lines`, so a
# finding quotes the reference itself rather than the whole wrapped line.
# Trailing sentence punctuation is dropped.
reference_spans <- function(lines, pattern, ignore_case = FALSE) {
  spans <- character(0)
  for (line in lines) {
    m <- gregexpr(pattern, line, ignore.case = ignore_case)[[1L]]
    if (m[1L] < 1L) {
      next
    }
    tok <- gregexpr("[^[:space:]]+", line)[[1L]]
    tok_end <- tok + attr(tok, "match.length") - 1L
    for (i in seq_along(m)) {
      first <- m[i]
      last <- m[i] + attr(m, "match.length")[i] - 1L
      hit <- tok_end >= first & tok <= last
      if (any(hit)) {
        span <- substr(line, min(tok[hit]), max(tok_end[hit]))
        # The sentence's punctuation is not part of the reference.
        spans <- c(spans, sub("[.,;]+$", "", span))
      }
    }
  }
  unique(spans)
}

# The arXiv DOI for a span naming an arXiv e-print, as "<doi:10.48550/arXiv.ID>",
# or "" when no identifier can be read from it. A version suffix is dropped, as
# the DOI names the e-print rather than one version of it.
arxiv_doi_for <- function(span) {
  rx <- "(?i)arxiv(?:\\.org/(?:abs|pdf)/|:)((?:[a-z.-]+/)?[0-9]+(?:\\.[0-9]+)*)"
  m <- regmatches(span, regexec(rx, span, perl = TRUE))[[1L]]
  if (length(m) < 2L) {
    return("")
  }
  paste0("<doi:10.48550/arXiv.", sub("\\.$", "", m[2L]), ">")
}

#' Diagnose Reference Formatting in DESCRIPTION
#'
#' Flags the links in the `Description` that CRAN's incoming check NOTEs,
#' applying its own rules to the same wrapped lines R reads:
#'
#' * a URL not enclosed in angle brackets, which should read `<https://...>`;
#' * a DOI not written as `<doi:prefix/suffix>`, such as a `https://doi.org/`
#'   link, a bare `doi:`, `<doi` with no colon, or `<10.xxxx/...>`;
#' * a publisher link that embeds a DOI, such as
#'   `<https://onlinelibrary.wiley.com/doi/10.1002/...>`, reported only when no
#'   DOI is malformed, as R does;
#' * an arXiv id or link, such as `<arXiv:1509.03700>` or
#'   `<https://arxiv.org/abs/...>`, which should be the e-print's arXiv DOI,
#'   `<doi:10.48550/arXiv.1509.03700>`.
#'
#' It also flags a reference with no closing `>`, which CRAN's page does not
#' render as a link. Each rule is one finding, quoting every reference that
#' breaks it. A space after the colon, as in `<doi: 10.1000/xyz>`, is left
#' alone: R does not NOTE it and CRAN's page links it all the same.
#'
#' @section Source:
#' The [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' run by `R CMD check --as-cran` NOTEs each of the four forms, with "Please
#' enclose URLs in angle brackets (<...>).", "Please write DOIs as
#' <doi:prefix/suffix>.", "Please use permanent DOI markup for linking to
#' publications as in <doi:prefix/suffix>." and "Please refer to arXiv e-prints
#' via their arXiv DOI <doi:10.48550/arXiv.YYMM.NNNNN>.". The
#' [submission checklist](https://cran.r-project.org/web/packages/submission_checklist.html)
#' says "arXiv preprints should be referred to via their arXiv DOI", and the
#' Cookbook's [References](https://contributor.r-project.org/cran-cookbook/description_issues.html#references)
#' recipe asks for "angle brackets for auto-linking". `devtools::check()` turns the incoming check off, so these
#' usually surface first on win-builder or at CRAN. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/references_bad.txt",
#'                                  show_content = FALSE)
#' lab_references(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_references <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  text <- desc_value(desc, "Description")
  issues <- character(0)
  if (!is.null(text)) {
    # As R reads it: one line, then wrapped. The width is fixed at the one R
    # uses in an 80-column session, so the result does not depend on the console.
    flat <- gsub("[\n\t]", " ", trimws(text))
    lines <- strwrap(flat, width = 72L)

    report <- function(rule, spans = NULL) {
      if (is.null(spans)) {
        spans <- reference_spans(
          lines,
          paste(rule$r_patterns, collapse = "|"),
          rule$ignore_case
        )
      }
      if (length(spans) == 0L) {
        return(character(0))
      }
      paste0(rule$label, ": ", paste(spans, collapse = ", "))
    }
    rules <- DESCRIPTION_REFERENCE_RULES
    issues <- c(issues, report(rules$bad_urls))
    dois <- report(rules$bad_dois)
    # R reports a publisher link only when no DOI is malformed (an else-branch).
    issues <- c(
      issues,
      if (length(dois)) dois else report(rules$replace_by_doi)
    )
    arxiv <- reference_spans(
      lines,
      paste(rules$bad_arxiv$r_patterns, collapse = "|"),
      TRUE
    )
    if (length(arxiv)) {
      fixes <- vapply(arxiv, arxiv_doi_for, "", USE.NAMES = FALSE)
      arxiv <- ifelse(nzchar(fixes), paste0(arxiv, " (write ", fixes, ")"), arxiv)
    }
    issues <- c(issues, report(rules$bad_arxiv, arxiv))

    # A space after the colon, as in <doi: 10.1000/xyz>, is not reported. The
    # Cookbook asks for none, but R does not NOTE it, CRAN's page renders it as a
    # working link (tools:::.DESCRIPTION_to_HTML allows the space), and 76 of the
    # packages CRAN published in the year to September 2026 carry one.
    #
    # An unclosed reference, with no '>' anywhere after the opening, is read from
    # the flat text so a reference split by the wrap is still whole. R does not
    # NOTE it, but CRAN's page renders a reference as a link only when it is
    # closed. A SICI DOI has angle brackets of its own, so the next '<' is no
    # sign the reference ended.
    open <- regmatches(
      flat,
      gregexpr("<(doi|https?|arxiv):[^>]*$", flat, ignore.case = TRUE)
    )[[1L]]
    if (length(open)) {
      issues <- c(
        issues,
        paste0(
          "Reference with no closing '>': ",
          sub("[.,;]+$", "", sub("[[:space:]].*", "", open))
        )
      )
    }
  }

  report_check(
    issues,
    verbose,
    check_label("references"),
    "References in Description are in CRAN's form",
    "References in Description are not in CRAN's form",
    treatment = paste("Treatment:", treatments$references$treatment)
  )
}

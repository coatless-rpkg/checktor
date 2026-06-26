#' Diagnose DESCRIPTION File Issues
#'
#' Runs diagnostics against the package DESCRIPTION file. Fields are parsed
#' with [base::read.dcf()] so that multi-line fields like `Description` and
#' `Title` are inspected in full, not just their first physical line.
#'
#' @param path Character. Path to the R package directory. Default: `"."`.
#' @param verbose Logical. Whether to print diagnostic output. Default: `TRUE`.
#'
#' @return
#' List containing one named element per check. Each element is a list with at
#' least `passed`, `issues`, and `message` (see [checktor_check_result()]).
#'
#' @seealso
#' [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt",
#'                                       show_content = FALSE)
#' results <- diagnose_description_issues(pkg_path, verbose = FALSE)
#' results$license$passed       # MIT + file LICENSE flagged depends on standard
diagnose_description_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("DESCRIPTION File Health Check")
  }

  results <- list()

  desc_file <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_file)) {
    if (verbose) cli::cli_alert_danger("DESCRIPTION file not found")
    out <- list(passed = FALSE, message = "DESCRIPTION file not found")
    class(out) <- "checktor_category_result"
    return(out)
  }

  desc <- tryCatch(
    read_description(desc_file),
    error = function(e) NULL
  )
  if (is.null(desc)) {
    if (verbose) cli::cli_alert_danger("Could not parse DESCRIPTION file")
    out <- list(passed = FALSE, message = "Could not parse DESCRIPTION file")
    class(out) <- "checktor_category_result"
    return(out)
  }

  # The DESCRIPTION sub-checks operate on the parsed `desc` (and `path` for
  # license cross-checks), not on the package path directly. Build a small
  # adapter list so we can still use run_checks() for the tryCatch/passed
  # bookkeeping.
  checks <- list(
    software_names      = function(p, v) diagnose_software_names_formatting(desc, v),
    acronyms            = function(p, v) diagnose_acronym_explanation(desc, v),
    license             = function(p, v) diagnose_license_formatting(desc, p, v),
    title_case          = function(p, v) diagnose_title_case(desc, v),
    title_starts_with_article = function(p, v) diagnose_title_starts_with_article(desc, v),
    title_redundant_phrases   = function(p, v) diagnose_title_redundant_phrases(desc, v),
    authors             = function(p, v) diagnose_authors_field(desc, v),
    cph_role            = function(p, v) diagnose_cph_role(desc, v),
    references          = function(p, v) diagnose_references_formatting(desc, v),
    description_length  = function(p, v) diagnose_description_length(desc, v),
    description_starts_with   = function(p, v) diagnose_description_starts_with(desc, v),
    description_bare_r        = function(p, v) diagnose_description_bare_r(desc, v),
    description_quoted_quotes = function(p, v) diagnose_description_quoted_quotes(desc, v),
    license_year        = function(p, v) diagnose_license_year(p, v)
  )
  run_checks(checks, path, verbose)
}

# Returns a named list of DESCRIPTION fields, with multi-line fields collapsed.
# Using read.dcf folds continuation lines into a single string per field.
read_description <- function(desc_file) {
  raw <- read.dcf(desc_file)
  if (nrow(raw) == 0L) {
    stop("DESCRIPTION has no records")
  }
  as.list(raw[1L, ])
}

diagnose_software_names_formatting <- function(desc, verbose) {
  # Software names other than "R" itself; "R" appears too often legitimately
  # (e.g., "R package", "R session") to flag generically.
  software_names <- c("Python", "Java", "C\\+\\+", "SQL", "HTML", "CSS",
                      "JavaScript", "ggplot2", "dplyr", "tidyr")
  issues <- character(0)

  for (field in c("Title", "Description")) {
    text <- desc[[field]]
    if (is.null(text) || !nzchar(text)) next
    for (name in software_names) {
      if (grepl(paste0("\\b", name, "\\b"), text) &&
          !grepl(paste0("'", name, "'"), text)) {
        issues <- c(issues,
                    paste0(field, ": ", gsub("\\\\", "", name),
                           " should be in single quotes"))
      }
    }
  }

  passed <- length(issues) == 0
  emit_issue_summary(
    issues, verbose,
    "Software names appear properly formatted",
    "Potential software name formatting issues",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Software names check")
}

diagnose_acronym_explanation <- function(desc, verbose) {
  text <- desc[["Description"]]
  if (is.null(text) || !nzchar(text)) {
    return(checktor_check_result(TRUE, character(0), "Acronyms check"))
  }

  acronyms <- regmatches(text, gregexpr("\\b[A-Z]{2,6}\\b", text))[[1]]
  common_abbrevs <- c("API", "SQL", "HTML", "CSS", "PDF", "XML", "JSON",
                      "URL", "HTTP", "HTTPS", "FTP", "GUI", "CLI", "CRAN",
                      "ID", "OS", "TLS", "SSL", "UTF", "ASCII")
  unexplained <- setdiff(unique(acronyms), common_abbrevs)

  passed <- length(unexplained) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No unexplained acronyms found")
    } else {
      cli::cli_alert_warning(
        "Potential unexplained acronyms: {.val {paste(unexplained, collapse = ', ')}}"
      )
      cli::cli_text("{.emph Treatment: Consider explaining these acronyms}")
    }
  }
  checktor_check_result(passed, unexplained, "Acronyms check")
}

diagnose_license_formatting <- function(desc, path, verbose) {
  license <- desc[["License"]]
  if (is.null(license) || !nzchar(license)) {
    if (verbose) cli::cli_alert_warning("No License field found")
    return(checktor_check_result(FALSE, character(0), "License check"))
  }

  has_file_clause <- grepl("\\+\\s*file\\s+LICENSE", license)
  license_file <- file.path(path, "LICENSE")

  # MIT (and BSD) actually REQUIRE "+ file LICENSE" because the template
  # encodes copyright holders in a LICENSE file. Standard variants that do
  # not need a LICENSE file include GPL-2, GPL-3, AGPL-3, LGPL-*, Apache-2.0.
  needs_license_file <- grepl("\\b(MIT|BSD_2_clause|BSD_3_clause)\\b", license)
  no_license_file_ok <- grepl(
    "^(GPL|AGPL|LGPL|Apache|Artistic|Unlimited|Mozilla)",
    license
  )

  issues <- character(0)
  if (needs_license_file && !has_file_clause) {
    issues <- c(issues,
                "MIT/BSD license requires '+ file LICENSE' for copyright holders")
  } else if (needs_license_file && has_file_clause && !file.exists(license_file)) {
    issues <- c(issues, "License declares '+ file LICENSE' but no LICENSE file found")
  } else if (no_license_file_ok && has_file_clause && !file.exists(license_file)) {
    issues <- c(issues,
                "Standard license declares '+ file LICENSE' without a LICENSE file")
  }

  passed <- length(issues) == 0
  emit_issue_summary(
    issues, verbose,
    "License formatting appears correct",
    "License formatting issues",
    level = "warning"
  )
  checktor_check_result(passed, issues, "License check", license = license)
}

diagnose_title_case <- function(desc, verbose) {
  title <- desc[["Title"]]
  if (is.null(title) || !nzchar(title)) {
    if (verbose) cli::cli_alert_warning("No Title field found")
    return(checktor_check_result(FALSE, character(0), "Title case check"))
  }

  words <- strsplit(title, "\\s+")[[1]]
  # Lowercase-allowed words mid-title (articles, short prepositions, conjunctions)
  small_words <- c("a", "an", "the", "and", "or", "but", "for", "nor",
                   "of", "to", "in", "on", "at", "by", "with", "as",
                   "from", "into", "vs", "via")

  issues <- character(0)
  for (i in seq_along(words)) {
    word <- words[i]
    if (!nzchar(word)) next
    # Strip surrounding quotes/punctuation for the case check
    bare <- gsub("[[:punct:]]", "", word)
    if (!nzchar(bare)) next

    if (i == 1L) {
      if (!grepl("^[A-Z]", bare)) {
        issues <- c(issues, paste("First word should be capitalized:", word))
      }
    } else {
      is_small <- tolower(bare) %in% small_words
      starts_caps <- grepl("^[A-Z]", bare)
      if (!is_small && !starts_caps) {
        issues <- c(issues, paste("Word should be capitalized:", word))
      }
    }
  }

  passed <- length(issues) == 0
  emit_issue_summary(
    issues, verbose,
    "Title appears to be in Title Case",
    "Potential Title Case issues",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Title case check")
}

diagnose_authors_field <- function(desc, verbose) {
  has_authors_r <- !is.null(desc[["Authors@R"]]) && nzchar(desc[["Authors@R"]])
  has_legacy <- (!is.null(desc[["Author"]]) && nzchar(desc[["Author"]])) ||
    (!is.null(desc[["Maintainer"]]) && nzchar(desc[["Maintainer"]]))

  passed <- has_authors_r
  issues <- if (passed) character(0) else "Missing Authors@R field"

  if (verbose) {
    if (passed) {
      cli::cli_alert_success("{.code Authors@R} field found")
    } else {
      cli::cli_alert_warning("No {.code Authors@R} field found")
      if (has_legacy) {
        cli::cli_text("{.emph Legacy Author/Maintainer fields detected}")
      }
      cli::cli_text("{.emph Treatment: Consider adding Authors@R field}")
    }
  }
  checktor_check_result(passed, issues, "Authors@R field check")
}

diagnose_references_formatting <- function(desc, verbose) {
  text <- desc[["Description"]]
  if (is.null(text) || !nzchar(text)) {
    return(checktor_check_result(TRUE, character(0), "References check"))
  }

  has_doi <- grepl("<doi:", text)
  has_url <- grepl("<https?:", text)
  has_arxiv <- grepl("<arXiv:", text, ignore.case = TRUE)
  has_references <- has_doi || has_url || has_arxiv

  issues <- character(0)
  if (has_references) {
    if (grepl("<doi:\\s+", text)) {
      issues <- c(issues, "Space found after 'doi:' - should be no space")
    }
    if (grepl("<https?:\\s+", text)) {
      issues <- c(issues, "Space found after 'https:' - should be no space")
    }
    # References should be enclosed in <...>, with a closing '>'
    open_count <- length(gregexpr("<(doi|https?|arXiv)", text, ignore.case = TRUE)[[1]])
    if (open_count > 0L && !grepl(">", text)) {
      issues <- c(issues, "Reference markup is missing a closing '>'")
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed && has_references) {
      cli::cli_alert_success("Reference formatting appears correct")
    } else if (passed && !has_references) {
      cli::cli_alert_info("No references found in Description")
    } else {
      cli::cli_alert_warning("Reference formatting issues")
      cli::cli_ul(issues)
    }
  }
  checktor_check_result(passed, issues, "References check")
}

diagnose_description_length <- function(desc, verbose) {
  text <- desc[["Description"]]
  if (is.null(text) || !nzchar(text)) {
    if (verbose) cli::cli_alert_warning("No Description field found")
    return(checktor_check_result(FALSE, character(0), "Description length check"))
  }

  # read.dcf returns multi-line fields with embedded newlines; treat \n as space
  flat <- gsub("\\s+", " ", text)
  sentences <- length(strsplit(flat, "[.!?]+\\s+|[.!?]+$")[[1]])
  word_count <- length(strsplit(trimws(flat), "\\s+")[[1]])

  passed <- sentences >= 2 && word_count >= 20
  issues <- if (passed) character(0) else paste0(
    "Description too short: ", sentences, " sentences, ", word_count, " words"
  )

  if (verbose) {
    if (passed) {
      cli::cli_alert_success("Description length appears adequate")
    } else {
      cli::cli_alert_warning(
        "Description may be too short: {.val {sentences}} sentences, {.val {word_count}} words"
      )
      cli::cli_text("{.emph Treatment: Consider expanding to 2+ sentences, 20+ words}")
    }
  }
  checktor_check_result(passed, issues, "Description length check",
                        sentences = sentences, words = word_count)
}

# Description must not start with one of CRAN's forbidden phrases.
diagnose_description_starts_with <- function(desc, verbose) {
  text <- desc[["Description"]]
  if (is.null(text) || !nzchar(text)) {
    return(checktor_check_result(TRUE, character(0),
                                 "Description starts-with check"))
  }
  flat <- trimws(gsub("\\s+", " ", text))
  forbidden <- c("^This package\\b",
                 "^Functions for\\b",
                 sprintf("^%s\\b", desc[["Package"]] %||% "")
  )
  forbidden <- forbidden[nzchar(forbidden) & forbidden != "^\\b"]

  issues <- character(0)
  for (pat in forbidden) {
    if (grepl(pat, flat, perl = TRUE)) {
      issues <- c(issues,
                  paste0("Description starts with forbidden phrase: '",
                         gsub("\\^|\\\\b", "", pat), "'"))
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Description does not start with a forbidden phrase",
    "Description starts with a CRAN-forbidden phrase",
    "Treatment: Rephrase so Description leads with what the package does",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Description starts-with check")
}

# Bare 'R' (the language name) should be quoted as 'R' in Description.
# Match 'R' as a standalone word, excluding cases already quoted or part of
# acronyms like 'CRAN' / 'RStudio'.
diagnose_description_bare_r <- function(desc, verbose) {
  text <- desc[["Description"]]
  if (is.null(text) || !nzchar(text)) {
    return(checktor_check_result(TRUE, character(0),
                                 "Description bare-R check"))
  }
  # read.dcf preserves the physical line breaks inside multi-line fields;
  # collapse them so phrase-level whitelisting works.
  text <- gsub("\\s+", " ", text)
  # Whitelist the canonical CRAN expansion - by convention the embedded R is
  # not quoted.
  text <- gsub("Comprehensive R Archive Network",
               "Comprehensive_X_Archive_Network", text, fixed = TRUE)
  # Match bare R with surrounding non-word chars, not preceded by quote or
  # alphabetic character. Allow 'R CMD check' and similar inside single quotes.
  pat <- "(?<![A-Za-z0-9_'])R(?![A-Za-z0-9_'])"
  if (grepl(pat, text, perl = TRUE)) {
    issues <- "Description contains bare 'R' (use single quotes: 'R')"
    passed <- FALSE
  } else {
    issues <- character(0)
    passed <- TRUE
  }
  emit_issue_summary(
    issues, verbose,
    "Description quotes 'R' properly",
    "Description has bare R that should be single-quoted",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Description bare-R check")
}

# Double quotes in Description should only enclose publication titles.
# Heuristic: flag any pair of double quotes whose content is short (< 80 chars)
# and contains no title-case multi-word pattern (very common indicator of a
# colloquial phrase like "doctor" vs "A Theory of Everything: Foo Bar").
diagnose_description_quoted_quotes <- function(desc, verbose) {
  text <- desc[["Description"]]
  if (is.null(text) || !nzchar(text)) {
    return(checktor_check_result(TRUE, character(0),
                                 "Description double-quotes check"))
  }
  quoted <- regmatches(text, gregexpr("\"[^\"]*\"", text))[[1]]
  if (length(quoted) == 0L) {
    return(checktor_check_result(TRUE, character(0),
                                 "Description double-quotes check"))
  }
  issues <- character(0)
  for (q in quoted) {
    body <- gsub("^\"|\"$", "", q)
    # Publication titles tend to be multi-word; flag short non-title phrases.
    if (nchar(body) < 80L &&
        length(strsplit(body, "\\s+")[[1]]) <= 3L) {
      issues <- c(issues,
                  paste0("Suspicious double-quoted phrase: ", q,
                         " (double quotes are for publication titles)"))
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Description double-quote usage looks OK",
    "Description has double-quoted phrases that aren't publication titles",
    "Treatment: Remove double quotes; use single quotes for software names",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Description double-quotes check")
}

# Title should not start with "A ", "An ", or "The ".
diagnose_title_starts_with_article <- function(desc, verbose) {
  title <- desc[["Title"]]
  if (is.null(title) || !nzchar(title)) {
    return(checktor_check_result(TRUE, character(0),
                                 "Title starts-with-article check"))
  }
  if (grepl("^(A|An|The)\\s+", title, perl = TRUE)) {
    issues <- "Title starts with an article (A/An/The)"
    passed <- FALSE
  } else {
    issues <- character(0)
    passed <- TRUE
  }
  emit_issue_summary(
    issues, verbose,
    "Title does not start with an article",
    "Title starts with an article",
    "Treatment: Drop the leading 'A'/'An'/'The'",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Title starts-with-article check")
}

# Title should not include redundant phrases like "for R", "A Toolkit for",
# "Tools for". CRAN explicitly flags these.
diagnose_title_redundant_phrases <- function(desc, verbose) {
  title <- desc[["Title"]]
  if (is.null(title) || !nzchar(title)) {
    return(checktor_check_result(TRUE, character(0),
                                 "Title redundant-phrases check"))
  }
  patterns <- c(
    "\\bfor R\\b",
    "\\bA Toolkit for\\b",
    "\\bTools for\\b"
  )
  issues <- character(0)
  for (pat in patterns) {
    if (grepl(pat, title, perl = TRUE)) {
      issues <- c(issues,
                  paste0("Title contains redundant phrase: '",
                         gsub("\\\\b", "", pat), "'"))
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Title is free of redundant phrases",
    "Title contains redundant phrases that CRAN flags",
    "Treatment: Remove 'for R'/'A Toolkit for'/'Tools for'",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Title redundant-phrases check")
}

# Require at least one [cph] role in Authors@R.
diagnose_cph_role <- function(desc, verbose) {
  authors <- desc[["Authors@R"]]
  if (is.null(authors) || !nzchar(authors)) {
    return(checktor_check_result(FALSE,
                                 "Authors@R missing",
                                 "cph role check"))
  }
  has_cph <- grepl("\\bcph\\b", authors, perl = TRUE)
  issues <- if (has_cph) character(0) else "Authors@R lacks any [cph] (copyright holder) role"
  passed <- has_cph
  emit_issue_summary(
    issues, verbose,
    "{.code Authors@R} includes a {.code [cph]} role",
    "{.code Authors@R} has no {.code [cph]} (copyright holder)",
    "Treatment: Add role 'cph' to a person, e.g. role = c('aut','cre','cph')",
    level = "warning"
  )
  checktor_check_result(passed, issues, "cph role check")
}

# The LICENSE file (the package-specific copyright file referenced by
# "License: MIT + file LICENSE" etc.) should carry a current year. LICENSE.md
# is intentionally NOT checked: it's typically the verbatim license text,
# whose own copyright year (FSF 2007 for AGPL, etc.) refers to the license
# author rather than the package author.
diagnose_license_year <- function(path, verbose) {
  license_file <- file.path(path, "LICENSE")
  if (!file.exists(license_file)) {
    return(checktor_check_result(TRUE, character(0), "License year check"))
  }

  current_year <- as.integer(format(Sys.Date(), "%Y"))
  content <- safe_read_lines(license_file)
  if (length(content) == 0L) {
    return(checktor_check_result(TRUE, character(0), "License year check"))
  }
  years <- as.integer(unlist(regmatches(
    content, gregexpr("\\b(19|20)[0-9]{2}\\b", content, perl = TRUE)
  )))
  years <- years[!is.na(years) & years >= 1990L & years <= current_year + 1L]
  issues <- character(0)
  if (length(years) > 0L && max(years) < current_year) {
    issues <- paste0("LICENSE: latest year is ", max(years),
                     "; consider updating to ", current_year)
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "LICENSE year looks current",
    "LICENSE year is older than current year",
    "Treatment: Bump the YEAR / copyright statement",
    level = "warning"
  )
  checktor_check_result(passed, issues, "License year check")
}

`%||%` <- function(a, b) if (is.null(a)) b else a

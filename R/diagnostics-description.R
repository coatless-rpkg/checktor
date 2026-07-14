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
#' issues(results)     # description-field problems, if any
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
    title_length        = function(p, v) diagnose_title_length(desc, v),
    title_starts_with_article = function(p, v) diagnose_title_starts_with_article(desc, v),
    title_redundant_phrases   = function(p, v) diagnose_title_redundant_phrases(desc, v),
    description_function_quotes = function(p, v) diagnose_description_function_quotes(desc, v),
    authors             = function(p, v) diagnose_authors_field(desc, v),
    cph_role            = function(p, v) diagnose_cph_role(desc, v),
    references          = function(p, v) diagnose_references_formatting(desc, v),
    description_length  = function(p, v) diagnose_description_length(desc, v),
    description_bare_r        = function(p, v) diagnose_description_bare_r(desc, v),
    description_quoted_quotes = function(p, v) diagnose_description_quoted_quotes(desc, v)
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
  # "CMD" is here because it is not an acronym anyone expands, it is part of the
  # literal command name `R CMD check`, which turns up in any Description that
  # talks about the standard toolchain.
  common_abbrevs <- c("API", "SQL", "HTML", "CSS", "PDF", "XML", "JSON",
                      "URL", "HTTP", "HTTPS", "FTP", "GUI", "CLI", "CRAN",
                      "ID", "OS", "TLS", "SSL", "UTF", "ASCII", "CMD")
  candidates <- setdiff(unique(acronyms), common_abbrevs)

  # An acronym is not "unexplained" when the Description spells it out with the
  # conventional parenthetical gloss, in either order:
  #   "principal component analysis (PCA)"  or  "PCA (principal component ...)".
  # Whitespace is collapsed first so a line-wrapped gloss is still detected.
  # The `word (ACRONYM)` pattern is anchored to a preceding word char so a bare
  # "(PCA)" with no expansion in front of it is still flagged.
  flat <- gsub("\\s+", " ", text)
  explained <- vapply(candidates, function(a) {
    expansion_then_acronym <- grepl(paste0("\\w\\s*\\(", a, "\\)"), flat, perl = TRUE)
    acronym_then_expansion <- grepl(paste0("\\b", a, "\\b\\s*\\("), flat, perl = TRUE)
    expansion_then_acronym || acronym_then_expansion
  }, logical(1))
  unexplained <- candidates[!explained]

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

diagnose_authors_field <- function(desc, verbose) {
  # Two things are checked here, and only one of them overlaps with R.
  #
  # (a) A MISSING Authors@R. R CMD check does raise a CRAN-incoming NOTE for this,
  #     but it is only a NOTE. checktor treats it as a failure, which is the
  #     stricter and more useful signal before a submission, so it stays.
  #
  # (b) An unfilled usethis template, e.g.
  #       person("First", "Last", , "you@example.com", role = c("aut", "cre"))
  #     R CMD check says NOTHING about this: the field is present, so it passes.
  #     A CRAN reviewer then rejects it. This is a genuine gap, and it is the one
  #     that mattered in practice -- pcaR2 shipped exactly this and checktor's
  #     presence-only check waved it through.
  issues <- character(0)

  has_authors_r <- !is.null(desc[["Authors@R"]]) && nzchar(desc[["Authors@R"]])
  if (!has_authors_r) {
    issues <- c(issues, "Missing Authors@R field")
  }

  placeholders <- c(
    "First", "Last", "First Last", "Your Name", "YOUR NAME",
    "you@example.com", "your@email.com", "first.last@example.com"
  )
  # One issue per field, listing the placeholders found. The same template leaks
  # into Authors@R, Author and Maintainer at once, so reporting every (field,
  # placeholder) pair would turn a single mistake into eight findings.
  for (field in c("Authors@R", "Author", "Maintainer")) {
    text <- desc[[field]]
    if (is.null(text) || !nzchar(text)) next
    hit <- placeholders[vapply(placeholders, function(ph) {
      grepl(paste0("[\"']", ph, "[\"']"), text) ||
        grepl(paste0("\\b", gsub("([.@])", "\\\\\\1", ph), "\\b"), text, perl = TRUE)
    }, logical(1))]
    if (length(hit) > 0L) {
      issues <- c(issues, paste0(
        field, ": unfilled template placeholder (",
        paste(sprintf("\"%s\"", hit), collapse = ", "), ")"
      ))
    }
  }
  issues <- unique(issues)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "{.code Authors@R} present and filled in",
    "Problems in the author fields",
    "Treatment: Add Authors@R, and replace any usethis template placeholder with the real name and email"
  )
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
  # Writing R Extensions, verbatim: "double quotes should be used for quotations
  # (including titles of books and articles), and single quotes for non-English
  # usage, including names of other packages and external software."
  #
  # So the rule is about SOFTWARE NAMES in double quotes. The old test flagged any
  # double-quoted phrase of three words or fewer, which caught ordinary scare-
  # quoted jargon -- cbcTools ships "labeled", "no choice" and "alternative-
  # specific designs" on CRAN today. Those ARE the quotations double quotes are
  # reserved for. Only flag a double-quoted name we can actually recognise as
  # software.
  issues <- character(0)
  for (q in quoted) {
    body <- trimws(gsub("^\"|\"$", "", q))
    if (is_software_name(body)) {
      issues <- c(issues, paste0(
        "Software name in double quotes: ", q,
        " (Writing R Extensions reserves double quotes for quotations; ",
        "use single quotes for software and package names)"
      ))
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Description double-quote usage looks OK",
    "Description double-quotes a software name",
    "Treatment: Use single quotes for software and package names",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Description double-quotes check")
}

# Software and package names that Writing R Extensions requires to be in SINGLE
# quotes. Deliberately a closed list: guessing from shape would re-introduce the
# false positives on scare-quoted English that this check used to produce.
SOFTWARE_NAMES <- c(
  "R", "Python", "Java", "C", "C++", "Fortran", "JavaScript", "SQL", "HTML",
  "CSS", "XML", "JSON", "Excel", "Stata", "SAS", "SPSS", "MATLAB", "Julia",
  "Docker", "Git", "GitHub", "Quarto", "LaTeX", "Pandoc",
  "shiny", "ggplot2", "dplyr", "tidyr", "knitr", "rmarkdown", "Rcpp",
  "data.table", "Stan", "JAGS", "BUGS", "TensorFlow", "PyTorch", "Keras"
)

is_software_name <- function(x) {
  if (!nzchar(x)) return(FALSE)
  any(tolower(x) == tolower(SOFTWARE_NAMES))
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

# Title should stay under CRAN's ~65-character guideline.
diagnose_title_length <- function(desc, verbose) {
  title <- desc[["Title"]]
  if (is.null(title) || !nzchar(title)) {
    return(checktor_check_result(TRUE, character(0), "Title length check"))
  }
  flat <- trimws(gsub("\\s+", " ", title))
  n <- nchar(flat)
  issues <- if (n >= 65L) {
    paste0("Title is ", n, " characters; CRAN prefers under 65")
  } else {
    character(0)
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Title length is within the 65-character guideline",
    "Title exceeds the 65-character guideline",
    "Treatment: Shorten the Title to under 65 characters",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Title length check", nchar = n)
}

# Function names must NOT be single-quoted in Title/Description (single quotes
# are reserved for software/package/API names). Heuristic: flag a single-quoted
# token of the form `'name(...)'` - a quoted call is a clear function name.
diagnose_description_function_quotes <- function(desc, verbose) {
  # 'fn()', 'fn(x)', 'pkg::fn()' - identifier (optionally pkg::) then parens.
  pat <- "'\\s*[A-Za-z.][A-Za-z0-9._]*(?:::[A-Za-z0-9._]+)?\\s*\\([^')]*\\)\\s*'"
  issues <- character(0)
  for (field in c("Title", "Description")) {
    text <- desc[[field]]
    if (is.null(text) || !nzchar(text)) next
    hits <- regmatches(text, gregexpr(pat, text, perl = TRUE))[[1L]]
    for (h in unique(hits)) {
      issues <- c(issues, paste0(field, ": function name ", trimws(h),
                                 " should not be quoted"))
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No single-quoted function names in Title/Description",
    "Function names are single-quoted (reserve quotes for software names)",
    "Treatment: Drop the single quotes around function names like 'fn()'",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Description function-quotes check")
}

`%||%` <- function(a, b) if (is.null(a)) b else a

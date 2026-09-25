# Quoting checks for software, language and format names, and the acronyms
# check, on DESCRIPTION. The word lists they share are in R/vocabulary.R.

# ---- Quoted names: what counts as bare --------------------------------------

# The spans of a Title or Description that are not bare prose. The first three are
# the spans CRAN's incoming spell check skips, as tools:::.check_package_CRAN_incoming
# hands them to aspell: a single-quoted span, a function call written foo() or
# pkg::foo(), and the target of <https://...>, <doi:...> or <arXiv:...> markup.
# They depart from CRAN's patterns twice. An apostrophe before two digits that end
# the word, as in '90s or '21, elides a year and opens no quote, which would
# otherwise run to the next apostrophe and hide the words between; a quoted name
# that starts with a digit ('4ti2', '3+3/PC') is still quoted. And the package in
# a call may contain a dot (shiny.semantic::semanticPage()), where CRAN's takes
# only letters and digits.
#
# The last three are checktor's. CRAN's quote pattern wants a blank or
# punctuation after the closing quote, so a quoted name that takes a plural or
# possessive s ('data.table's, 'ggplot2's) fails it although the name is quoted.
# Double quotes enclose a quotation, such as the title of a book or article, and a
# name inside one is part of the quotation; a name alone in double quotes is
# lab_description_quoted_quotes()'s to report. And a name in a bare web address is
# part of the address, not a mention.
QUOTING_IGNORED_SPANS <- c(
  quoted = "(?<=[ \t[:punct:]])'(?![0-9]{2}s?(?![[:alnum:]]))[^']*'(?=[ \t[:punct:]])",
  call = "(?<=[ \t[:punct:]])([[:alnum:].]+::)?[[:alnum:]_.]*\\(\\)(?=[ \t[:punct:]])",
  markup = "(?<=[<])(https?://|DOI:|doi:|arXiv:)[^>]+(?=[>])",
  quoted_s = "(?<=[ \t[:punct:]])'(?![0-9]{2}s?(?![[:alnum:]]))[^']*'(?=s(?![[:alnum:]]))",
  double_quoted = "(?<=[ \t[:punct:]])\"[^\"]*\"(?=[ \t[:punct:]])",
  url = "(https?|ftp)://[^[:space:]<>]+"
)

# A field with every span above blanked to spaces, leaving the prose a
# reader sees unquoted. The quoting checks search this, so a term inside a quoted
# longer name ('R Markdown', 'JSON-stat', 'shiny.semantic') is not bare, and each
# remaining occurrence is judged on its own. Blanking rather than deleting keeps
# the words either side of a span apart, as aspell does.
#
# CRAN's patterns need a blank or punctuation either side of a quote. aspell gets
# one by blanking the "Field:" tag and appending a blank to every line, so the
# field is padded here. read.dcf() also joins a continuation line with a newline,
# which the patterns do not count, so every run of whitespace becomes one blank
# first; otherwise a quote that opens a continuation line would not be a quote.
# A missing or empty field has no prose, and comes back empty rather than padded,
# so an NA is never read as the word "NA".
blank_ignored_spans <- function(text) {
  empty <- is.na(text) | !nzchar(text)
  text <- paste0(" ", gsub("[[:space:]]+", " ", text), " ", recycle0 = TRUE)
  for (re in QUOTING_IGNORED_SPANS) {
    hits <- gregexpr(re, text, perl = TRUE)
    regmatches(text, hits) <- lapply(
      regmatches(text, hits),
      function(s) strrep(" ", nchar(s))
    )
  }
  text[empty] <- ""
  text
}

# Whether `name` still occurs in text returned by blank_ignored_spans(). A name
# can carry regex metacharacters (C++, C#, data.table), so it is escaped, and it
# must not match inside a larger token: Java in JavaScript, SQL in PostgreSQL. A
# dot joins a token when a word character sits on its other side, so the shiny in
# shiny.semantic is part of another package's name, while a full stop ending the
# sentence still ends the name.
has_bare_name <- function(blanked, name) {
  pattern <- paste0(
    "(?<![\\w+#])(?<!\\w\\.)",
    escape_regex(name),
    "(?![\\w+#]|\\.\\w)"
  )
  grepl(pattern, blanked, perl = TRUE)
}

# The quoting checks' shared loop: one finding per field and name that still
# occurs bare once the ignored spans are blanked, in vocabulary order. Searching
# the blanked text judges each occurrence on its own. Asking whether a literal
# 'shiny' appeared anywhere let one quoted mention excuse every bare one, and
# still reported the shiny inside a correctly quoted 'shiny.semantic'.
bare_name_issues <- function(desc, names, finding) {
  issues <- character(0)
  for (field in c("Title", "Description")) {
    text <- dcf_field(desc, field)
    if (is.null(text) || is.na(text) || !nzchar(text)) {
      next
    }
    unquoted <- blank_ignored_spans(text)
    for (name in names) {
      if (has_bare_name(unquoted, name)) {
        issues <- c(issues, paste0(field, ": ", name, " ", finding))
      }
    }
  }
  issues
}

#' Diagnose Unquoted Software Names in DESCRIPTION
#'
#' Flags a package or external-software name in `Title`/`Description` that is not in single quotes, as Writing R Extensions requires.
#'
#' Each occurrence is judged on its own, so one quoted mention does not excuse a
#' bare one elsewhere. A name is not bare inside a single-quoted span such as
#' `'shiny.semantic'`, a `<https://...>` or `<doi:...>`, or a function call such
#' as `purrr::map()`, which are the spans CRAN's own incoming spell check skips.
#' Nor is it bare in a plain web address, or in a double-quoted quotation such as
#' the title of a book. A name alone in double quotes, in either field, is
#' reported by [lab_description_quoted_quotes()] instead.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", asks you to "Refer to other packages and
#' external software in single quotes". See
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
#' pkg <- example_diagnose_scenario("description_examples/software_names_bad.txt",
#'                                  show_content = FALSE)
#' lab_software_names(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_software_names <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  # R PACKAGE and software-PRODUCT names only. Writing R Extensions asks for "other
  # packages and external software" in single quotes, and CRAN enforces it for
  # package names, so an unquoted `ggplot2` or `shiny` is flagged here at policy.
  #
  # PROGRAMMING LANGUAGES (Python, Java) live in their own policy check,
  # `lab_language_names()` -- a language name and a package name are different
  # kinds of thing, so they read as separate concerns -- and format and markup
  # names (JSON, HTML, SQL) in `lab_format_names()`, which runs on request. ("R"
  # itself is never flagged anywhere, in either form: no authority names it, and
  # both a bare R and a quoted 'R' clear CRAN, so neither is worth nagging about.)
  #
  # `WebAssembly` stays here rather than with the languages: it is a specific format
  # (a W3C standard, not a language you write a package "in"), consistently quoted
  # in the R WebAssembly ecosystem, and CRAN asks for it. Its abbreviation `WASM`
  # and the products `webR`/`Shinylive` are recognised when quoted but not demanded,
  # since bare abbreviations in parentheses are conventional. A package can add its
  # own names via `Config/checktor/software_names`.
  software_names <- check_vocab(
    checktor_config(path),
    "software_names",
    VOCABULARY$software_names
  )
  issues <- bare_name_issues(desc, software_names, "should be in single quotes")

  passed <- length(issues) == 0
  emit_issue_summary(
    issues,
    verbose,
    "Software names appear properly formatted",
    "Potential software name formatting issues",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Software names check")
}

#' Diagnose Programming-Language Names in DESCRIPTION
#'
#' Flags a bare programming-language or statistical-computing name -- `Python`,
#' `Java`, `JavaScript`, `Rust`, `MATLAB`, `SAS`, `Stata` and more -- in `Title`
#' or `Description` that CRAN asks to see single-quoted. This is the language
#' counterpart to [lab_software_names()]: both are policy-tier
#' quoting checks, kept separate because a language name and a package name are
#' different kinds of thing. `R` itself is never flagged in either form. No
#' authority names it, and a bare `R` and a quoted `'R'` both clear CRAN, so
#' checktor takes no position on which you write. Single-letter or common-word
#' names (`C`, `Go`, `Swift`) are left out because they cannot be told from
#' ordinary prose.
#'
#' Data, markup and query formats (`JSON`, `HTML`, `YAML`, `SQL`, `Markdown`,
#' `LaTeX` and the like) and the languages CRAN packages write either way (`C++`,
#' `Fortran`, `Tcl`) are not flagged here. A census of CRAN in September 2026
#' found that packages accepted at new-package review in the previous 18 months
#' wrote them bare 62% of the time, against 28% for the languages this check
#' covers, so a bare one is not a policy finding. [lab_format_names()] reports them when you
#' ask.
#'
#' A package can extend the list through `Config/checktor/language_names` in its own
#' DESCRIPTION.
#'
#' Each occurrence is judged on its own, as in [lab_software_names()]: a term
#' inside a quoted longer name such as `'MATLAB Runtime'` or `'AWS Python SDK'` is
#' quoted, and so is one in a web address, a `<doi:...>` or a double-quoted book
#' title.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", asks for single quotes around other software;
#' checktor applies the same to programming-language and markup names. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_software_names()], [lab_format_names()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/language_names_bad.txt",
#'                                  show_content = FALSE)
#' lab_language_names(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_language_names <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  language_names <- check_vocab(
    checktor_config(path),
    "language_names",
    VOCABULARY$language_names
  )
  # Single-letter names (C, D) and common English words (Go, Swift) are left out:
  # at policy severity their false positives would outweigh the catch. A package
  # that wants them can add them via Config/checktor/language_names.
  #
  # Formats and the languages CRAN writes both ways (JSON, HTML, SQL, C++, Tcl, ...)
  # live in lab_format_names(), on request: most accepted packages write them
  # bare, so a bare one here would fail a clean package for nothing CRAN enforces.
  #
  # The same matcher as software_names: a term inside a quoted longer name
  # ('AWS Python SDK', 'MATLAB Runtime') is quoted, and one quoted 'Python' no
  # longer excuses a bare Python elsewhere in the field.
  issues <- bare_name_issues(desc, language_names, "should be in single quotes")

  passed <- length(issues) == 0
  emit_issue_summary(
    issues,
    verbose,
    "Programming-language names appear properly formatted",
    "Potential programming-language name formatting issues",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Language names check")
}

#' Diagnose Bare Format and Markup Names in DESCRIPTION
#'
#' Flags a data, markup, typesetting or query format name -- `JSON`, `HTML`,
#' `XML`, `CSS`, `YAML`, `TOML`, `Markdown`, `LaTeX`, `TeX` or `SQL` -- or one of
#' the languages CRAN packages write either way (`C++`, `Fortran`, `Tcl`) that
#' appears in `Title` or `Description` without single quotes. It runs only when
#' you call it, for a maintainer who wants the quoting consistent. CRAN accepts
#' these names bare, so a finding here never counts against a clean result.
#'
#' Occurrences are judged as in [lab_software_names()]: a name inside a quoted
#' longer name such as `'R Markdown'` or `'JSON-stat'` is quoted, and so is one in
#' a web address or a double-quoted span. A format name alone in double quotes,
#' such as `"JSON"`, is therefore reported by no check, by design: double quotes
#' are the wrong kind for a name, but CRAN accepts the name with no quotes at all,
#' so [lab_description_quoted_quotes()] leaves it alone too. A package can extend
#' the list through `Config/checktor/format_names` in its own DESCRIPTION.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file)
#' asks for single quotes around "other packages and external software", and a
#' format is not software. A census of CRAN in September 2026 found that packages
#' accepted at new-package review in the previous 18 months wrote these names bare
#' 62% of the time, against 28% for the languages [lab_language_names()] covers, so
#' this is a matter of style and sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_language_names()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/format_names_bad.txt",
#'                                  show_content = FALSE)
#' lab_format_names(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_format_names <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  # Split out of language_names (#16). These are formats and specifications rather
  # than software, or languages whose names CRAN packages write quoted and bare
  # about equally, and a census of recently accepted packages found most of them
  # bare. C, Go and the other names that read as ordinary words stay out here too.
  format_names <- check_vocab(
    checktor_config(path),
    "format_names",
    VOCABULARY$format_names
  )
  issues <- bare_name_issues(desc, format_names, "is not in single quotes")

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Format and markup names are single-quoted",
    "Format and markup names written without single quotes",
    "Treatment: Optional. CRAN accepts these names bare; quote them only to keep the quoting consistent throughout the Title and Description",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Format names check")
}

#' Diagnose Unexplained Acronyms in DESCRIPTION
#'
#' Flags an acronym in `Description` that is never spelled out. A parenthetical gloss in either order counts as explained.
#'
#' A name in single quotes, straight or typographic, is not read as an acronym,
#' so `'YAML'` or `'MATLAB'` written as [lab_language_names()] and
#' [lab_format_names()] ask is not reported here. Nor is anything inside a web
#' address, a `<doi:...>`, a function call or a quotation in double quotes,
#' straight or typographic, such as the title of an article.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Explaining Acronyms](https://contributor.r-project.org/cran-cookbook/description_issues.html#explaining-acronyms).
#' Reviewers ask for an acronym to be spelled out once, but nothing enforces it,
#' which is why this sits at `opinion` tier. See
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
#' pkg <- example_diagnose_scenario("description_examples/acronyms_bad.txt",
#'                                  show_content = FALSE)
#' lab_acronyms(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_acronyms <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  text <- desc[["Description"]]
  if (is.null(text) || is.na(text) || !nzchar(text)) {
    return(checktor_check_result(TRUE, character(0), "Acronyms check"))
  }

  # Candidates come from the prose a reader sees unquoted, with the same spans
  # blanked that the quoting checks skip: single-quoted names, web addresses,
  # DOIs and function calls. language_names and format_names ask for 'MATLAB' and
  # 'YAML' in single quotes, so reading a quoted name as an unexplained acronym
  # had checktor contradict itself whichever way the user wrote it.
  #
  # Typographic quotes (U+2018/U+2019 and U+201C/U+201D) are skipped too, here
  # only. The quoting checks keep to CRAN's ASCII pattern, but an acronym in curly
  # quotes has been quoted as surely as 'GLMM' or "GLMM", and the gloss detection
  # below already reads a curly closing quote. A curly quote follows the rules of
  # the straight one: it opens after a blank or punctuation and not at an elided
  # year (\u201890s), and it closes where a quote ends the word or, for a single
  # quote, takes a plural or possessive s, so the apostrophe in package\u2019s
  # closes nothing. Word processors may curl one side only, so a straight quote
  # can close a curly one (\u2018CFO').
  typographic <- c(
    single = paste0(
      "(?<=[ \t[:punct:]])\u2018(?![0-9]{2}s?(?![[:alnum:]]))",
      "[^\u2018\u2019]*?['\u2019](?=[ \t[:punct:]]|s(?![[:alnum:]]))"
    ),
    double = "(?<=[ \t[:punct:]])\u201c[^\u201c\u201d]*?[\"\u201d](?=[ \t[:punct:]])"
  )
  prose <- blank_ignored_spans(text)
  for (re in typographic) {
    prose <- gsub(re, " ", prose, perl = TRUE)
  }
  acronyms <- regmatches(prose, gregexpr("\\b[A-Z]{2,6}\\b", prose))[[1]]
  # Known abbreviations, including the format names CRAN accepts bare; see
  # R/vocabulary.R.
  common_abbrevs <- check_vocab(
    checktor_config(path),
    "acronyms",
    VOCABULARY$acronyms
  )
  candidates <- setdiff(unique(acronyms), common_abbrevs)

  # An acronym is not "unexplained" when the Description spells it out with the
  # conventional parenthetical gloss, in either order:
  #   "principal component analysis (PCA)"  or  "PCA (principal component ...)".
  # Whitespace is collapsed first so a line-wrapped gloss is still detected.
  # The `word (ACRONYM)` pattern is anchored to a preceding word char so a bare
  # "(PCA)" with no expansion in front of it is still flagged. A closing quote may
  # sit between the two, because the expansion is often a software name and
  # `software_names` requires those to be quoted -- "'WebAssembly' (WASM)" is a
  # gloss, and reading it as an unexplained acronym would have checktor contradict
  # its own policy check.
  flat <- gsub("\\s+", " ", text)
  explained <- vapply(
    candidates,
    function(a) {
      expansion_then_acronym <- grepl(
        paste0("\\w['\u2019\"]?\\s*\\(", a, "\\)"),
        flat,
        perl = TRUE
      )
      acronym_then_expansion <- grepl(
        paste0("\\b", a, "\\b\\s*\\("),
        flat,
        perl = TRUE
      )
      expansion_then_acronym || acronym_then_expansion
    },
    logical(1)
  )
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

# Double quotes in the Title and Description should only enclose quotations.
#' Diagnose Double-Quoted Software Names
#'
#' Flags a software name in double quotes in `Title` or `Description`. Writing R Extensions reserves double quotes for quotations and requires single quotes for software names, so scare-quoted jargon is left alone. A lower-case span matches only a name written in lower case, such as `shiny`, so an English `"rust"` or a parameter `"r"` is not read as `Rust` or `R`.
#'
#' The names are those [lab_software_names()] and [lab_language_names()] ask to
#' see in single quotes, and a few more. Format names such as `JSON` or `HTML`,
#' which CRAN accepts bare, are not among them, so one in double quotes is not
#' reported; [lab_format_names()] reports them bare, on request.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", reserves double quotes for book
#' titles and similar; software names take single quotes. See
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
#' pkg <- example_diagnose_scenario("description_examples/description_quoted_quotes_bad.txt",
#'                                  show_content = FALSE)
#' lab_description_quoted_quotes(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_description_quoted_quotes <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  # Both fields. lab_software_names() and lab_language_names() read a
  # double-quoted span in either as a quotation, so a name alone in double quotes
  # in the Title is reported here or nowhere.
  quoted <- list()
  for (field in c("Title", "Description")) {
    text <- desc[[field]]
    if (is.null(text) || is.na(text) || !nzchar(text)) {
      next
    }
    quoted[[field]] <- regmatches(text, gregexpr("\"[^\"]*\"", text))[[1]]
  }
  if (length(unlist(quoted)) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Description double-quotes check"
    ))
  }
  # Writing R Extensions, verbatim: "double quotes should be used for quotations
  # (including titles of books and articles), and single quotes for non-English
  # usage, including names of other packages and external software."
  #
  # So the rule is about SOFTWARE NAMES in double quotes. The old test flagged any
  # double-quoted phrase of three words or fewer, which caught ordinary scare-
  # quoted jargon such as the "labeled", "no choice" and "alternative-specific
  # designs" that appear on CRAN today. Those ARE the quotations double quotes are
  # reserved for. Only flag a double-quoted name we can actually recognise as
  # software.
  # The names a package adds to either quoting check count too, since those checks
  # leave a name alone in double quotes to this one.
  config <- checktor_config(path)
  extra_names <- c(config$software_names, config$language_names)
  issues <- character(0)
  for (field in names(quoted)) {
    for (q in quoted[[field]]) {
      body <- trimws(gsub("^\"|\"$", "", q))
      if (is_software_name(body, extra_names)) {
        issues <- c(
          issues,
          paste0(
            field,
            ": ",
            q,
            " is a software name in double quotes (Writing R Extensions ",
            "reserves double quotes for quotations; use single quotes for ",
            "software and package names)"
          )
        )
      }
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Title and Description double-quote usage looks OK",
    "Title or Description double-quotes a software name",
    "Treatment: Use single quotes for software and package names",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Description double-quotes check")
}

# Case is ignored, so "Matlab" is MATLAB and "Shiny" is shiny, except in one
# direction: a name is a proper noun, and a span in lower case is an ordinary word
# or a symbol unless the name itself is written in lower case. An English "rust",
# BFF's hyperparameter "r" and R2WinBUGS's class "bugs" are not Rust, R and BUGS,
# and at policy tier reading them as such was a false finding.
is_software_name <- function(x, extra = character(0)) {
  if (!nzchar(x)) {
    return(FALSE)
  }
  names <- c(SOFTWARE_NAMES, extra)
  if (identical(x, tolower(x))) {
    names <- names[names == tolower(names)]
  }
  any(tolower(x) == tolower(names))
}

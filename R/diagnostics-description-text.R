# Checks on the Description prose: its length and opening, how it quotes
# function names, and its spelling.

#' Diagnose Description Length
#'
#' Flags a `Description` of fewer than 10 words.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Description Length](https://contributor.r-project.org/cran-cookbook/general_issues.html#description-length).
#' A one-line `Description` is thin and reviewers ask for more, a convention rather
#' than a rule, which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/description_length_bad.txt",
#'                                  show_content = FALSE)
#' lab_description_length(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_description_length <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  text <- desc_value(desc, "Description")
  if (is.null(text)) {
    if (verbose) {
      cli::cli_alert_warning("No Description field found")
    }
    # Fails with nothing to list, so it builds the result itself.
    return(checktor_check_result(
      FALSE,
      character(0),
      check_label("description_length")
    ))
  }

  # read.dcf returns multi-line fields with embedded newlines; treat \n as space
  flat <- gsub("\\s+", " ", text)
  sentences <- length(strsplit(flat, "[.!?]+\\s+|[.!?]+$")[[1]])
  word_count <- length(strsplit(trimws(flat), "\\s+")[[1]])

  # Word count only. The old rule also demanded 2+ SENTENCES, which no authority
  # supports and which flagged renderthis for a perfectly complete 31-word
  # single-sentence Description. What is genuinely thin is a Description that
  # says almost nothing ("Does stuff."), and words measure that; punctuation
  # does not.
  passed <- word_count >= 10
  issues <- if (passed) {
    character(0)
  } else {
    paste0(
      "Description too short: ",
      word_count,
      " words"
    )
  }

  if (verbose) {
    if (passed) {
      cli::cli_alert_success("Description length appears adequate")
    } else {
      cli::cli_alert_warning(
        "Description may be too short: {.val {word_count}} words"
      )
      cli::cli_text(paste0(
        "{.emph Treatment: ", treatments$description_length$treatment, "}"
      ))
    }
  }
  checktor_check_result(
    passed,
    issues,
    check_label("description_length"),
    sentences = sentences,
    words = word_count
  )
}

# Function names must NOT be single-quoted in Title/Description (single quotes
# are reserved for software/package/API names). Heuristic: flag a single-quoted
# token of the form `'name(...)'` - a quoted call is a clear function name.
#' Diagnose Single-Quoted Function Names
#'
#' Flags a single-quoted function name in `Title`/`Description`. Single quotes are reserved for software names.
#'
#' @section Source:
#' No rule. This was an invented rule and is kept callable but off by
#' default. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/description_function_quotes_bad.txt",
#'                                  show_content = FALSE)
#' lab_description_function_quotes(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_description_function_quotes <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  # 'fn()', 'fn(x)', 'pkg::fn()' - identifier (optionally pkg::) then parens.
  pat <- "'\\s*[A-Za-z.][A-Za-z0-9._]*(?:::[A-Za-z0-9._]+)?\\s*\\([^')]*\\)\\s*'"
  issues <- character(0)
  for (field in c("Title", "Description")) {
    text <- desc_value(desc, field)
    if (is.null(text)) {
      next
    }
    hits <- regmatches(text, gregexpr(pat, text, perl = TRUE))[[1L]]
    for (h in unique(hits)) {
      issues <- c(
        issues,
        paste0(field, ": function name ", trimws(h), " should not be quoted")
      )
    }
  }
  report_check(
    issues,
    verbose,
    check_label("description_function_quotes"),
    "No single-quoted function names in Title/Description",
    "Function names are single-quoted (reserve quotes for software names)",
    treatment = paste(
      "Treatment:",
      treatments$description_function_quotes$treatment
    ),
    level = "warning"
  )
}

# What the Description must not start with. R's own CRAN-incoming check uses a
# broader pattern than we did, and additionally requires an initial capital, which
# we lacked entirely. Match it.
#' Diagnose the Description Opening
#'
#' Flags a `Description` opening with a phrase CRAN forbids ("This package..."), or one that does not begin with a capital letter.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says "It is good practice not to
#' start with the package name, 'This package' or similar"; the
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' flags it. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/description_starts_with_bad.txt",
#'                                  show_content = FALSE)
#' lab_description_starts_with(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_description_starts_with <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  text <- desc_value(desc, "Description")
  pkg <- desc_value(desc, "Package")
  if (is.null(text)) {
    return(pass_result(check_label("description_starts_with")))
  }
  flat <- trimws(gsub("\\s+", " ", text))

  issues <- character(0)
  if (
    grepl(
      "^(The|This|A|An|In this|In the)\\s+package\\b",
      flat,
      ignore.case = TRUE
    )
  ) {
    issues <- c(
      issues,
      paste0(
        "Description should not start with \"",
        sub("\\s.*", "", flat),
        " package\"; describe what it does instead"
      )
    )
  }
  if (!is.null(pkg) && grepl(paste0("^['\"]?", pkg, "\\b"), flat)) {
    issues <- c(issues, "Description should not start with the package name")
  }
  # R's descr_bad_initial rule: the Description must begin with a capital letter.
  if (grepl("^[a-z]", flat)) {
    issues <- c(issues, "Description should start with a capital letter")
  }

  report_check(
    issues,
    verbose,
    check_label("description_starts_with"),
    "Description opening looks fine",
    "Description opening needs work",
    treatment = paste(
      "Treatment:",
      treatments$description_starts_with$treatment
    ),
    level = "warning"
  )
}

#' Diagnose Possibly Misspelled Words in DESCRIPTION
#'
#' Spell-checks the `Title` and `Description` fields with [utils::aspell()],
#' mirroring the aspell pass in CRAN's incoming check. It reports only words that
#' are not already accepted somewhere: a package `.aspell/` dictionary,
#' `inst/WORDLIST`, or a `Config/checktor/acronyms`, `software_names`,
#' `language_names` or `format_names` field.
#'
#' @details
#' The check needs a spell-check backend (`aspell` or `hunspell`) on the system.
#' Without one it is reported as skipped, the same way CRAN's incoming check
#' skips spelling when no backend is present, so a run on one machine may find
#' words a run on another does not. It is therefore an `opinion`-tier check.
#' When it does fire, [prescribe()] hands back a ready-to-paste `.aspell/`
#' snippet with the flagged words filled in.
#'
#' @section Source:
#' The [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' runs `aspell` over the `Title` and `Description`; it needs a
#' spell-check backend and is noisy, so checktor keeps it at
#' `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_description_fields
#' @param desc Present for signature parity with the other DESCRIPTION checks;
#'   spelling reads the `DESCRIPTION` file directly and ignores it.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`; the
#'   `issues` are the possibly-misspelled words.
#' @seealso [checktor()], [prescribe()].
#' @export
#' @examples
#' # Needs aspell or hunspell; without one the check is skipped and finds nothing
#' pkg <- example_diagnose_scenario("description_examples/spelling_bad.txt",
#'                                  show_content = FALSE)
#' lab_spelling(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_spelling <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc_file <- file.path(path, "DESCRIPTION")
  # Backend-dependent, so its result can differ between machines. Users who want
  # a fully deterministic run (and the test suite) turn it off with
  # options(checktor.spelling = FALSE); it stays on by default.
  if (!isTRUE(getOption("checktor.spelling", TRUE))) {
    return(checktor_skipped_result(
      check_label("spelling"),
      "turned off with options(checktor.spelling = FALSE)"
    ))
  }
  program <- Sys.which("aspell")
  if (!nzchar(program)) {
    program <- Sys.which("hunspell")
  }
  # No backend or no DESCRIPTION: nothing was examined, so say so rather than
  # reporting a pass, exactly as CRAN's incoming check skips spelling without one.
  if (!nzchar(program)) {
    return(checktor_skipped_result(
      check_label("spelling"),
      "no aspell or hunspell backend installed"
    ))
  }
  if (!file.exists(desc_file)) {
    return(pass_result(check_label("spelling")))
  }

  # CRAN's incoming check leaves single-quoted names ('ggplot2'), function calls
  # (fn(), pkg::fn()) and <doi:...>/<https://...> targets out of the spell check,
  # and adds British spellings and R's en_stats word list. Without the same
  # ignores, 'ggplot2' came back as a misspelled "ggplot".
  filter <- list("dcf", ignore = SPELLING_IGNORE)
  flagged <- NULL
  if (identical(basename(program), "aspell")) {
    flagged <- tryCatch(
      utils::aspell(
        desc_file,
        filter = filter,
        control = c("--master=en_US", "--add-extra-dicts=en_GB"),
        program = program,
        dictionaries = "en_stats"
      ),
      error = function(e) NULL
    )
  }
  # hunspell, or an aspell without the en_US/en_GB dictionaries: the backend's
  # default dictionary, still with CRAN's ignores.
  if (is.null(flagged)) {
    flagged <- tryCatch(
      utils::aspell(desc_file, filter = filter, program = program),
      error = function(e) NULL
    )
  }
  if (is.null(flagged)) {
    return(checktor_skipped_result(
      check_label("spelling"),
      paste0("the ", basename(program), " backend failed to run")
    ))
  }
  words <- if (nrow(flagged) == 0L) {
    character(0)
  } else {
    unique(as.character(flagged$Original))
  }
  issues <- sort(setdiff(words, spelling_accepted_words(path)))

  report_check(
    issues,
    verbose,
    check_label("spelling"),
    "No possibly-misspelled words in {.file DESCRIPTION}",
    "Possibly misspelled words in {.file DESCRIPTION}",
    treatment = paste("Treatment:", treatments$spelling$treatment),
    level = "warning"
  )
}

# The text CRAN's incoming check keeps out of its DESCRIPTION spell check, as in
# tools:::.check_package_CRAN_incoming(): single-quoted spans, function calls,
# and the targets of <doi:>, <arXiv:> and <https://> links.
SPELLING_IGNORE <- list(
  c(
    "(?<=[ \t[:punct:]])'[^']*'(?=[ \t[:punct:]])",
    "(?<=[ \t[:punct:]])([[:alnum:]]+::)?[[:alnum:]_.]*\\(\\)(?=[ \t[:punct:]])",
    "(?<=[<])(https?://|DOI:|doi:|arXiv:)[^>]+(?=[>])"
  ),
  perl = TRUE
)

# Words a package has already declared acceptable, gathered from every mechanism
# a maintainer might use: an aspell `.aspell/*.rds` dictionary, the spelling
# package's `inst/WORDLIST`, and every one of checktor's own `Config/checktor`
# vocabularies. Subtracting these keeps lab_spelling silenceable no matter which
# one the package reaches for.
spelling_accepted_words <- function(path) {
  words <- character(0)

  aspell_dir <- file.path(path, ".aspell")
  if (dir.exists(aspell_dir)) {
    for (f in list.files(aspell_dir, pattern = "\\.rds$", full.names = TRUE)) {
      w <- tryCatch(readRDS(f), error = function(e) NULL)
      if (is.character(w)) {
        words <- c(words, w)
      }
    }
  }

  wordlist <- file.path(path, "inst", "WORDLIST")
  if (file.exists(wordlist)) {
    words <- c(words, safe_read_lines(wordlist))
  }

  cfg <- checktor_config(path)
  words <- c(
    words,
    cfg$acronyms,
    cfg$software_names,
    cfg$language_names,
    cfg$format_names
  )

  unique(words[nzchar(words)])
}

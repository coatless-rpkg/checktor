#' Diagnose Documentation Issues
#'
#' Runs diagnostics on package documentation to identify common issues that
#' can cause CRAN submission problems or a poor user experience.
#'
#' @details
#' This function checks for:
#' - Missing `\value` tags in function documentation
#' - Exported functions missing an `\examples` section
#' - Roxygen2 usage
#' - Example structure (appropriate use of `\dontrun{}`)
#' - Examples that use Suggested packages without a guard
#'
#' `.Rd` files are parsed structurally via [tools::parse_Rd()] so analyses
#' look at sections by their `Rd_tag` rather than grepping LaTeX text.
#'
#' @param path Character. Path to package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return
#' List of [checktor_check_result()] objects plus a `passed` named logical
#' vector summarizing pass/fail per check.
#'
#' @seealso [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("documentation_examples/missing_value_tag.Rd",
#'                                       show_content = FALSE)
#' doc_results <- diagnose_documentation_issues(pkg_path, verbose = FALSE)
#' summary(doc_results)
#' issues(doc_results)
diagnose_documentation_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("Documentation Health Check")
  }
  run_checks(
    c(
      list(
        value_tags = diagnose_value_tags,
        missing_examples = diagnose_missing_examples,
        roxygen_usage = diagnose_roxygen_usage,
        example_structure = diagnose_example_structure,
        commented_examples = diagnose_commented_examples,
        donttest_vs_dontrun = diagnose_donttest_vs_dontrun,
        unexported_example_ns = diagnose_unexported_example_namespace,
        suggested_in_examples = diagnose_suggested_in_examples
      ),
      registered_checks_for("documentation")
    ),
    path,
    verbose
  )
}

# Heuristics for "Rd files we should NOT require to have \value{}".
# Data, class, methods, and package-level topics, plus re-export pages.
is_non_function_rd_obj <- function(rd) {
  doctype <- extract_rd_section(rd, "\\docType")
  if (!is.null(doctype)) {
    dt <- trimws(collect_rd_text(doctype))
    if (dt %in% c("data", "class", "package", "methods")) return(TRUE)
  }
  # Package-level: any \alias ending in -package.
  for (sec in rd) {
    if (identical(attr(sec, "Rd_tag"), "\\alias")) {
      if (grepl("-package$", trimws(collect_rd_text(sec)))) return(TRUE)
    }
  }
  # Re-export pages
  for (sec in rd) {
    if (identical(attr(sec, "Rd_tag"), "\\name")) {
      nm <- trimws(collect_rd_text(sec))
      if (nm == "reexports") return(TRUE)
    }
  }
  FALSE
}

#' Diagnose Missing Value Tags in Documentation
#'
#' Walks `.Rd` files via [tools::parse_Rd()] and reports topics that are
#' missing a `\value{}` section. Data, class, methods, package-level, and
#' re-export topics are skipped (they don't need `\value{}`).
#'
#' @param path Character. Path to package directory
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Documenting-functions),
#' under "Documenting functions", describes `\value{}`, and the CRAN Cookbook keeps
#' the recipe reviewers cite under
#' [Missing value-tags in .Rd-files](https://contributor.r-project.org/cran-cookbook/docs_issues.html#missing-value-tags-in-.rd-files),
#' but `R CMD check` does not require it, so checktor keeps this at `opinion` tier.
#' See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `missing`,
#'   `message`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("documentation_examples/missing_value_tag.Rd",
#'                                       show_content = FALSE)
#' issues(diagnose_value_tags(pkg_path, verbose = FALSE))
diagnose_value_tags <- function(path, verbose = TRUE) {
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
  if (length(rd_files) == 0L) {
    if (verbose) {
      cli::cli_alert_info("No .Rd files found")
    }
    return(checktor_check_result(TRUE, character(0), "Value tags check"))
  }

  # Walk each .Rd with tools::parse_Rd() rather than tools::checkRdContents(),
  # whose `missing_value` output postdates checktor's R floor: a diagnostic must
  # not change its verdict with the R version running it. A topic needs a \value
  # only if it documents a function, meaning it has a \usage or \arguments
  # section and is not a data, class or package topic, nor a \keyword{internal}
  # or graphics topic. R CMD check does NOT surface missing \value as a NOTE, so
  # this stays an extra-CRAN check.
  skip_keywords <- c("internal", "aplot", "hplot", "device", "dynamic")
  rd_tags <- function(rd) {
    vapply(
      rd,
      function(x) {
        tag <- attr(x, "Rd_tag")
        if (is.null(tag)) "" else tag
      },
      character(1)
    )
  }
  needs_value <- function(rd_file) {
    rd <- tryCatch(tools::parse_Rd(rd_file), error = function(e) NULL)
    if (is.null(rd)) {
      return(FALSE)
    }
    tags <- rd_tags(rd)
    doctype <- tolower(trimws(
      collect_rd_text(extract_rd_section(rd, "\\docType"))
    ))
    if (doctype %in% c("data", "class", "package")) {
      return(FALSE)
    }
    keywords <- tolower(trimws(vapply(
      rd[tags == "\\keyword"],
      function(k) collect_rd_text(k),
      character(1)
    )))
    if (any(keywords %in% skip_keywords)) {
      return(FALSE)
    }
    documents_function <- any(tags %in% c("\\usage", "\\arguments"))
    documents_function && !("\\value" %in% tags)
  }

  hit <- vapply(rd_files, needs_value, logical(1))
  missing_value <- sort(basename(rd_files[hit]))

  passed <- length(missing_value) == 0L
  emit_issue_summary(
    missing_value,
    verbose,
    "All function documentation has {.code \\value} tags",
    "Missing {.code \\value} tags"
  )
  checktor_check_result(
    passed,
    missing_value,
    "Value tags check",
    missing = missing_value
  )
}

#' Diagnose Example Structure
#'
#' Walks `\examples{}` sections via [tools::parse_Rd()] and flags
#' `\dontrun{}` subtrees that don't appear to have a justifying reason
#' (interactive, network, credentials, long-running, etc.).
#'
#' @inheritParams diagnose_value_tags
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples).
#' `\dontrun{}` should wrap only code that genuinely cannot run inside a check, a
#' convention rather than a rule, which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @examples
#' pkg_path <- example_diagnose_scenario("network_examples/bad_network_example.Rd",
#'                                       show_content = FALSE)
#' diagnose_example_structure(pkg_path, verbose = FALSE)
diagnose_example_structure <- function(path, verbose = TRUE) {
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
  if (length(rd_files) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Example structure check"))
  }

  # What makes \dontrun{} legitimate is code that CANNOT run in a check: it needs
  # a network, credentials, a person at the keyboard, a database, a running app,
  # or more time than CRAN allows.
  #
  # The reactive-context markers matter as much as the rest. Some examples
  # define `server <- function(input, output, session)`, which is
  # meaningless outside a running Shiny app, but the word "shiny" never appears
  # in them -- so a literal search for it reported three correct \dontrun{} blocks
  # as unnecessary.
  justify_re <- paste(
    # needs a person
    "interactive",
    "readline",
    "menu\\(",
    "askYesNo",
    # needs credentials or a network
    "API",
    "password",
    "token",
    "key",
    "secret",
    "credentials?",
    "auth",
    "download\\.file",
    "httr2?::",
    "curl",
    "network",
    "http[s]?://",
    # needs a database
    "dbConnect",
    "DBI::",
    "RPostgres",
    "RSQLite",
    "dbWriteTable",
    # needs a running app / reactive context
    "shiny",
    "shinyApp",
    "runApp",
    "server\\s*<-\\s*function",
    "\\binput\\$",
    "\\boutput\\$",
    "\\bsession\\b",
    "observeEvent",
    "reactive",
    # needs more time than a check allows
    "long.running",
    "long.time",
    "Sys.sleep",
    # installs or launches external software, or runs a system command
    "install",
    "electron",
    "launch",
    "system2?\\(",
    # a placeholder path the example cannot actually open
    "path/to",
    "your[-_/ ]",
    sep = "|"
  )

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) {
      next
    }
    if (!contains_dontrun(examples)) {
      next
    }
    text <- collect_rd_text(examples)
    if (!grepl(justify_re, text, ignore.case = TRUE, perl = TRUE)) {
      issues <- c(
        issues,
        paste0(basename(file), ": potential unnecessary \\dontrun{}")
      )
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Example structure appears appropriate",
    "Potential example structure issues",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Example structure check")
}

# Recursively true if any subtree carries Rd_tag `tag`.
contains_rd_tag <- function(node, tag) {
  if (identical(attr(node, "Rd_tag"), tag)) {
    return(TRUE)
  }
  if (is.list(node)) {
    any(vapply(node, contains_rd_tag, logical(1), tag = tag, USE.NAMES = FALSE))
  } else {
    FALSE
  }
}

contains_dontrun <- function(node) contains_rd_tag(node, "\\dontrun")

# Flags commented-out code lines inside \examples{}. A "commented-out call"
# is heuristically a line that starts with `#`, has no other code before it,
# and contains a `(` (the giveaway that it's a call rather than prose).
#' Diagnose Examples That Run Nothing
#'
#' Flags an `\examples{}` block whose only content is commented out, so it demonstrates nothing. A comment beside live code is illustration and is not flagged.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @section Source:
#' No formal rule. An `\examples{}` block that is entirely commented out
#' demonstrates nothing, a convention which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_commented_examples(pkg, verbose = FALSE)$passed
diagnose_commented_examples <- function(path, verbose = TRUE) {
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
  if (length(rd_files) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Commented-out examples check"
    ))
  }

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) {
      next
    }
    text <- collect_rd_text(examples)
    lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]

    has_commented <- any(vapply(lines, is_commented_out_code, logical(1)))
    if (!has_commented) {
      next
    }

    # The defect is an example that DEMONSTRATES NOTHING because the code that
    # would run has been commented out. A comment sitting alongside live code is
    # a different thing entirely: some examples comment out server and .qmd
    # snippets that belong in the user's OWN files, then call a setup function
    # for real. That is illustration, not a disabled example,
    # and reporting it was reporting the documentation for doing its job.
    #
    # So: only flag when the block has no runnable code at all. \dontrun{} is
    # skipped, since its contents are not meant to run either.
    runnable <- collect_rd_text(examples, skip = c("\\dontrun", "\\donttest"))
    if (
      !is.null(parse_text_xml(runnable)) &&
        length(xml2::xml_find_all(parse_text_xml(runnable), "//expr")) > 0L
    ) {
      next
    }

    issues <- c(
      issues,
      paste0(
        basename(file),
        ": \\examples{} contains only commented-out code, so it runs nothing"
      )
    )
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Every {.code \\examples{}} block runs something",
    "{.code \\examples{}} blocks that run nothing",
    "Treatment: Uncomment the demonstration, or remove the empty example",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Commented-out examples check")
}

# Everything a package exports, read with R's OWN NAMESPACE parser.
#
# This used to be two hand-rolled regexes over the file, LINE BY LINE, and they
# were catastrophically wrong. A multi-line block, which is the form roxygen2 and
# most humans write:
#
#     export(AES,
#            digest,
#            ...)
#
# lost every name after the first line. Run against the `digest` package the old
# reader returned exactly ONE entry, the string "AES," (trailing comma included),
# where the truth is nine exports. So `digest::digest()`, the package's flagship
# function, was reported as UNEXPORTED. It also ignored exportPattern() entirely.
#
# That single defect silently poisoned every check that asks "is this exported?":
# unexported_example_ns, missing_examples, and roxygen_usage. Across 45 CRAN
# packages it accounted for 121 false findings.
#
# base::parseNamespaceFile() is the parser R itself uses to load a namespace. It
# wants (package, lib) and reads <lib>/<package>/NAMESPACE, which is exactly the
# shape of a source tree.
#
# Returns list(names, patterns), or NULL when the NAMESPACE cannot be parsed. NULL
# means "cannot tell", and every caller must then SKIP rather than guess: a check
# that cannot see the exports must not accuse anything of being unexported.
package_exports <- function(path) {
  full <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (!file.exists(file.path(full, "NAMESPACE"))) {
    return(NULL)
  }

  ns <- tryCatch(
    parseNamespaceFile(basename(full), dirname(full)),
    error = function(e) NULL
  )
  if (is.null(ns)) {
    return(NULL)
  }

  names <- as.character(ns$exports)

  # S3method(generic, class) registers `generic.class`. The optional third column
  # names a differently-named function backing the method.
  s3 <- ns$S3methods
  if (!is.null(s3) && nrow(s3) > 0L) {
    names <- c(names, paste(s3[, 1L], s3[, 2L], sep = "."))
    if (ncol(s3) >= 3L) {
      backing <- s3[, 3L]
      names <- c(names, backing[!is.na(backing)])
    }
  }

  # S4.
  names <- c(
    names,
    as.character(ns$exportClasses),
    as.character(ns$exportMethods)
  )

  list(names = unique(names), patterns = as.character(ns$exportPatterns))
}

# Is `nm` exported, given the result of package_exports()? exportPattern() takes
# regexes, so a name can be exported without ever being named.
name_is_exported <- function(nm, ex) {
  if (is.null(ex)) {
    return(TRUE)
  } # cannot tell: assume exported, never accuse
  if (nm %in% ex$names) {
    return(TRUE)
  }
  for (pat in ex$patterns) {
    if (grepl(pat, nm)) return(TRUE)
  }
  FALSE
}


# Returns the primary topic name (first \name{...}) of an Rd object, or NA.
rd_primary_name <- function(rd) {
  for (sec in rd) {
    if (identical(attr(sec, "Rd_tag"), "\\name")) {
      return(trimws(collect_rd_text(sec)))
    }
  }
  NA_character_
}

# Returns all \alias{} values from an Rd object.
rd_aliases <- function(rd) {
  out <- character(0)
  for (sec in rd) {
    if (identical(attr(sec, "Rd_tag"), "\\alias")) {
      out <- c(out, trimws(collect_rd_text(sec)))
    }
  }
  out
}

# Suggest \donttest{} for code that is only slow, not impossible to run.
# Heuristic: an \examples block contains \dontrun{} AND the only "justifying"
# pattern is Sys.sleep() or a "long.running"/"long.time" comment - in that
# case \donttest{} would be the correct macro.
#' Diagnose dontrun Where donttest Belongs
#'
#' Flags `\dontrun{}` around code that is merely slow. `\donttest{}` is the right wrapper, since it still runs under `--run-donttest`.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @section Source:
#' The CRAN Cookbook covers the distinction under
#' [Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples),
#' where `\donttest{}` is the wrapper for an example that merely runs long. Nothing
#' enforces the choice, which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_donttest_vs_dontrun(pkg, verbose = FALSE)$passed
diagnose_donttest_vs_dontrun <- function(path, verbose = TRUE) {
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
  if (length(rd_files) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "donttest vs dontrun check"
    ))
  }

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) {
      next
    }
    if (!contains_dontrun(examples)) {
      next
    }
    text <- collect_rd_text(examples)
    only_slow <- grepl(
      "Sys\\.sleep\\b|long.running|long.time",
      text,
      ignore.case = TRUE,
      perl = TRUE
    ) &&
      !grepl(
        "interactive|API|password|token|key|secret|credentials?|auth|download\\.file|httr2?::|curl",
        text,
        ignore.case = TRUE,
        perl = TRUE
      )
    if (only_slow) {
      issues <- c(
        issues,
        paste0(
          basename(file),
          ": uses \\dontrun{} for slow code; ",
          "prefer \\donttest{}"
        )
      )
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "{.code \\dontrun{}} use is appropriate",
    "Some {.code \\dontrun{}} blocks should be {.code \\donttest{}}",
    "Treatment: Slow-only code belongs in {.code \\donttest{}}",
    level = "warning"
  )
  checktor_check_result(passed, issues, "donttest vs dontrun check")
}

#' Diagnose Exported Functions Missing Examples
#'
#' CRAN expects exported functions to carry a runnable `\examples{}` section.
#' Walks `.Rd` files via [tools::parse_Rd()] and reports exported function
#' topics that lack one. Data, class, methods, package-level, and re-export
#' topics are skipped, and only topics whose name appears in NAMESPACE
#' `export()` are considered (so internal helpers and S3 methods aren't
#' required to have examples). Genuinely side-effect-only functions may be
#' false positives and can be ignored.
#'
#' @inheritParams diagnose_value_tags
#' @return [checktor_check_result()] with `passed`, `issues`, `missing`,
#'   `message`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario(
#' @section Source:
#' The CRAN Cookbook covers examples under
#' [Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples).
#' Exported functions are expected to carry an `\examples{}` block, a convention
#' rather than a rule, which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#'   "documentation_examples/missing_examples_bad.Rd", show_content = FALSE)
#' writeLines("export(undocumented_fn)", file.path(pkg_path, "NAMESPACE"))
#' issues(diagnose_missing_examples(pkg_path, verbose = FALSE))
diagnose_missing_examples <- function(path, verbose = TRUE) {
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
  if (length(rd_files) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Missing examples check"))
  }

  ex <- package_exports(path)
  if (is.null(ex) || length(ex$names) == 0L) {
    # NAMESPACE missing or unparseable: we cannot tell what is exported, so we
    # must not enforce. Guessing here is how a check starts accusing a package's
    # flagship function of not existing.
    return(checktor_check_result(TRUE, character(0), "Missing examples check"))
  }

  missing <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    if (is_non_function_rd_obj(rd)) {
      next
    }
    # \keyword{internal} pages are deprecated shims and other non-API topics that
    # are deliberately hidden from the index. R's own checkRdContents exempts them
    # from its Rd-content checks on the strength of the keyword alone, so requiring
    # a runnable example of them is not a rule anyone enforces.
    if (rd_is_internal(rd)) {
      next
    }
    names <- c(rd_primary_name(rd), rd_aliases(rd))
    names <- names[!is.na(names) & nzchar(names)]
    # Only exported function topics. exportPattern() means a name can be exported
    # without ever being listed, so ask name_is_exported() rather than %in%.
    if (!any(vapply(names, name_is_exported, logical(1), ex = ex))) {
      next
    }
    if (is.null(extract_rd_section(rd, "\\examples"))) {
      missing <- c(missing, basename(file))
    }
  }

  passed <- length(missing) == 0L
  emit_issue_summary(
    missing,
    verbose,
    "Exported functions include {.code \\examples}",
    "Exported functions missing {.code \\examples}",
    "Treatment: Add a runnable {.code @examples} (side-effect-only functions may be exempt)",
    level = "warning"
  )
  checktor_check_result(
    passed,
    missing,
    "Missing examples check",
    missing = missing
  )
}

# Split a DESCRIPTION dependency field (Suggests/Imports/...) into bare package
# names, dropping version constraints and the special "R" entry.
parse_package_list <- function(field) {
  if (is.null(field) || !nzchar(field)) {
    return(character(0))
  }
  parts <- strsplit(field, ",", fixed = TRUE)[[1L]]
  parts <- trimws(sub("\\(.*\\)", "", parts))
  parts <- parts[nzchar(parts)]
  setdiff(parts, "R")
}

#' Diagnose Suggested Packages Used in Examples Without a Guard
#'
#' Under CRAN's `noSuggests` check a package must work without its Suggested
#' packages installed. This flags `\examples{}` that load a Suggested package
#' (`library()`/`require()`/`pkg::`) in code that runs unconditionally and is
#' not guarded by `requireNamespace()` / `rlang::is_installed()` (the form
#' `@examplesIf` and `if (requireNamespace(...))` produce). Usage inside
#' `\dontrun{}` or `\donttest{}` is not flagged.
#'
#' @inheritParams diagnose_value_tags
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario(
#'   "documentation_examples/suggested_in_examples_bad.Rd", show_content = FALSE)
#' cat("Suggests: somesuggest\n",
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Suggested-packages),
#' under "Suggested packages", asks that a package from `Suggests` used in
#' an example be guarded so the example still runs without it. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#'     file = file.path(pkg_path, "DESCRIPTION"), append = TRUE)
#' issues(diagnose_suggested_in_examples(pkg_path, verbose = FALSE))
diagnose_suggested_in_examples <- function(path, verbose = TRUE) {
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
  desc_file <- file.path(path, "DESCRIPTION")
  if (length(rd_files) == 0L || !file.exists(desc_file)) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Suggested-package examples check"
    ))
  }
  desc <- tryCatch(read_description(desc_file), error = function(e) NULL)
  suggests <- if (is.null(desc)) {
    character(0)
  } else {
    parse_package_list(desc[["Suggests"]])
  }
  if (length(suggests) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Suggested-package examples check"
    ))
  }

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) {
      next
    }
    full <- collect_rd_text(examples)
    run <- collect_rd_text(examples, skip = c("\\dontrun", "\\donttest"))
    for (pkg in suggests) {
      esc <- gsub("([.])", "\\\\\\1", pkg)
      use_re <- sprintf(
        "\\b(?:library|require)\\s*\\(\\s*['\"]?%s['\"]?|\\b%s::",
        esc,
        esc
      )
      if (!grepl(use_re, run, perl = TRUE)) {
        next
      }

      # Writing R Extensions sanctions `if (require("pkgB", quietly = TRUE))` as
      # THE way to use a Suggests conditionally in an example. The old guard
      # recognised only requireNamespace()/is_installed(), and only with quotes,
      # while the USE pattern above happily matched `require(chron)` -- so the
      # guard was reported as the violation. zoo, glue, cli and rlang all write it
      # the sanctioned way and were all flagged.
      #
      # Note `interactive()` is deliberately NOT a guard: it does not make the
      # package available, so an example wrapped in it still fails when the package
      # is absent. Some examples do exactly that, and they stay flagged.
      guard_re <- sprintf(
        paste0(
          "(?:requireNamespace|is_installed)\\s*\\(\\s*['\"]?%s['\"]?",
          "|if\\s*\\(\\s*!?\\s*require(?:Namespace)?\\s*\\(\\s*['\"]?%s['\"]?"
        ),
        esc,
        esc
      )
      if (grepl(guard_re, full, perl = TRUE)) {
        next
      }

      # roxygen's `@examplesIf` compiles to
      #   \dontshow{if (COND) (if (getRversion() >= "3.4") withAutoprint else force)({
      # and COND can be anything: cli writes `cli:::has_packages(c("htmltools"))`.
      # The GUARD IS THE STRUCTURE, not the predicate, so match the structure. cli,
      # curl and rlang all guard this way and were all reported.
      if (
        grepl("\\dontshow\\s*\\{\\s*if\\s*\\(|examplesIf", full, perl = TRUE)
      ) {
        next
      }
      issues <- c(
        issues,
        paste0(
          basename(file),
          ": uses Suggested package '",
          pkg,
          "' in \\examples without a guard"
        )
      )
      break # one report per file is enough
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Examples guard Suggested-package usage",
    "Examples use Suggested packages without a guard",
    "Treatment: Wrap in @examplesIf rlang::is_installed('pkg') or if (requireNamespace('pkg'))",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Suggested-package examples check")
}

#' Diagnose Stale Generated Documentation
#'
#' Flags a package whose `NAMESPACE` and `man/` no longer match the roxygen
#' comments they were generated from, i.e. you edited roxygen and forgot to run
#' `devtools::document()`.
#'
#' Two signals, both deliberately clock-free:
#'
#' - A name tagged `@export` in a roxygen block that does not appear in
#'   `NAMESPACE`. This is the real cost of a forgotten `document()` call: the
#'   function is not exported, so users cannot call it, and `R CMD check` says
#'   nothing because a package is free to export whatever it likes.
#' - An `.Rd` file whose roxygen2 backlink names a source file that no longer
#'   exists, which is the orphan left behind when a source file is renamed or
#'   deleted without re-documenting.
#'
#' File modification times are deliberately not used. `git` does not preserve
#' them, so on a fresh clone every file carries roughly the checkout time in
#' arbitrary order, and an mtime comparison would pass or fail at random in CI.
#'
#' The check is skipped entirely unless `NAMESPACE` carries the roxygen2
#' "do not edit by hand" banner, so a hand-managed package is never flagged.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#' @section Source:
#' The CRAN Cookbook covers the roxygen2 side of this under
#' [Repeated Rejections of Issues in Manuals](https://contributor.r-project.org/cran-cookbook/docs_issues.html#repeated-rejections-of-issues-in-manuals-if-using-roxygen2),
#' where documentation is regenerated rather than hand-edited. A function tagged
#' `@export` that never reached `NAMESPACE` is not actually exported, and no binding
#' rule names it, which is why this sits at `robustness` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#'                                       show_content = FALSE)
#' diagnose_roxygen_usage(pkg_path, verbose = FALSE)$passed
diagnose_roxygen_usage <- function(path, verbose = TRUE) {
  pass <- function() {
    checktor_check_result(TRUE, character(0), "Roxygen freshness check")
  }

  r_files <- list_r_files(path)
  if (length(r_files) == 0L) {
    return(pass())
  }

  # Only meaningful for a roxygen-managed package. A hand-written NAMESPACE is
  # nobody's business but its author's.
  ns_lines <- safe_read_lines(file.path(path, "NAMESPACE"))
  if (!any(grepl("Generated by roxygen2", ns_lines, fixed = TRUE))) {
    return(pass())
  }

  issues <- character(0)

  # Signal 1: tagged @export in roxygen, absent from NAMESPACE.
  declared <- roxygen_exported_names(read_r_xml(path))
  if (length(declared) > 0L) {
    ex <- package_exports(path)
    if (is.null(ex)) {
      return(pass())
    } # cannot read NAMESPACE: cannot judge drift
    hit <- vapply(names(declared), name_is_exported, logical(1), ex = ex)
    missing <- declared[!hit]
    if (length(missing) > 0L) {
      issues <- c(
        issues,
        paste0(
          names(missing),
          " is tagged @export in ",
          unname(missing),
          " but is absent from NAMESPACE"
        )
      )
    }
  }

  # Signal 2: an Rd pointing back at a source file that is gone.
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
  for (rd in rd_files) {
    head_lines <- utils::head(safe_read_lines(rd), 3L)
    backlink <- grep(
      "^%\\s*Please edit documentation in ",
      head_lines,
      value = TRUE
    )
    if (length(backlink) == 0L) {
      next
    } # hand-written Rd
    srcs <- sub("^%\\s*Please edit documentation in ", "", backlink[[1L]])
    srcs <- trimws(strsplit(srcs, ",", fixed = TRUE)[[1L]])
    gone <- srcs[!file.exists(file.path(path, srcs))]
    if (length(gone) > 0L) {
      issues <- c(
        issues,
        paste0(
          basename(rd),
          " documents ",
          paste(gone, collapse = ", "),
          ", which no longer exists"
        )
      )
    }
  }

  emit_issue_summary(
    issues,
    verbose,
    "Generated documentation is up to date",
    "Generated documentation is out of sync with roxygen",
    "Treatment: Run devtools::document() to regenerate man/ and NAMESPACE",
    level = "warning"
  )
  checktor_check_result(length(issues) == 0L, issues, "Roxygen freshness check")
}

# Names carrying an `@export` tag in a roxygen block, as a named character
# vector: names are the object names, values the file each was found in.
#
# This runs on the parse tree, not the source text. `COMMENT` is a real token in
# getParseData(), so roxygen blocks are located structurally, and the exported
# object is the target of the first top-level expression that FOLLOWS the block,
# read off the tree by assign_target_of(). That is what buys us `add <-` split
# across two lines, `x = 1`, and backticked or quoted names, none of which a
# "regex the next line" approach survives.
#
# Matching `@export` within the comment's own text IS a regex, and correctly so:
# roxygen tags have no finer tokenization than the COMMENT they sit in. The rule
# the AST rewrite enforces is "do not regex the raw source", not "never regex".
#
# Anything that does not resolve to a plain assigned name (S4 setMethod, the
# `"_PACKAGE"` sentinel) is skipped rather than guessed at: a false "you forgot
# to document()" is worse than a miss.
roxygen_exported_names <- function(parsed) {
  out <- character(0)
  for (entry in parsed) {
    if (is.null(entry$xml)) {
      next
    }
    file <- basename(entry$file)

    # A top-level `<-` is an `expr`, but a top-level `=` is wrapped in
    # `expr_or_assign_or_help` (`equal_assign` on older R), so matching only
    # `expr` would silently skip every `name = function(...)` in the package.
    top <- xml2::xml_find_all(
      entry$xml,
      "/exprlist/*[self::expr or self::expr_or_assign_or_help or self::equal_assign]"
    )
    if (length(top) == 0L) {
      next
    }
    top_line <- as.integer(xml2::xml_attr(top, "line1"))

    comments <- xml2::xml_find_all(entry$xml, "//COMMENT")
    for (cmt in comments) {
      text <- xml2::xml_text(cmt)
      # `@export` exactly. The negative lookahead is load-bearing: without it
      # `@exportS3Method` matches too.
      if (!grepl("^\\s*#'\\s*@export(?![A-Za-z0-9_])", text, perl = TRUE)) {
        next
      }

      # `@export` may name its objects outright, and may name SEVERAL:
      # jsonlite writes `#' @export fromJSON toJSON`. Storing that whole string as
      # one name invented a function called "fromJSON toJSON" and then reported it
      # as missing from NAMESPACE.
      explicit <- trimws(sub("^\\s*#'\\s*@export\\s*", "", text, perl = TRUE))
      if (nzchar(explicit)) {
        for (nm in strsplit(explicit, "[,[:space:]]+")[[1L]]) {
          if (nzchar(nm)) out[[nm]] <- file
        }
        next
      }

      # The object being exported is the target of the first top-level
      # expression starting after this comment line.
      line <- as.integer(xml2::xml_attr(cmt, "line2"))
      nxt <- which(top_line > line)
      if (length(nxt) == 0L) {
        next
      }
      name <- assign_target_of(top[[nxt[[1L]]]])
      if (!is.na(name)) out[[name]] <- file
    }
  }
  out
}

#' Diagnose Bare Calls to Unexported Functions in Examples
#'
#' Flags an `\examples{}` block that calls its own topic bare when that topic is
#' not exported. Examples run with only the package's exports attached, so the
#' call fails.
#'
#' `R CMD check` does catch this, but only by RUNNING the examples, which is late
#' and slow, and it is skipped entirely when examples are wrapped in `\dontrun{}`
#' or when you check with `--no-examples`. This finds it statically in a second.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                       show_content = FALSE)
#' @section Source:
#' No formal rule. An example that reaches for an unexported object will
#' error when it runs, which is why this sits at `robustness` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' diagnose_unexported_example_namespace(pkg_path, verbose = FALSE)$passed
diagnose_unexported_example_namespace <- function(path, verbose = TRUE) {
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
  if (length(rd_files) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Unexported example-namespace check"
    ))
  }

  ex <- package_exports(path)
  if (is.null(ex) || length(ex$names) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Unexported example-namespace check"
    ))
  }

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    names <- c(rd_primary_name(rd), rd_aliases(rd))
    names <- names[!is.na(names) & nzchar(names)]
    if (length(names) == 0L) {
      next
    }
    if (any(vapply(names, name_is_exported, logical(1), ex = ex))) {
      next
    }
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) {
      next
    }
    # \dontrun{} is not executed, so a bare call in there cannot fail. R CMD check
    # would not run it either.
    text <- collect_rd_text(examples, skip = "\\dontrun")

    # Parse the example code rather than grepping it. A comment reading
    # `# call helper(1) yourself`, or the string "helper(", is not a call, and
    # only the parse tree knows that. `pkg:::helper()` still produces a
    # SYMBOL_FUNCTION_CALL, so the `:::` is detected as a preceding NS_GET_INT
    # sibling rather than by looking for a colon in the text.
    xml <- parse_text_xml(text)
    if (is.null(xml)) {
      next
    } # example does not parse; not our check to report

    for (nm in names) {
      bare <- xml2::xml_find_all(
        xml,
        sprintf(
          "//SYMBOL_FUNCTION_CALL[text() = '%s' and not(preceding-sibling::NS_GET) and not(preceding-sibling::NS_GET_INT)]",
          nm
        )
      )
      if (length(bare) > 0L) {
        issues <- c(
          issues,
          paste0(
            basename(file),
            ": unexported '",
            nm,
            "()' called bare in \\examples; use 'pkg:::",
            nm,
            "()'"
          )
        )
        break
      }
    }
  }

  emit_issue_summary(
    issues,
    verbose,
    "Unexported examples use {.code :::} where needed",
    "Unexported topics call themselves bare in {.code \\examples{}}",
    "Treatment: Use {.code pkg:::name()} or add {.code @noRd}",
    level = "warning"
  )
  checktor_check_result(
    length(issues) == 0L,
    issues,
    "Unexported example-namespace check"
  )
}

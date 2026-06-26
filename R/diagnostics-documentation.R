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
  run_checks(list(
    value_tags                = diagnose_value_tags,
    missing_examples          = diagnose_missing_examples,
    roxygen_usage             = diagnose_roxygen_usage,
    example_structure         = diagnose_example_structure,
    commented_examples        = diagnose_commented_examples,
    unexported_example_ns     = diagnose_unexported_example_namespace,
    donttest_vs_dontrun       = diagnose_donttest_vs_dontrun,
    suggested_in_examples     = diagnose_suggested_in_examples
  ), path, verbose)
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
  rd_files <- list.files(file.path(path, "man"),
                         pattern = "\\.Rd$", full.names = TRUE)
  if (length(rd_files) == 0L) {
    if (verbose) cli::cli_alert_info("No .Rd files found")
    return(checktor_check_result(TRUE, character(0), "Value tags check"))
  }

  missing_value <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) next
    if (is_non_function_rd_obj(rd)) next
    if (is.null(extract_rd_section(rd, "\\value"))) {
      missing_value <- c(missing_value, basename(file))
    }
  }

  passed <- length(missing_value) == 0L
  emit_issue_summary(
    missing_value, verbose,
    "All function documentation has {.code \\value} tags",
    "Missing {.code \\value} tags"
  )
  checktor_check_result(passed, missing_value, "Value tags check",
                        missing = missing_value)
}

#' Diagnose Roxygen2 Usage
#'
#' Informational check: reports whether the package appears to use roxygen2.
#'
#' @inheritParams diagnose_value_tags
#' @return [checktor_check_result()] with `passed` (always `TRUE`),
#'   `has_roxygen`, `message`.
#' @export
#' @examples
#' diagnose_roxygen_usage(".", verbose = FALSE)$has_roxygen
diagnose_roxygen_usage <- function(path, verbose = TRUE) {
  r_files <- list_r_files(path)
  if (length(r_files) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Roxygen usage check",
                                 has_roxygen = FALSE))
  }

  has_roxygen <- FALSE
  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) > 0L && any(grepl("^\\s*#'", content))) {
      has_roxygen <- TRUE
      break
    }
  }

  if (verbose) {
    if (has_roxygen) {
      cli::cli_alert_info(
        "Roxygen2 usage detected - ensure to run {.code roxygenize()} before submission"
      )
    } else {
      cli::cli_alert_info("No Roxygen2 usage detected")
    }
  }
  checktor_check_result(TRUE, character(0), "Roxygen usage check",
                        has_roxygen = has_roxygen)
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
#' @examples
#' pkg_path <- example_diagnose_scenario("network_examples/bad_network_example.Rd",
#'                                       show_content = FALSE)
#' diagnose_example_structure(pkg_path, verbose = FALSE)
diagnose_example_structure <- function(path, verbose = TRUE) {
  rd_files <- list.files(file.path(path, "man"),
                         pattern = "\\.Rd$", full.names = TRUE)
  if (length(rd_files) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Example structure check"))
  }

  justify_re <- paste(
    "interactive", "API", "password", "token", "key", "secret",
    "credentials?", "auth", "download\\.file", "httr2?::", "curl",
    "long.running", "long.time", "Sys.sleep", "shiny",
    sep = "|"
  )

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) next
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) next
    if (!contains_dontrun(examples)) next
    text <- collect_rd_text(examples)
    if (!grepl(justify_re, text, ignore.case = TRUE, perl = TRUE)) {
      issues <- c(issues,
                  paste0(basename(file), ": potential unnecessary \\dontrun{}"))
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Example structure appears appropriate",
    "Potential example structure issues",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Example structure check")
}

# Recursively true if any subtree carries Rd_tag `tag`.
contains_rd_tag <- function(node, tag) {
  if (identical(attr(node, "Rd_tag"), tag)) return(TRUE)
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
diagnose_commented_examples <- function(path, verbose = TRUE) {
  rd_files <- list.files(file.path(path, "man"),
                         pattern = "\\.Rd$", full.names = TRUE)
  if (length(rd_files) == 0L) {
    return(checktor_check_result(TRUE, character(0),
                                 "Commented-out examples check"))
  }

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) next
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) next
    text <- collect_rd_text(examples)
    lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
    for (i in seq_along(lines)) {
      ln <- lines[i]
      if (grepl("^\\s*#[^'#].*\\(", ln, perl = TRUE)) {
        issues <- c(issues,
                    paste0(basename(file),
                           ": commented-out call in \\examples{}"))
        break  # one report per file is enough
      }
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No commented-out code in {.code \\examples{}}",
    "Commented-out code in {.code \\examples{}}",
    "Treatment: Remove the comment or make it a real example",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Commented-out examples check")
}

# Reads NAMESPACE and returns a character vector of all exported symbol
# names (from export(...) directives). Empty character vector on any error.
read_exports <- function(path) {
  ns_file <- file.path(path, "NAMESPACE")
  if (!file.exists(ns_file)) return(character(0))
  content <- safe_read_lines(ns_file)
  m <- regmatches(content, regexpr("(?<=export\\()[^)]+", content, perl = TRUE))
  trimws(unlist(m), whitespace = "[\\s\"']")
}

# Reads NAMESPACE and returns names appearing in S3method(...) registrations
# (those count as exports for our purposes).
read_s3methods <- function(path) {
  ns_file <- file.path(path, "NAMESPACE")
  if (!file.exists(ns_file)) return(character(0))
  content <- safe_read_lines(ns_file)
  m <- regmatches(content, regexpr("(?<=S3method\\()[^)]+", content, perl = TRUE))
  out <- character(0)
  for (entry in m) {
    parts <- trimws(strsplit(entry, ",", fixed = TRUE)[[1]])
    if (length(parts) >= 2L) {
      out <- c(out, paste(parts[[1]], parts[[2]], sep = "."))
    }
  }
  out
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

# If an Rd file documents an unexported function and the \examples{} calls
# the function by bare name, CRAN requires the call to use `pkg:::fn()`.
diagnose_unexported_example_namespace <- function(path, verbose = TRUE) {
  rd_files <- list.files(file.path(path, "man"),
                         pattern = "\\.Rd$", full.names = TRUE)
  if (length(rd_files) == 0L) {
    return(checktor_check_result(TRUE, character(0),
                                 "Unexported example-namespace check"))
  }

  exports <- c(read_exports(path), read_s3methods(path))
  if (length(exports) == 0L) {
    # No exports declared - either an empty package or NAMESPACE is missing;
    # don't try to enforce.
    return(checktor_check_result(TRUE, character(0),
                                 "Unexported example-namespace check"))
  }

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) next
    names <- c(rd_primary_name(rd), rd_aliases(rd))
    names <- names[!is.na(names) & nzchar(names)]
    if (length(names) == 0L) next
    # If any documented name is exported, the topic is treated as exported.
    if (any(names %in% exports)) next
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) next
    text <- collect_rd_text(examples)
    # Flag if a documented name appears as `name(` without preceding `:::`.
    # R function names match [A-Za-z0-9._], so only `.` needs escaping.
    for (nm in names) {
      pat <- sprintf("(?<!:)\\b%s\\s*\\(", gsub(".", "\\.", nm, fixed = TRUE))
      if (grepl(pat, text, perl = TRUE)) {
        issues <- c(issues,
                    paste0(basename(file),
                           ": unexported '", nm,
                           "()' called bare in \\examples; use ",
                           "'pkg:::", nm, "()'"))
        break
      }
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Unexported examples use {.code :::} where needed",
    "Unexported topics call themselves bare in {.code \\examples{}}",
    "Treatment: Use {.code pkg:::name()} or add {.code @noRd}",
    level = "warning"
  )
  checktor_check_result(passed, issues,
                        "Unexported example-namespace check")
}

# Suggest \donttest{} for code that is only slow, not impossible to run.
# Heuristic: an \examples block contains \dontrun{} AND the only "justifying"
# pattern is Sys.sleep() or a "long.running"/"long.time" comment - in that
# case \donttest{} would be the correct macro.
diagnose_donttest_vs_dontrun <- function(path, verbose = TRUE) {
  rd_files <- list.files(file.path(path, "man"),
                         pattern = "\\.Rd$", full.names = TRUE)
  if (length(rd_files) == 0L) {
    return(checktor_check_result(TRUE, character(0),
                                 "donttest vs dontrun check"))
  }

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) next
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) next
    if (!contains_dontrun(examples)) next
    text <- collect_rd_text(examples)
    only_slow <- grepl("Sys\\.sleep\\b|long.running|long.time",
                       text, ignore.case = TRUE, perl = TRUE) &&
      !grepl("interactive|API|password|token|key|secret|credentials?|auth|download\\.file|httr2?::|curl",
             text, ignore.case = TRUE, perl = TRUE)
    if (only_slow) {
      issues <- c(issues,
                  paste0(basename(file),
                         ": uses \\dontrun{} for slow code; ",
                         "prefer \\donttest{}"))
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
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
#'   "documentation_examples/missing_examples_bad.Rd", show_content = FALSE)
#' writeLines("export(undocumented_fn)", file.path(pkg_path, "NAMESPACE"))
#' issues(diagnose_missing_examples(pkg_path, verbose = FALSE))
diagnose_missing_examples <- function(path, verbose = TRUE) {
  rd_files <- list.files(file.path(path, "man"),
                         pattern = "\\.Rd$", full.names = TRUE)
  if (length(rd_files) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Missing examples check"))
  }

  exports <- read_exports(path)
  if (length(exports) == 0L) {
    # No exports declared - can't tell which topics are exported; don't enforce.
    return(checktor_check_result(TRUE, character(0), "Missing examples check"))
  }

  missing <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) next
    if (is_non_function_rd_obj(rd)) next
    names <- c(rd_primary_name(rd), rd_aliases(rd))
    names <- names[!is.na(names) & nzchar(names)]
    if (!any(names %in% exports)) next     # only exported function topics
    if (is.null(extract_rd_section(rd, "\\examples"))) {
      missing <- c(missing, basename(file))
    }
  }

  passed <- length(missing) == 0L
  emit_issue_summary(
    missing, verbose,
    "Exported functions include {.code \\examples}",
    "Exported functions missing {.code \\examples}",
    "Treatment: Add a runnable {.code @examples} (side-effect-only functions may be exempt)",
    level = "warning"
  )
  checktor_check_result(passed, missing, "Missing examples check",
                        missing = missing)
}

# Split a DESCRIPTION dependency field (Suggests/Imports/...) into bare package
# names, dropping version constraints and the special "R" entry.
parse_package_list <- function(field) {
  if (is.null(field) || !nzchar(field)) return(character(0))
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
#'     file = file.path(pkg_path, "DESCRIPTION"), append = TRUE)
#' issues(diagnose_suggested_in_examples(pkg_path, verbose = FALSE))
diagnose_suggested_in_examples <- function(path, verbose = TRUE) {
  rd_files <- list.files(file.path(path, "man"),
                         pattern = "\\.Rd$", full.names = TRUE)
  desc_file <- file.path(path, "DESCRIPTION")
  if (length(rd_files) == 0L || !file.exists(desc_file)) {
    return(checktor_check_result(TRUE, character(0),
                                 "Suggested-package examples check"))
  }
  desc <- tryCatch(read_description(desc_file), error = function(e) NULL)
  suggests <- if (is.null(desc)) character(0) else
    parse_package_list(desc[["Suggests"]])
  if (length(suggests) == 0L) {
    return(checktor_check_result(TRUE, character(0),
                                 "Suggested-package examples check"))
  }

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) next
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) next
    full <- collect_rd_text(examples)
    run  <- collect_rd_text(examples, skip = c("\\dontrun", "\\donttest"))
    for (pkg in suggests) {
      esc <- gsub("([.])", "\\\\\\1", pkg)
      use_re <- sprintf(
        "\\b(?:library|require)\\s*\\(\\s*['\"]?%s['\"]?|\\b%s::", esc, esc
      )
      if (!grepl(use_re, run, perl = TRUE)) next
      guard_re <- sprintf(
        "(?:requireNamespace|is_installed)\\s*\\(\\s*['\"]%s['\"]", esc
      )
      if (grepl(guard_re, full, perl = TRUE)) next
      issues <- c(issues,
                  paste0(basename(file), ": uses Suggested package '", pkg,
                         "' in \\examples without a guard"))
      break  # one report per file is enough
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Examples guard Suggested-package usage",
    "Examples use Suggested packages without a guard",
    "Treatment: Wrap in @examplesIf rlang::is_installed('pkg') or if (requireNamespace('pkg'))",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Suggested-package examples check")
}

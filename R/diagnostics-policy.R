#' Check for Common CRAN Policy Violations
#'
#' Runs additional diagnostics focused on CRAN policy: leftover `browser()`
#' calls, raw system invocations, file writes outside `tempdir()`, and
#' unwrapped network access in examples or vignettes. Code-side checks use
#' the parsed AST so string/comment matches don't false-positive; Rd-side
#' checks use [tools::parse_Rd()] for the same reason.
#'
#' @param path Character. Path to the R package directory. Default: `"."`.
#' @param verbose Logical. Whether to print diagnostic output. Default: `TRUE`.
#'
#' @return
#' List of [checktor_check_result()] objects, plus a `passed` named logical
#' vector summarizing pass/fail per check.
#'
#' @seealso [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/browser_calls_bad.R",
#'                                  show_content = FALSE)
#' policy <- diagnose_policy_violations(pkg, verbose = FALSE)
#' summary(policy)
#' issues(policy)
diagnose_policy_violations <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("CRAN Policy Violations Check")
  }

  # Pre-parse once for the code-side checks.
  parsed <- if (dir.exists(file.path(path, "R"))) read_r_xml(path) else list()

  run_checks(list(
    browser_calls      = function(p, v) diagnose_browser_calls(p, v, parsed = parsed),
    system_calls       = function(p, v) diagnose_system_calls(p, v, parsed = parsed),
    file_operations    = function(p, v) diagnose_file_operations(p, v, parsed = parsed),
    network_operations = function(p, v) diagnose_network_operations(p, v)
  ), path, verbose)
}

diagnose_browser_calls <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Browser calls check"))
  }
  issues <- undesirable_function_check(parsed, "browser", label = FALSE)
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No {.code browser()} calls found",
    "{.code browser()} calls found (should be removed for CRAN)"
  )
  checktor_check_result(passed, issues, "Browser calls check")
}

diagnose_system_calls <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "System calls check"))
  }
  issues <- undesirable_function_check(parsed,
                                       c("system", "system2", "shell"),
                                       label = TRUE)
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No dangerous system calls found",
    "Potential dangerous system calls found",
    "Treatment: Review these carefully - may need platform checks",
    level = "warning"
  )
  checktor_check_result(passed, issues, "System calls check")
}

# Writes outside tempdir(). For each write-like call, check whether the first
# argument expression - or any nearby preceding assignment - references
# tempfile/tempdir. We approximate "preceding assignment" by looking at
# top-level siblings before the call.
diagnose_file_operations <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "File operations check"))
  }

  write_funs <- c("write.csv", "write.csv2", "write.table", "writeLines",
                  "saveRDS", "save", "file.create")
  predicate <- paste(sprintf("text() = '%s'", write_funs),
                     collapse = " or ")
  # A write call is "safe" if any tempfile/tempdir call appears in:
  #   (a) the same call's argument expressions (path argument is a tempfile()
  #       invocation, e.g. `saveRDS(x, tempfile())`)
  #   (b) earlier statements in the same scope (enclosing function body or
  #       same top-level exprlist), e.g. `p <- tempfile(); saveRDS(x, p)`
  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[%s][
       not(parent::expr/following-sibling::expr//SYMBOL_FUNCTION_CALL[
         text() = 'tempfile' or text() = 'tempdir'
       ])
       and not(
         ancestor::expr[parent::expr/FUNCTION or parent::exprlist][1]
         //SYMBOL_FUNCTION_CALL[text() = 'tempfile' or text() = 'tempdir']
       )
     ]",
    predicate
  )
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    paste0(basename(file), ":",
           xml2::xml_attr(nodes, "line1"),
           " (", xml2::xml_text(nodes), "())")
  })

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "File operations appear safe",
    "Potential file operations without temp directory",
    "Treatment: Ensure file operations use temporary directories",
    level = "warning"
  )
  checktor_check_result(passed, issues, "File operations check")
}

# Walks .Rd files via tools::parse_Rd. For each \examples{} block, looks for
# nested network calls that are NOT wrapped in \dontrun/\donttest/\dontshow
# or an `if (interactive())` / `capabilities("libcurl")` guard.
diagnose_network_operations <- function(path, verbose = TRUE) {
  rd_files <- list.files(file.path(path, "man"),
                         pattern = "\\.Rd$", full.names = TRUE, recursive = TRUE)
  vignette_files <- list.files(file.path(path, "vignettes"),
                               pattern = "\\.(Rmd|qmd|md)$",
                               full.names = TRUE, recursive = TRUE)
  if (length(rd_files) == 0L && length(vignette_files) == 0L) {
    return(checktor_check_result(TRUE, character(0),
                                 "Network operations check"))
  }

  net_re <- paste(
    "\\bdownload\\.file\\b", "\\bhttr2?::", "\\bcurl::", "\\bRCurl::",
    sep = "|"
  )

  issues <- character(0)

  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) next
    ex <- extract_rd_section(rd, "\\examples")
    if (is.null(ex)) next
    code <- collect_rd_text(ex, skip = c("\\dontrun", "\\donttest", "\\dontshow"))
    if (!nzchar(code)) next
    if (grepl(net_re, code, perl = TRUE)) {
      issues <- c(issues, paste0(basename(file), " (unwrapped network call in \\examples)"))
    }
  }

  for (file in vignette_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0L) next
    has_wrapper <- any(grepl("if\\s*\\(\\s*interactive|capabilities\\(\\s*[\"']libcurl[\"']",
                             content, perl = TRUE))
    for (pat in c("\\bdownload\\.file\\b", "\\bhttr2?::",
                  "\\bcurl::", "\\bRCurl::")) {
      hits <- grep(pat, content, perl = TRUE)
      if (length(hits) > 0L && !has_wrapper) {
        issues <- c(issues, paste0(basename(file), " (",
                                   gsub("\\\\b|\\\\.|::", "", pat), ")"))
      }
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Network operations appear properly wrapped",
    "Potential unwrapped network operations",
    "Treatment: Wrap in \\dontrun{}, \\donttest{}, or capability checks",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Network operations check")
}

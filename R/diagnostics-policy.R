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

  run_checks(
    c(
      list(
        browser_calls = function(p, v) {
          diagnose_browser_calls(p, v, parsed = parsed)
        },
        system_calls = function(p, v) {
          diagnose_system_calls(p, v, parsed = parsed)
        },
        file_operations = function(p, v) {
          diagnose_file_operations(p, v, parsed = parsed)
        },
        network_operations = function(p, v) diagnose_network_operations(p, v)
      ),
      registered_checks_for("policy", parsed = parsed)
    ),
    path,
    verbose
  )
}

#' Diagnose Leftover browser() Calls
#'
#' Flags a `browser()` call left in package code.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_browser_calls(pkg, verbose = FALSE)$passed
diagnose_browser_calls <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Browser calls check"))
  }
  issues <- undesirable_function_check(parsed, "browser", label = FALSE)
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No {.code browser()} calls found",
    "{.code browser()} calls found (should be removed for CRAN)"
  )
  checktor_check_result(passed, issues, "Browser calls check")
}

#' Diagnose System Calls
#'
#' Flags `system()` / `system2()` / `shell()`, which need review for portability and for shell-injection risk.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_system_calls(pkg, verbose = FALSE)$passed
diagnose_system_calls <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "System calls check"))
  }
  # The check's own remediation says "may need platform checks". A call that ALREADY
  # sits in a function doing exactly that is not what we are asking about. shell()
  # is Windows-only by definition, so a package calling it invariably branches on
  # the OS first; beepr and cli were reported for the correctly-branched call.
  platform_aware <- not_under_fn_with_call_xpath(c(
    "Sys.info",
    "os_type",
    "is_windows",
    "is_mac",
    "is_osx",
    "is_unix",
    "capabilities",
    "Sys.which"
  ))
  predicate <- paste(
    sprintf("text() = '%s'", c("system", "system2", "shell")),
    collapse = " or "
  )
  xpath <- sprintf(
    paste0(
      "//SYMBOL_FUNCTION_CALL[(%s) and %s and %s",
      " and not(ancestor::expr[FUNCTION][1]//SYMBOL[text() = '.Platform'])]"
    ),
    predicate,
    NOT_MEMBER_ACCESS,
    platform_aware
  )
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    paste0(
      basename(file),
      ":",
      xml2::xml_attr(nodes, "line1"),
      " (",
      xml2::xml_text(nodes),
      "())"
    )
  })
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No dangerous system calls found",
    "Potential dangerous system calls found",
    "Treatment: Review these carefully - may need platform checks",
    level = "warning"
  )
  checktor_check_result(passed, issues, "System calls check")
}

# Writes to a path we can PROVE lands in the user's filespace.
#
# CRAN Repository Policy: a package may not write to the user's home filespace,
# nor to the working directory, without permission. The operative words are
# "without permission" -- so the question is not "does this call write?" but
# "can we prove where it writes?"
#
# Only a LITERAL destination can be proven. `writeLines(x, "output.csv")` writes
# to whatever the working directory happens to be, every time. By contrast
# `writeLines(x, out_file)` writes wherever the caller said, and a caller who
# passed the path gave permission by doing so. An earlier version had this
# backwards: it flagged every write and then tried to exempt the ones whose
# destination was a formal, which meant every computed path -- surveydown's
# `writeLines(template, env_file)`, where env_file is built from a user-supplied
# directory -- was reported.
#
# The one hole that leaves is a destination that IS a symbol but DEFAULTS to a
# bad path, as in `function(path = "~/data.csv")`. That is closed separately.
#' Diagnose Writes to the User's Filespace
#'
#' Flags a write whose destination is a literal path, so it provably lands in the working directory or the user's home. A caller-supplied or computed destination is permission, and is not flagged.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_file_operations(pkg, verbose = FALSE)$passed
diagnose_file_operations <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "File operations check"))
  }

  write_funs <- c(
    "write.csv",
    "write.csv2",
    "write.table",
    "writeLines",
    "saveRDS",
    "save",
    "file.create"
  )
  predicate <- paste(sprintf("text() = '%s'", write_funs), collapse = " or ")
  xpath <- sprintf("//SYMBOL_FUNCTION_CALL[%s]", predicate)

  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    keep <- vapply(
      nodes,
      function(n) {
        dest_is_unsafe_literal(
          write_destination(n),
          formals_with_unsafe_default(n)
        )
      },
      logical(1)
    )
    nodes <- nodes[keep]
    if (length(nodes) == 0L) {
      return(character(0))
    }
    paste0(
      basename(file),
      ":",
      xml2::xml_attr(nodes, "line1"),
      " (",
      xml2::xml_text(nodes),
      "())"
    )
  })

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "File operations use {.code tempdir()} or a caller-supplied path",
    "File operations write to a hardcoded path",
    "Treatment: Write to {.code tempdir()}, or take the destination as an argument",
    level = "warning"
  )
  checktor_check_result(passed, issues, "File operations check")
}

# Walks .Rd files via tools::parse_Rd. For each \examples{} block, looks for
# nested network calls that are NOT wrapped in \dontrun/\donttest/\dontshow
# or an `if (interactive())` / `capabilities("libcurl")` guard.
#' Diagnose Unguarded Network Access
#'
#' Flags network access in code or examples that runs without a guard.
#'
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_network_operations(pkg, verbose = FALSE)$passed
diagnose_network_operations <- function(path, verbose = TRUE) {
  rd_files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE,
    recursive = TRUE
  )
  vignette_files <- list.files(
    file.path(path, "vignettes"),
    pattern = "\\.(Rmd|qmd|md)$",
    full.names = TRUE,
    recursive = TRUE
  )
  if (length(rd_files) == 0L && length(vignette_files) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Network operations check"
    ))
  }

  net_re <- paste(
    "\\bdownload\\.file\\b",
    "\\bhttr2?::",
    "\\bcurl::",
    "\\bRCurl::",
    sep = "|"
  )

  issues <- character(0)

  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    ex <- extract_rd_section(rd, "\\examples")
    if (is.null(ex)) {
      next
    }
    code <- collect_rd_text(
      ex,
      skip = c("\\dontrun", "\\donttest", "\\dontshow")
    )
    if (!nzchar(code)) {
      next
    }
    if (grepl(net_re, code, perl = TRUE)) {
      issues <- c(
        issues,
        paste0(basename(file), " (unwrapped network call in \\examples)")
      )
    }
  }

  # A vignette is mostly PROSE. This loop used to grep the raw file line by line, so
  # every narrative mention of a function became a finding: curl's intro.Rmd
  # describes itself as "a drop-in replacement for `download.file` in r-base" and
  # was reported for saying so. The rest of checktor is AST-based precisely so a
  # name in text is not mistaken for a call; this one loop was not.
  #
  # Extract the R code chunks, parse them, and ask the parse tree instead.
  for (file in vignette_files) {
    code <- vignette_r_code(file)
    if (!nzchar(code)) {
      next
    }
    xml <- parse_text_xml(code)
    if (is.null(xml)) {
      next
    }

    guarded <- length(xml2::xml_find_all(
      xml,
      "//SYMBOL_FUNCTION_CALL[text() = 'interactive' or text() = 'capabilities']"
    )) >
      0L
    if (guarded) {
      next
    }

    hits <- xml2::xml_find_all(
      xml,
      paste0(
        "//SYMBOL_FUNCTION_CALL[",
        "  text() = 'download.file' or text() = 'curl_download'",
        "][",
        NOT_MEMBER_ACCESS,
        "]",
        " | //SYMBOL_PACKAGE[text() = 'httr' or text() = 'httr2'",
        "                    or text() = 'curl' or text() = 'RCurl']"
      )
    )
    if (length(hits) > 0L) {
      issues <- c(
        issues,
        paste0(
          basename(file),
          ": unguarded network access in a code chunk (",
          paste(unique(xml2::xml_text(hits)), collapse = ", "),
          ")"
        )
      )
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Network operations appear properly wrapped",
    "Potential unwrapped network operations",
    "Treatment: Wrap in \\dontrun{}, \\donttest{}, or capability checks",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Network operations check")
}

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
  path <- find_package_root(path)
  # Share each parse among this panel's checks; see R/cache.R.
  local_run_cache()
  if (verbose) {
    cli::cli_h2("CRAN Policy Violations Check")
  }

  # Pre-parse once for the code-side checks.
  parsed <- if (dir.exists(file.path(path, "R"))) read_r_xml(path) else list()

  run_checks(
    c(
      builtin_checks_for("policy", parsed = parsed),
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
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' requires checks to run non-interactively, so a debugging leftover such as
#' `browser()` must not be left in. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/browser_calls_bad.R",
#'                                  show_content = FALSE)
#' lab_browser_calls(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_browser_calls <- function(path, verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
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
#' @section Source:
#' No flat rule. A raw `system()` or `system2()` call needs review for
#' portability rather than being an automatic violation, which is why this sits
#' at `robustness` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/system_calls_bad.R",
#'                                  show_content = FALSE)
#' lab_system_calls(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_system_calls <- function(path, verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
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
# destination was a formal, which meant every computed path -- a
# `writeLines(template, env_file)` where env_file is built from a user-supplied
# directory -- was reported.
#
# The one hole that leaves is a destination that IS a symbol but DEFAULTS to a
# bad path, as in `function(path = "~/data.csv")`. That is closed separately.
#' Diagnose Writes to the User's Filespace
#'
#' Flags a write whose destination is a literal path, so it provably lands in the working directory or the user's home. A caller-supplied or computed destination is permission, and is not flagged.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' states that "Packages should not write ... anywhere ... apart from the R
#' session's temporary directory". See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/file_operations_bad.R",
#'                                  show_content = FALSE)
#' lab_file_operations(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_file_operations <- function(path, verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  if (is.null(parsed)) {
    parsed <- read_r_xml(path)
  }
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "File operations check"))
  }

  predicate <- paste(
    sprintf("text() = '%s'", WRITE_FUNCTIONS),
    collapse = " or "
  )
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

# Calls that make a request when they run. download.file() and curl's fetchers
# have names no other package uses, so they are matched bare as well as qualified.
# The rest are matched only with their package written, since a bare GET() or
# curl() may well be somebody else's function. A helper from the same packages
# that only builds a request, a handle or a form body, such as curl::form_file(),
# reaches nothing: httr2's own req_body.Rd was reported for one. nslookup() asks a
# DNS server and send_mail() talks to an SMTP server, so both reach the network.
NETWORK_CALLS <- c(
  "download.file", "curl_download", "curl_fetch_memory", "curl_fetch_disk",
  "curl_fetch_stream", "multi_download"
)
NETWORK_QUALIFIED_CALLS <- list(
  curl = c(
    "curl", "curl_download", "curl_fetch_memory", "curl_fetch_disk",
    "curl_fetch_stream", "curl_upload", "multi_download", "multi_run",
    "nslookup", "send_mail"
  ),
  httr = c("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "VERB", "RETRY"),
  httr2 = c(
    "req_perform", "req_perform_parallel", "req_perform_sequential",
    "req_perform_iterative", "req_perform_stream", "req_perform_connection",
    "req_perform_promise", "req_stream"
  ),
  RCurl = c(
    "getURL", "getURI", "getURLContent", "getBinaryURL", "getForm", "postForm",
    "httpGET", "httpPOST", "httpPUT", "httpDELETE", "httpHEAD"
  )
)

# Functions that call the function they are handed: the apply family, with its
# parallel and future.apply variants, Map() and its kin, purrr's and furrr's
# mappers, do.call() and match.fun(). Naming a request function in a call to one
# of them makes the request as surely as calling it. Handed to anything else, as
# in `args(download.file)` or `class(download.file)`, or defined, as a mock is,
# it makes none.
VALUE_CALLER_RE <- paste0(
  "^(future_)?(",
  "[lsvmtre]?apply|Map|Reduce|Filter|Find|Position|do\\.call|match\\.fun|",
  "mclapply|mcmapply|mcMap|par[LS]?apply|clusterApply(LB)?|clusterMap|",
  "(map|map2|pmap|imap|lmap|walk|walk2|pwalk|iwalk)(_[a-z]+)?",
  ")$"
)

# do.call() and match.fun() with their formals. The first names the function they
# call, so a request function named in a string there is called too.
STRING_CALLERS <- list(
  do.call = c("what", "args", "quote", "envir"),
  match.fun = c("FUN", "descend")
)

# Whether a request function named as a value -- its SYMBOL, or a STR_CONST
# holding its name -- is handed to something that calls it: an argument of a
# VALUE_CALLER_RE function, the right side of magrittr's `%>%`, or, for a string,
# the function do.call() or match.fun() is asked for.
handed_to_caller <- function(node) {
  arg <- xml2::xml_parent(node)
  if (xml2::xml_name(node) == "SYMBOL") {
    before <- xml2::xml_find_first(arg, "preceding-sibling::*[not(self::COMMENT)][1]")
    if (identical(xml2::xml_text(before), "%>%")) {
      return(TRUE)
    }
  }
  parts <- call_parts(xml2::xml_parent(arg))
  if (is.null(parts) || !any(vapply(parts$args, identical, logical(1), arg))) {
    return(FALSE)
  }
  if (xml2::xml_name(node) == "SYMBOL") {
    return(grepl(VALUE_CALLER_RE, parts$fn))
  }
  formals <- STRING_CALLERS[[parts$fn]]
  !is.null(formals) && identical(matched_args(parts, formals)[[1L]], arg)
}

# The places in parsed code that make a request: a call, as its
# SYMBOL_FUNCTION_CALL node, or a request function handed on to be called, as its
# SYMBOL or STR_CONST node. `lapply(urls, download.file)`, `Map(httr::GET, urls)`,
# `do.call(download.file, args)` and `do.call("download.file", args)` call the
# function they are given, so naming it there is making the request. Only the
# functions matched bare can be named in a string, since a string names no
# package.
network_calls <- function(xml) {
  known <- unique(c(NETWORK_CALLS, unlist(NETWORK_QUALIFIED_CALLS)))
  named <- paste0("[", paste0("text() = '", known, "'", collapse = " or "), "]")
  quoted <- paste0(
    "[",
    paste0(
      "text() = '\"", NETWORK_CALLS, "\"' or text() = \"'", NETWORK_CALLS, "'\"",
      collapse = " or "
    ),
    "]"
  )
  nodes <- xml2::xml_find_all(
    xml,
    paste0(
      "//SYMBOL_FUNCTION_CALL", named, "[", NOT_MEMBER_ACCESS, "]",
      " | //SYMBOL", named, "[", NOT_MEMBER_ACCESS, "]",
      " | //STR_CONST", quoted
    )
  )
  if (length(nodes) == 0L) {
    return(nodes)
  }
  fn <- unquote_name(xml2::xml_text(nodes))
  pkg <- xml2::xml_text(
    xml2::xml_find_first(nodes, "preceding-sibling::SYMBOL_PACKAGE")
  )
  qualified <- vapply(
    seq_along(fn),
    function(i) !is.na(pkg[[i]]) && fn[[i]] %in% NETWORK_QUALIFIED_CALLS[[pkg[[i]]]],
    logical(1)
  )
  nodes <- nodes[fn %in% NETWORK_CALLS | qualified]
  keep <- vapply(
    nodes,
    function(n) {
      xml2::xml_name(n) == "SYMBOL_FUNCTION_CALL" || handed_to_caller(n)
    },
    logical(1)
  )
  nodes[keep]
}

# A condition under which an example may reach the network: a test that a
# connection is up, or an interactive session, where someone is there to see a
# failure. `capabilities("libcurl")` says only that R can make the request, not
# that it will succeed, but it is the guard many packages write and one this check
# has always accepted. A literal FALSE is the branch that never runs.
NETWORK_PROBES <- c("has_internet", "is_online")

is_network_guard <- function(node) {
  if (is_interactive_call(node) || is_false_constant(node)) {
    return(TRUE)
  }
  parts <- call_parts(node)
  if (is.null(parts)) {
    return(FALSE)
  }
  parts$fn %in% NETWORK_PROBES ||
    (parts$fn == "capabilities" &&
      any(arg_strings(parts$args) %in% c("libcurl", "http/ftp")))
}

#' Diagnose Unguarded Network Access
#'
#' Flags network access in code or examples that runs without a guard.
#'
#' An example is read as parsed R, so a function named in a comment, a string or
#' an Rd `%` comment is not a call. A request counts as guarded when it sits in
#' `\dontrun{}` or `\donttest{}`, or in the branch of an `if` whose condition
#' confines it to a connection or a session: `curl::has_internet()`,
#' `pingr::is_online()`, `capabilities("libcurl")` or `interactive()`, including
#' roxygen's `@examplesIf` with any of them. Only a guard that encloses the call
#' excuses it, and a guard kept in a variable counts only when it is assigned in
#' the same function and on every path to the test. A request function handed to
#' something that calls it, as in `lapply(urls, download.file)`,
#' `purrr::map(reqs, httr2::req_perform)`, `do.call(httr::GET, args)` or
#' `do.call("download.file", args)`, is a request too. Named anywhere else, as in
#' `args(download.file)` or a mock that redefines it, it is not. Neither is a
#' helper from a network package that only builds a request, such as
#' `curl::form_file()`.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' states that "Packages which use Internet resources should fail gracefully
#' with an informative message if the resource is not available". See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("network_examples/bad_network_example.Rd",
#'                                  show_content = FALSE)
#' lab_network_operations(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_network_operations <- function(path, verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  vignette_files <- list_included_files(
    path,
    "vignettes",
    "\\.(Rmd|qmd|md)$",
    recursive = TRUE
  )
  if (length(rd_files) == 0L && length(vignette_files) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Network operations check"
    ))
  }

  issues <- character(0)

  # The example text used to be grepped for `download.file` or `curl::`, so a name
  # in a comment or a string was a call, no guard was ever read, and the guard's
  # own `curl::has_internet()` was reported as the network access. Read the parse
  # tree instead, as the other example checks do.
  for (file in rd_files) {
    rd <- tryCatch(read_rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    ex <- extract_rd_section(rd, "\\examples")
    if (is.null(ex)) {
      next
    }
    xml <- rd_example_xml(ex)
    if (is.null(xml)) {
      next
    }
    unguarded <- Filter(
      function(call) {
        !in_hidden_block(call) && !guarded_by(call, is_network_guard)
      },
      network_calls(xml)
    )
    if (length(unguarded) > 0L) {
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
    if (!nzchar(trimws(code))) {
      next
    }
    xml <- parse_text_xml(code)
    if (is.null(xml)) {
      next
    }

    # A vignette usually guards in a chunk option or a setup chunk, such as
    # `knitr::opts_chunk$set(eval = curl::has_internet())`, which the parse tree
    # cannot tie to the chunks it governs. So a guard anywhere in the file counts.
    guards <- c("interactive", "capabilities", NETWORK_PROBES)
    guarded <- length(xml2::xml_find_all(
      xml,
      sprintf(
        "//SYMBOL_FUNCTION_CALL[%s]",
        paste0("text() = '", guards, "'", collapse = " or ")
      )
    )) >
      0L
    if (guarded) {
      next
    }

    hits <- network_calls(xml)
    if (length(hits) > 0L) {
      issues <- c(
        issues,
        paste0(
          basename(file),
          ": unguarded network access in a code chunk (",
          paste(unique(unquote_name(xml2::xml_text(hits))), collapse = ", "),
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
    "Treatment: Wrap in \\dontrun{{}}, \\donttest{{}}, or capability checks",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Network operations check")
}

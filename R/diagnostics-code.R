#' Diagnose Code Health Issues
#'
#' Runs comprehensive diagnostics on R source code to identify common CRAN
#' submission issues and coding best-practice violations.
#'
#' @param path Character. Path to the R package directory. Default: `"."`.
#' @param verbose Logical. Whether to print detailed diagnostic output.
#'   Default: `TRUE`.
#'
#' @return
#' List of named [checktor_check_result()] objects (e.g., `tf_usage`,
#' `seed_setting`) plus a `passed` named logical vector summarizing pass/fail
#' for each sub-check.
#'
#' @details
#' Each source file is parsed once with `parse(keep.source = TRUE)`; checks
#' run XPath queries against the parsed XML representation, so identifiers
#' that appear only inside string literals or comments do not false-positive.
#' Multi-line constructs (`set.seed(\n123\n)`), formula `~` versus path `~`,
#' and scope-aware patterns (an `options()` call guarded by a sibling
#' `on.exit()` in the same function body) are all handled correctly.
#'
#' @seealso [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' code_results <- diagnose_code_issues(pkg, verbose = FALSE)
#' code_results$tf_usage$passed
diagnose_code_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("Code Health Check")
  }

  if (!dir.exists(file.path(path, "R"))) {
    if (verbose) cli::cli_alert_info("No R/ directory found")
    return(list(passed = TRUE, message = "No R directory found"))
  }

  # Parse all R files once and pass the cache to each public diagnostic via
  # its hidden `parsed` argument. The closures below reference the public
  # function names symbolically, so resolution happens at call time and
  # `with_mocked_bindings` can replace any of them in tests.
  parsed <- read_r_xml(path)

  run_checks(list(
    tf_usage           = function(p, v) diagnose_tf_usage(p, v, parsed = parsed),
    seed_setting       = function(p, v) diagnose_seed_setting(p, v, parsed = parsed),
    print_cat_usage    = function(p, v) diagnose_print_cat_usage(p, v, parsed = parsed),
    option_changes     = function(p, v) diagnose_option_changes(p, v, parsed = parsed),
    home_writing       = function(p, v) diagnose_home_writing(p, v, parsed = parsed),
    temp_cleanup       = function(p, v) diagnose_temp_cleanup(p, v, parsed = parsed),
    globalenv_mod      = function(p, v) diagnose_globalenv_modification(p, v, parsed = parsed),
    installed_packages = function(p, v) diagnose_installed_packages_usage(p, v, parsed = parsed),
    warn_option        = function(p, v) diagnose_warn_option(p, v, parsed = parsed),
    software_install   = function(p, v) diagnose_software_installation(p, v, parsed = parsed),
    core_usage         = function(p, v) diagnose_core_usage(p, v, parsed = parsed),
    library_in_pkg     = function(p, v) diagnose_library_in_pkg_code(p, v, parsed = parsed),
    sys_setenv         = function(p, v) diagnose_sys_setenv_no_reset(p, v, parsed = parsed)
  ), path, verbose)
}

# Verbose output helper shared across diagnostic functions.
emit_issue_summary <- function(issues, verbose, success_msg, failure_msg,
                               treatment = NULL, max_show = 5L,
                               level = c("danger", "warning")) {
  if (!verbose) return(invisible())
  level <- match.arg(level)
  if (length(issues) == 0L) {
    cli::cli_alert_success(success_msg)
    return(invisible())
  }
  if (level == "danger") cli::cli_alert_danger(failure_msg)
  else                   cli::cli_alert_warning(failure_msg)
  cli::cli_ul(utils::head(issues, max_show))
  if (length(issues) > max_show) {
    cli::cli_text("{.emph ... and {length(issues) - max_show} more}")
  }
  if (!is.null(treatment)) cli::cli_text("{.emph {treatment}}")
}

# In the xmlparsedata XML, a call `fn(a, b)` is:
#   <expr>                                <- call expr ("outer" expr)
#     <expr>                              <- function-name expr
#       <SYMBOL_FUNCTION_CALL>fn</...>
#     </expr>
#     <OP-LEFT-PAREN>(
#     <expr><SYMBOL>a</SYMBOL></expr>     <- first positional arg
#     <OP-COMMA>,
#     <expr><SYMBOL>b</SYMBOL></expr>
#     <OP-RIGHT-PAREN>)
#   </expr>
# Named args `f(a = 1)` use SYMBOL_SUB/EQ_SUB/expr triples (children of the
# call expr, not wrapped in another expr).
# Helper: from a SYMBOL_FUNCTION_CALL position, navigate to:
#   - the call expr:           `parent::expr/parent::expr`
#   - first positional arg:    `parent::expr/following-sibling::expr[1]`
#   - any named-arg name:      `parent::expr/parent::expr/SYMBOL_SUB`

#' Diagnose `T`/`F` Usage in R Code
#'
#' Flags bare `T` / `F` symbols that should be `TRUE` / `FALSE`. Operates on
#' the parsed AST, so `T` inside string literals or comments is not flagged
#' (a long-standing source of regex false positives). Named-argument names
#' (`f(T = 1)`) and `$T` / `@T` extractions are excluded.
#'
#' @param path Character. Path to package directory.
#' @param verbose Logical. Print diagnostic messages.
#' @param parsed Internal. Pre-parsed source cache; if `NULL`, files are read
#'   from `path` on demand.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' diagnose_tf_usage(pkg, verbose = FALSE)$issues
diagnose_tf_usage <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "T/F usage check"))
  }

  xpath <- paste0(
    "//SYMBOL[(text() = 'T' or text() = 'F')",
    "  and not(parent::expr[OP-DOLLAR or OP-AT])",
    "  and not(parent::expr/preceding-sibling::*[1][self::EQ_SUB])",
    "]"
  )
  issues <- c(xpath_lints(parsed, xpath), parse_error_issues(parsed))

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No {.code T}/{.code F} usage found",
    "Found {.code T}/{.code F} usage (should use {.code TRUE}/{.code FALSE})"
  )
  checktor_check_result(passed, issues, "T/F usage check")
}

#' Diagnose Hardcoded Seed Setting
#'
#' Flags `set.seed(<numeric>)` calls. Multi-line forms are handled because
#' the check matches the call AST node, not raw text.
#'
#' @inheritParams diagnose_tf_usage
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/seed_setting_bad.R",
#'                                  show_content = FALSE)
#' diagnose_seed_setting(pkg, verbose = FALSE)$passed
diagnose_seed_setting <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Seed setting check"))
  }

  # set.seed() call whose first positional arg expression contains a numeric
  # literal (covers `set.seed(123)` and `set.seed(\n  123\n)`).
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'set.seed']",
    "/parent::expr/following-sibling::expr[1]//NUM_CONST"
  )
  issues <- xpath_lints(parsed, xpath)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No hardcoded seed setting found",
    "Found hardcoded seed setting",
    "Treatment: Add a seed parameter to allow user control"
  )
  checktor_check_result(passed, issues, "Seed setting check")
}

#' Diagnose Print/Cat Usage in Functions
#'
#' Flags `print()` / `cat()` calls not guarded by an enclosing `if()`,
#' `for()`, or `while()`. The check uses the ancestor axis, so guard
#' detection is robust regardless of formatting.
#'
#' @inheritParams diagnose_tf_usage
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/print_cat_bad.R",
#'                                  show_content = FALSE)
#' diagnose_print_cat_usage(pkg, verbose = FALSE)$passed
diagnose_print_cat_usage <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Print/cat usage check"))
  }

  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'print' or text() = 'cat'][",
    "  not(ancestor::expr[IF or FOR or WHILE])",
    "]"
  )
  issues <- xpath_lints(parsed, xpath)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No unsuppressable {.code print()}/{.code cat()} usage found",
    "Potential unsuppressable {.code print()}/{.code cat()} usage",
    "Treatment: Use {.code message()} or {.code if(verbose)} conditions"
  )
  checktor_check_result(passed, issues, "Print/cat usage check")
}

diagnose_option_changes <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Option changes check"))
  }

  # options/par/setwd call whose innermost enclosing function body does NOT
  # contain an on.exit() or any withr::local_*/with_* helper.
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'options' or text() = 'par' or text() = 'setwd'][",
    "  ", not_under_fn_with_call_xpath(c(
        "on.exit",
        "local_options", "with_options",
        "local_par",     "with_par",
        "local_dir",     "with_dir"
      )),
    "]"
  )
  issues <- xpath_lints(parsed, xpath)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Option changes appear to be properly reset",
    "Option changes without apparent reset",
    "Treatment: Use {.code on.exit()} or {.code withr::local_*}"
  )
  checktor_check_result(passed, issues, "Option changes check")
}

diagnose_home_writing <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Home writing check"))
  }

  # Each rule = (function name, first-arg STR_CONST prefix to flag, label).
  # STR_CONST text retains the surrounding quotes, hence the
  # `"<prefix>` and `'<prefix>` alternation.
  rules <- list(
    list(fn = "path.expand",   prefix = "~",           label = "path.expand('~...')"),
    list(fn = "normalizePath", prefix = "~",           label = "normalizePath('~...')"),
    list(fn = "file.path",     prefix = "~",           label = "file.path('~', ...)"),
    list(fn = "Sys.getenv",    prefix = "HOME",        label = "Sys.getenv('HOME')"),
    list(fn = "Sys.getenv",    prefix = "USERPROFILE", label = "Sys.getenv('USERPROFILE')")
  )

  issues <- character(0)
  for (r in rules) {
    xpath <- sprintf(
      "//SYMBOL_FUNCTION_CALL[text() = '%s']/parent::expr/following-sibling::expr[1]/STR_CONST[starts-with(text(), '\"%s') or starts-with(text(), \"'%s\")]",
      r$fn, r$prefix, r$prefix
    )
    issues <- c(issues, xpath_lints(parsed, xpath, label = r$label))
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No obvious home directory writing detected",
    "Potential home directory writing patterns",
    "Treatment: Verify these don't write to the user's home directory"
  )
  checktor_check_result(passed, issues, "Home writing check")
}

# Per-tempfile cleanup detection. Only scans `tests/` since R/ helpers may
# legitimately hand temp paths back to callers. A tempfile()/tempdir() call
# is "clean" if cleanup exists either (a) in the innermost enclosing function
# body, OR (b) later in the same top-level scope (handles test scripts).
diagnose_temp_cleanup <- function(path, verbose = TRUE, parsed = NULL) {
  test_dir <- file.path(path, "tests")
  if (!dir.exists(test_dir)) {
    return(checktor_check_result(TRUE, character(0), "Temp cleanup check"))
  }
  test_files <- list.files(test_dir, pattern = "\\.R$",
                           full.names = TRUE, recursive = TRUE)
  if (length(test_files) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Temp cleanup check"))
  }

  test_parsed <- setNames(lapply(test_files, parse_one_r_file), test_files)

  cleanup_funs <- c("unlink", "file.remove", "on.exit", "defer", "defer_cleanup",
                    "local_tempfile", "deferred_run")
  predicate <- paste(sprintf("text() = '%s'", cleanup_funs),
                     collapse = " or ")
  # A tempfile()/tempdir() call is "clean" if cleanup exists in any of:
  #   (a) the innermost enclosing function body (most precise),
  #   (b) the same top-level statement (handles testthat blocks like
  #       `test_that("...", { tempfile(); on.exit(...) })` where the lambda is
  #       constructed at runtime, not statically a FUNCTION node), or
  #   (c) a later top-level statement (handles top-level test scripts).
  # Only tempfile() needs explicit cleanup; tempdir() returns the session
  # temp directory which R auto-cleans at session end.
  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[text() = 'tempfile'][
       not(ancestor::expr[parent::expr/FUNCTION][1]//SYMBOL_FUNCTION_CALL[%s])
       and not(
         ancestor::expr[parent::exprlist][1]
         //SYMBOL_FUNCTION_CALL[%s]
       )
       and not(
         ancestor::expr[parent::exprlist][1]
         /following-sibling::expr
         //SYMBOL_FUNCTION_CALL[%s]
       )
     ]",
    predicate, predicate, predicate
  )
  issues <- xpath_lints(test_parsed, xpath)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Temp file usage appears to include cleanup",
    "Temp files without apparent cleanup",
    "Treatment: Add cleanup (unlink, on.exit, withr::local_tempfile, ...)"
  )
  checktor_check_result(passed, issues, "Temp cleanup check")
}

diagnose_globalenv_modification <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0),
                                 "GlobalEnv modification check"))
  }

  xpath_op <- "//LEFT_ASSIGN[text() = '<<-'] | //RIGHT_ASSIGN[text() = '->>']"
  xpath_globalenv_ref <- paste0(
    "//SYMBOL[text() = '.GlobalEnv'] | ",
    "//SYMBOL_FUNCTION_CALL[text() = 'globalenv']"
  )

  issues <- c(
    xpath_lints(parsed, xpath_op),
    xpath_lints(parsed, xpath_globalenv_ref)
  )

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No {.code .GlobalEnv} modification detected",
    "Potential {.code .GlobalEnv} modification",
    "Treatment: Avoid modifying the global environment"
  )
  checktor_check_result(passed, issues, "GlobalEnv modification check")
}

diagnose_installed_packages_usage <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0),
                                 "installed.packages() usage check"))
  }
  issues <- undesirable_function_check(parsed, "installed.packages",
                                       label = FALSE)
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No {.code installed.packages()} usage found",
    "{.code installed.packages()} usage found",
    "Treatment: Use {.code requireNamespace()} or {.code find.package()} instead"
  )
  checktor_check_result(passed, issues, "installed.packages() usage check")
}

# `options(..., warn = -1)` in any form: standalone, multi-arg, or wrapped in
# withr::local_options/with_options. Anchors on the named-arg SYMBOL_SUB
# (a child of the call expr), then checks its value expr for `-1`.
diagnose_warn_option <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Warn option check"))
  }

  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[",
    "  text() = 'options' or text() = 'local_options' or text() = 'with_options'",
    "]/parent::expr/parent::expr/SYMBOL_SUB[text() = 'warn'][",
    "  following-sibling::expr[1][OP-MINUS and expr/NUM_CONST[text() = '1']]",
    "]"
  )
  issues <- xpath_lints(parsed, xpath)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No {.code options(warn = -1)} usage found",
    "{.code options(warn = -1)} usage found",
    "Treatment: Use {.code suppressWarnings()} for a narrow scope instead"
  )
  checktor_check_result(passed, issues, "Warn option check")
}

diagnose_software_installation <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0),
                                 "Software installation check"))
  }

  direct_funs <- c("install.packages", "pkg_install", "install_local",
                   "install_github", "install_url", "install_bitbucket",
                   "install_cran", "install_dev", "install_git",
                   "install_gitlab", "install_svn", "install_version")
  issues <- undesirable_function_check(parsed, direct_funs, label = TRUE)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No software installation in functions detected",
    "Potential software installation in functions",
    "Treatment: Packages should not install other packages at runtime",
    max_show = 3L
  )
  checktor_check_result(passed, issues, "Software installation check")
}

# Parallelism calls without an explicit per-call core bound. Looks for
# mclapply/parLapply/makeCluster/detectCores whose enclosing call has no
# `mc.cores =` named argument.
diagnose_core_usage <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Core usage check"))
  }

  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[",
    "  text() = 'mclapply' or text() = 'parLapply' or text() = 'makeCluster'",
    "  or text() = 'detectCores'",
    "][",
    "  not(parent::expr/parent::expr/SYMBOL_SUB[text() = 'mc.cores'])",
    "]"
  )
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    paste0(basename(file), ":",
           xml2::xml_attr(nodes, "line1"),
           " (", xml2::xml_text(nodes), "())")
  })

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Core usage appears limited appropriately",
    "Potential unlimited core usage",
    "Treatment: Limit to 2 cores on CRAN (e.g., {.code mc.cores = 2L})",
    max_show = 3L
  )
  checktor_check_result(passed, issues, "Core usage check")
}

# library() / require() in package R/ code is almost always a mistake -
# package dependencies belong in DESCRIPTION Imports/Depends and should be
# referenced via NAMESPACE imports or pkg::fn calls.
diagnose_library_in_pkg_code <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "library() in pkg code check"))
  }
  issues <- undesirable_function_check(parsed,
                                       c("library", "require"),
                                       label = TRUE)
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No {.code library()}/{.code require()} calls in package code",
    "{.code library()}/{.code require()} calls in package code",
    "Treatment: Declare deps in DESCRIPTION Imports and use {.code pkg::fn()}"
  )
  checktor_check_result(passed, issues, "library() in pkg code check")
}

# Sys.setenv() without on.exit()/withr cleanup in the same function body.
# Mirrors diagnose_option_changes for environment variables.
diagnose_sys_setenv_no_reset <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Sys.setenv reset check"))
  }
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'Sys.setenv'][",
    "  ", not_under_fn_with_call_xpath(c(
        "on.exit",
        "Sys.unsetenv",
        "local_envvar", "with_envvar"
      )),
    "]"
  )
  issues <- xpath_lints(parsed, xpath)
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "{.code Sys.setenv()} calls appear to be reset",
    "{.code Sys.setenv()} without apparent reset",
    "Treatment: Use {.code on.exit(Sys.unsetenv(...))} or {.code withr::local_envvar()}"
  )
  checktor_check_result(passed, issues, "Sys.setenv reset check")
}

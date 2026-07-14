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
#' summary(code_results)   # per-category overview
#' issues(code_results)    # the issues found
diagnose_code_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("Code Health Check")
  }

  if (!dir.exists(file.path(path, "R"))) {
    if (verbose) cli::cli_alert_info("No R/ directory found")
    out <- list(passed = TRUE, message = "No R directory found")
    class(out) <- "checktor_category_result"
    return(out)
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
#' # show_content defaults to TRUE, so the offending file prints first
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R")
#' issues(diagnose_tf_usage(pkg, verbose = FALSE))
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
#' diagnose_seed_setting(pkg, verbose = FALSE)   # prints PASSED/FAILED
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
#' detection is robust regardless of formatting. Calls inside S3 `print.*`
#' and `format.*` methods are exempt, since `cat()` is the required idiom
#' there (base R's own `print.default()` / `print.lm()` use it).
#'
#' @inheritParams diagnose_tf_usage
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/print_cat_bad.R",
#'                                  show_content = FALSE)
#' diagnose_print_cat_usage(pkg, verbose = FALSE)
diagnose_print_cat_usage <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Print/cat usage check"))
  }

  # Only a VERBOSITY gate is a guard. The previous rule was
  # `not(ancestor::expr[IF or FOR or WHILE])`, which exempted a call under *any*
  # enclosing control flow, so `if (x > 0) print("debug")` and
  # `for (i in xs) print(i)` were silently let through. Those are exactly the
  # unsuppressable output we are looking for.
  # Names packages actually use for an output-control flag. `show` and `echo` are
  # here because checktor's own example_diagnose_scenario() gates its cat() behind
  # `if (show_content)`, and any package with show_*/echo/trace flags would
  # otherwise be flagged for correctly guarding its output.
  verbosity_words <- c("verbose", "quiet", "debug", "silent",
                       "show", "echo", "trace", "progress")
  lower <- "translate(text(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')"
  verbosity <- paste(
    sprintf("contains(%s, '%s')", lower, verbosity_words),
    collapse = " or "
  )
  # The condition of an `if` is its first child <expr>; the body follows it.
  guarded <- sprintf("ancestor::expr[IF][expr[1][.//SYMBOL[%s]]]", verbosity)

  # cat()/print() are the required idiom inside S3 output methods. base R's own
  # print.default/print.lm/format.* use cat(), and the CRAN policy sentence that
  # states the rule ends with the literal parenthetical
  # "(except for print, summary, interactive functions)" -- so summary.* counts too.
  s3_method <- paste0(
    "ancestor::expr[FUNCTION][",
    "  parent::*/expr[1]/SYMBOL[",
    "    starts-with(text(), 'print.') or starts-with(text(), 'format.')",
    "    or starts-with(text(), 'summary.')",
    "  ]",
    "]"
  )

  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'print' or text() = 'cat'][",
    "  not(", guarded, ")",
    "  and not(", s3_method, ")",
    "]"
  )

  # An S3 print method may delegate its output to a helper. The helper is not
  # itself a method, so the XPath above cannot see that its output is only ever
  # reachable through one. Drop hits inside a function whose only callers are S3
  # output methods -- behaviourally identical to inlining the helper into them.
  delegates <- s3_output_delegates(parsed)
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    keep <- !vapply(nodes, function(n) {
      enclosing_function_name(n) %in% delegates
    }, logical(1))
    nodes <- nodes[keep]
    if (length(nodes) == 0L) return(character(0))
    paste0(basename(file), ":", xml2::xml_attr(nodes, "line1"))
  })

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
  #
  # There is a second legitimate shape. options(), par() and setwd() all return
  # their previous value, so a setter that captures it and hands it back is
  # honouring the base R contract and leaves the caller able to restore:
  #
  #     configure <- function(x) { old <- options(digits = x); invisible(old) }
  #
  # The real leak is a bare `options(digits = 3)` whose old value is discarded,
  # so a call that sits on the right-hand side of an assignment is exempt.
  captured <- paste0(
    "not(parent::expr/parent::expr/preceding-sibling::*[1]",
    "[self::LEFT_ASSIGN or self::EQ_ASSIGN])"
  )
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'options' or text() = 'par' or text() = 'setwd'][",
    "  ", not_under_fn_with_call_xpath(c(
        "on.exit",
        "local_options", "with_options",
        "local_par",     "with_par",
        "local_dir",     "with_dir"
      )),
    "  and ", captured,
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

  # The CRAN rule is about WRITING into the user's filespace. Earlier versions of
  # this check inspected only path.expand()/normalizePath()/file.path()/Sys.getenv(),
  # which are all *reads*: it flagged `Sys.getenv("HOME")` (which writes nothing)
  # while missing `writeLines(x, "~/leaked.txt")`, the actual violation. So flag a
  # WRITE whose destination resolves to the user's home.
  write_funs <- c("write.csv", "write.csv2", "write.table", "writeLines",
                  "saveRDS", "save", "file.create", "dir.create", "file.copy",
                  "file.rename", "sink", "png", "pdf", "jpeg", "ggsave")
  write_pred <- paste(sprintf("text() = '%s'", write_funs), collapse = " or ")

  # An argument resolves to the user's home if it contains a `~`-rooted literal
  # anywhere, or reads HOME / USERPROFILE from the environment. STR_CONST text
  # retains its quotes, hence the "~ / '~ alternation.
  home_pred <- paste0(
    ".//STR_CONST[starts-with(text(), '\"~') or starts-with(text(), \"'~\")]",
    " or .//SYMBOL_FUNCTION_CALL[text() = 'Sys.getenv']/parent::expr",
    "/following-sibling::expr[1]/STR_CONST[",
    "  starts-with(text(), '\"HOME') or starts-with(text(), \"'HOME\")",
    "  or starts-with(text(), '\"USERPROFILE') or starts-with(text(), \"'USERPROFILE\")",
    "]"
  )

  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[%s][parent::expr/parent::expr[%s]]",
    write_pred, home_pred
  )
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    paste0(basename(file), ":", xml2::xml_attr(nodes, "line1"),
           " (", xml2::xml_text(nodes), "() writes under the home directory)")
  })

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No home directory writing detected",
    "Writes into the user's home directory",
    "Treatment: Write to tempdir(), or to a path the caller supplies"
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

  # `<<-` does NOT mean ".GlobalEnv". It walks the enclosing environments and
  # assigns in the first one where the name is already bound, only reaching
  # .GlobalEnv when the name is bound nowhere else. So a `<<-` is a global write
  # only when its target binds in neither an enclosing function nor the package
  # namespace. Flagging every `<<-` false-positives on the two commonest correct
  # uses: a closure updating a variable in its parent frame, and the package-level
  # memoisation idiom (`.cache <<- ...`).
  #
  # The `.GlobalEnv` / globalenv() *reference* rule is gone entirely. It flagged
  # pure reads such as `exists(nm, envir = globalenv())`, and the one write form
  # that matters, `assign(x, envir = .GlobalEnv)`, is already an R CMD check NOTE
  # ("Found the following assignments to the global environment"), so duplicating
  # it here would only add noise.
  pkg_level <- package_level_names(parsed)

  issues <- character(0)
  for (p in parsed) {
    if (!is.null(p$error) || is.null(p$xml)) next
    ops <- xml2::xml_find_all(
      p$xml,
      "//LEFT_ASSIGN[text() = '<<-'] | //RIGHT_ASSIGN[text() = '->>']"
    )
    for (op in ops) {
      target <- superassign_target(op)
      if (!nzchar(target)) next
      if (target %in% pkg_level) next          # package-level binding, e.g. a cache
      if (binds_in_enclosing_function(op, target)) next
      issues <- c(issues, paste0(
        basename(p$file), ":", xml2::xml_attr(op, "line1"), " (", target, ")"
      ))
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "No {.code .GlobalEnv} modification detected",
    "Assignment reaches the global environment",
    "Treatment: Bind the name in the package or an enclosing function, or use a local cache environment"
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

  # CRAN's rule is: "If running a package uses multiple threads/cores it must
  # never use more than two simultaneously." The prohibition is on USING more
  # than two, not on calling detectCores().
  #
  # The old rule required an `mc.cores` named argument on the call itself. But
  # `mc.cores` is an argument of mclapply()/pvec() ONLY: detectCores() takes no
  # arguments at all, makeCluster() takes `spec`, parLapply() takes a cluster. So
  # detectCores() could never satisfy it and was flagged 100% of the time, while
  # `makeCluster(2L)` -- explicitly CRAN-compliant -- was flagged too.
  #
  # What actually matters is the WORKER COUNT handed to each framework, measured
  # under `_R_CHECK_LIMIT_CORES_=TRUE` (the CRAN check environment):
  #
  #     parallel::detectCores()        -> 12   ignores the CRAN limit
  #     parallelly::availableCores()   ->  2   auto-caps
  #     future::availableCores()       ->  2   auto-caps
  #
  # So a worker count is risky when it is a literal above 2, or is derived from
  # detectCores(). It is safe when it comes from availableCores(), is capped at 2,
  # or sits in a function that guards on the CRAN environment variables.
  issues <- character(0)
  for (p in parsed) {
    if (!is.null(p$error) || is.null(p$xml)) next
    calls <- xml2::xml_find_all(
      p$xml,
      sprintf("//SYMBOL_FUNCTION_CALL[%s]",
              paste(sprintf("text() = '%s'", names(PARALLEL_WORKER_ARG)),
                    collapse = " or "))
    )
    for (cl in calls) {
      fn <- xml2::xml_text(cl)
      w <- worker_count_expr(cl, PARALLEL_WORKER_ARG[[fn]])
      if (is.null(w)) next                      # no explicit count: defaults are safe
      if (!worker_count_is_risky(w)) next
      if (has_cran_core_guard(cl)) next
      issues <- c(issues, paste0(
        basename(p$file), ":", xml2::xml_attr(cl, "line1"),
        " (", fn, "() worker count is unbounded)"
      ))
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues, verbose,
    "Core usage is bounded for CRAN",
    "Worker count may exceed the two cores CRAN allows",
    "Treatment: Use {.code parallelly::availableCores()}, which caps at 2 under {.envvar _R_CHECK_LIMIT_CORES_}, or guard the count yourself",
    max_show = 3L
  )
  checktor_check_result(passed, issues, "Core usage check")
}

# Worker-count argument per parallel framework. A name means a named argument;
# `1L` means the first positional argument.
PARALLEL_WORKER_ARG <- list(
  # parallel / snow
  mclapply            = "mc.cores",
  mcmapply            = "mc.cores",
  pvec                = "mc.cores",
  makeCluster         = 1L,
  makePSOCKcluster    = 1L,
  makeForkCluster     = 1L,
  # foreach backends
  registerDoParallel  = "cores",
  registerDoMC        = "cores",
  registerDoSNOW      = 1L,
  # future / furrr (furrr inherits the plan, so plan() is the control point)
  plan                = "workers",
  # mirai
  daemons             = 1L,
  # RcppParallel
  setThreadOptions    = "numThreads",
  # data.table
  setDTthreads        = 1L,
  # BiocParallel
  MulticoreParam      = "workers",
  SnowParam           = "workers"
)

# The expression supplying the worker count for a call, or NULL when none is
# given (the framework defaults are all CRAN-safe).
worker_count_expr <- function(call_node, arg) {
  if (is.character(arg)) {
    e <- xml2::xml_find_first(
      call_node,
      sprintf(
        "parent::expr/parent::expr/SYMBOL_SUB[text() = '%s']/following-sibling::expr[1]",
        arg
      )
    )
  } else {
    # First positional argument. A named argument's value is also an <expr>
    # sibling, so require that it not be preceded by an EQ_SUB.
    e <- xml2::xml_find_first(
      call_node,
      "parent::expr/following-sibling::expr[1][not(preceding-sibling::*[1][self::EQ_SUB])]"
    )
  }
  if (inherits(e, "xml_missing")) NULL else e
}

# A worker count is risky when it is a numeric literal above 2, or is derived
# from detectCores(). availableCores() already caps itself at 2 under the CRAN
# check environment, so it is safe.
worker_count_is_risky <- function(w) {
  if (length(xml2::xml_find_all(w, ".//SYMBOL_FUNCTION_CALL[text() = 'availableCores']"))) {
    return(FALSE)
  }
  if (length(xml2::xml_find_all(w, ".//SYMBOL_FUNCTION_CALL[text() = 'detectCores']"))) {
    return(TRUE)
  }
  nums <- xml2::xml_find_all(w, "descendant-or-self::NUM_CONST")
  if (length(nums) == 1L && length(xml2::xml_find_all(w, ".//SYMBOL_FUNCTION_CALL")) == 0L) {
    n <- suppressWarnings(as.numeric(sub("L$", "", xml2::xml_text(nums))))
    return(!is.na(n) && n > 2)
  }
  FALSE   # a bare variable: not resolvable statically, so do not guess
}

# TRUE when the enclosing function caps cores for CRAN, i.e. it mentions
# _R_CHECK_LIMIT_CORES_ or NOT_CRAN. This is the guard both logitr and cbcTools
# implement, and it is byte-for-byte R's own parallel:::.check_ncores predicate.
has_cran_core_guard <- function(call_node) {
  hits <- xml2::xml_find_all(
    call_node,
    paste0(
      "ancestor::expr[FUNCTION]//STR_CONST[",
      "  contains(text(), '_R_CHECK_LIMIT_CORES_') or contains(text(), 'NOT_CRAN')",
      "]"
    )
  )
  length(hits) > 0L
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

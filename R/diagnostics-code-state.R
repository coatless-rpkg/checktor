# Code checks for changes to global state: the seed, options, environment
# variables and the global environment.

#' Diagnose Hardcoded Seed Setting
#'
#' Flags `set.seed(<numeric>)` calls. Multi-line forms are handled because
#' the check matches the call AST node, not raw text.
#'
#' @inheritParams lab_tf_usage
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' asks a package not to modify the user's workspace, and `set.seed()` writes
#' `.Random.seed` there, changing the random-number stream for the rest of the
#' session. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/seed_setting_bad.R",
#'                                  show_content = FALSE)
#' lab_seed_setting(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_seed_setting <- function(path = ".", verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("seed_setting")))
  }

  # set.seed() call whose first positional arg expression contains a numeric
  # literal (covers `set.seed(123)` and `set.seed(\n  123\n)`).
  # `set.seed(123)` inside `if (FALSE)` can never execute, so it can never mutate
  # the user's RNG state, which is the entire harm this check polices.
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'set.seed']",
    "[not(ancestor::expr[IF][expr[1][count(*) = 1][NUM_CONST[text() = 'FALSE'] or SYMBOL[text() = 'FALSE']]])]",
    "/parent::expr/following-sibling::expr[1]//NUM_CONST"
  )
  report_check(
    xpath_lints(parsed, xpath),
    verbose,
    check_label("seed_setting"),
    "No hardcoded seed setting found",
    "Found hardcoded seed setting",
    paste("Treatment:", treatments$seed_setting$treatment)
  )
}

#' Diagnose Unrestored Option Changes
#'
#' Flags a call to `options()`, `par()` or `setwd()` that changes the user's
#' session state without restoring it.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Change of Options, Graphical Parameters and Working Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory),
#' which asks that a function restore any `options()`, `par()` graphics parameters,
#' or working directory it changes, using `on.exit()`. No clause in the Repository
#' Policy or Writing R Extensions states it, yet it is among the most common reasons
#' a package is sent back, because a function that quietly runs `options(digits = 3)`
#' and returns has changed how the rest of the session behaves. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#'
#' @section Exemptions:
#' Two shapes leak nothing and are exempt. A setter that captures the old value and
#' hands it back, as in `old <- options(...); invisible(old)`, honours the base R
#' contract and lets the caller restore. And an option in the package's own
#' namespace, written `options(<PackageName>.key = ...)`, is the package managing
#' its own configuration rather than the user's, so a deliberate session preference
#' like `options(mypkg.threshold = 5)` is fine. If you keep a user setting for the
#' session, give it a namespaced name rather than a bare global one, and restore a
#' genuinely temporary change with `on.exit(options(old))`.
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
#' pkg <- example_diagnose_scenario("code_examples/option_changes_bad.R",
#'                                  show_content = FALSE)
#' lab_option_changes(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_option_changes <- function(path = ".", verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("option_changes")))
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

  # And the check must first establish that the call CHANGES anything at all.
  # options() and par() both read AND write, and the old rule could not tell the
  # difference:
  #
  #   par("usr")[3]            <- a READ. zoo does this to get plot coordinates.
  #   options("digits")        <- a READ.
  #   options(old)             <- a RESTORE, the documented counterpart to
  #                               `old <- options(...)`. withr's reset_options()
  #                               is literally `function(old) options(old)`, and
  #                               checktor reported withr's own CLEANUP function
  #                               as an unrestored change.
  #   options(digits = 3)      <- a WRITE. This is the violation.
  #
  # A NAMED argument is what makes it a write. An unnamed one is a read or a
  # restore, and neither is something we can call a leak. setwd() is exempt from
  # this rule: it takes a bare path and always writes.
  # A package setting an option in ITS OWN namespace is managing its own state, not
  # the user's. CRAN's concern is a package disturbing options that other code
  # depends on. data.table toggles `datatable.verbose`, cli sets `cli.*`, knitr sets
  # `knitr.*`; none of that touches anyone else.
  # data.table names its option `datatable.verbose`, with the dot dropped from the
  # package name, so both spellings have to count as "its own".
  own <- own_option_prefix(path)
  own_option <- if (nzchar(own)) {
    prefixes <- unique(c(own, gsub(".", "", own, fixed = TRUE)))
    sprintf(
      " and not(parent::expr/parent::expr/SYMBOL_SUB[%s])",
      paste(sprintf("starts-with(text(), '%s.')", prefixes), collapse = " or ")
    )
  } else {
    ""
  }
  sets_something <- paste0(
    "(text() = 'setwd'",
    " or parent::expr/parent::expr/SYMBOL_SUB)",
    own_option
  )
  # A setwd()/options()/par() inside a function handed to a SUBPROCESS runner runs
  # in a child R process and cannot touch the user's session: the child exits and
  # takes its working directory and options with it. aisdk's `callr::r(function()
  # { setwd(wd); ... })` is the canonical shape.
  in_subprocess <- sprintf(
    "not(ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[%s]])",
    xp_text_in(c("r", "r_bg", "r_session", "rcmd", "callr"))
  )
  # A function factored out as an on.exit() restore handler -- registered by the
  # caller as `on.exit(restore_par(op))` -- is doing the restoring, so its own
  # par()/options() writes are the restore, not a leak. Its body holds no on.exit,
  # which is why the guard above cannot see it. paintr's restore_par() is exactly
  # this shape.
  not_restore_handler <- not_on_exit_handler_xpath(on_exit_handler_names(
    parsed
  ))
  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[%s][%s]",
    xp_text_in(c("options", "par", "setwd")),
    paste(
      sets_something,
      not_under_fn_with_call_xpath(c(
        "on.exit",
        "local_options",
        "with_options",
        "local_par",
        "with_par",
        "local_dir",
        "with_dir"
      )),
      in_subprocess,
      not_restore_handler,
      captured,
      sep = " and "
    )
  )

  report_check(
    xpath_lints(parsed, xpath),
    verbose,
    check_label("option_changes"),
    "Option changes appear to be properly reset",
    "Option changes without apparent reset",
    paste("Treatment:", treatments$option_changes$treatment)
  )
}

#' Diagnose Writes to the Global Environment
#'
#' Flags a `<<-` whose target binds in neither an enclosing function nor the package, and so reaches `.GlobalEnv`. A closure updating its parent, or a package-level cache, is not flagged.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' states that "Packages should not modify the global environment (user's
#' workspace)." See
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
#' pkg <- example_diagnose_scenario("code_examples/globalenv_bad.R",
#'                                  show_content = FALSE)
#' lab_globalenv_mod(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_globalenv_mod <- function(
  path = ".",
  verbose = TRUE,
  parsed = NULL
) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("globalenv_mod")))
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

  # A `<<-` inside a setRefClass()/R6Class()/setClass() body is FIELD or PRIVATE
  # assignment, not a global write: it is the documented way an RC method updates
  # its object's own field, and R6's active-binding setters use it too. chapensk's
  # Reference Class alone produced 52 findings this way.
  xpath <- sprintf(
    "(//LEFT_ASSIGN[text() = '<<-'] | //RIGHT_ASSIGN[text() = '->>'])[not(ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[%s]])]",
    xp_text_in(c("setRefClass", "R6Class", "setClass"))
  )
  reaches_global <- function(op) {
    target <- superassign_target(op)
    # A package-level binding, such as a cache, or one in an enclosing function.
    # And a function stored into a container gets its closure environment at run
    # time, so we cannot see where its `<<-` lands. Do not guess.
    nzchar(target) &&
      !target %in% pkg_level &&
      !binds_in_enclosing_function(op, target) &&
      !in_container_assigned_function(op)
  }
  issues <- xpath_filter(parsed, xpath, reaches_global, function(file, ops) {
    targets <- vapply(ops, superassign_target, character(1))
    line_hits(file, ops, paste0(" (", targets, ")"))
  })

  report_check(
    issues,
    verbose,
    check_label("globalenv_mod"),
    "No {.code .GlobalEnv} modification detected",
    "Assignment reaches the global environment",
    paste("Treatment:", treatments$globalenv_mod$treatment)
  )
}

# `options(..., warn = -1)` in any form: standalone, multi-arg, or wrapped in
# withr::local_options/with_options. Anchors on the named-arg SYMBOL_SUB
# (a child of the call expr), then checks its value expr for `-1`.
#' Diagnose Changes to options(warn=)
#'
#' Flags a change to `options(warn = )` that is not restored.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Setting options(warn = -1)](https://contributor.r-project.org/cran-cookbook/code_issues.html#setting-optionswarn--1).
#' Suppressing warnings for the rest of the session hides them from everything that
#' runs afterwards, so restore the previous value via `on.exit()`. See
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
#' pkg <- example_diagnose_scenario("code_examples/option_changes_bad.R",
#'                                  show_content = FALSE)
#' lab_warn_option(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_warn_option <- function(path = ".", verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("warn_option")))
  }

  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[",
    xp_text_in(c("options", "local_options", "with_options")),
    "]/parent::expr/parent::expr/SYMBOL_SUB[text() = 'warn'][",
    "  following-sibling::expr[1][OP-MINUS and expr/NUM_CONST[text() = '1']]",
    "]"
  )

  report_check(
    xpath_lints(parsed, xpath),
    verbose,
    check_label("warn_option"),
    "No {.code options(warn = -1)} usage found",
    "{.code options(warn = -1)} usage found",
    paste("Treatment:", treatments$warn_option$treatment)
  )
}

# Sys.setenv() without on.exit()/withr cleanup in the same function body.
# Mirrors lab_option_changes for environment variables.
#' Diagnose Unrestored Environment Variables
#'
#' Flags `Sys.setenv()` with no matching cleanup in the same function.
#'
#' @section Source:
#' No clause names environment variables, but they are session state exactly as
#' `options()` are, so the same restore-on-exit requirement applies. The CRAN
#' Cookbook states it for options under
#' [Change of Options, Graphical Parameters and Working Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory).
#' See
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
#' pkg <- example_diagnose_scenario("code_examples/sys_setenv_bad.R",
#'                                  show_content = FALSE)
#' lab_sys_setenv(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_sys_setenv <- function(path = ".", verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("sys_setenv")))
  }
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'Sys.setenv'][",
    "  ",
    not_under_fn_with_call_xpath(c(
      "on.exit",
      "Sys.unsetenv",
      "local_envvar",
      "with_envvar"
    )),
    "]"
  )
  # A setter that captures the prior state and hands it back is participating in a
  # restore contract, not leaking: the caller restores. This is how withr's
  # set_path()/set_envvar() are built, and it is the same base-R contract
  # option_changes already honours, just written across statements because
  # Sys.setenv() returns TRUE rather than the old value.
  issues <- xpath_filter(parsed, xpath, function(n) {
    !enclosing_fn_returns_capture(n)
  })
  report_check(
    issues,
    verbose,
    check_label("sys_setenv"),
    "{.code Sys.setenv()} calls appear to be reset",
    "{.code Sys.setenv()} without apparent reset",
    paste("Treatment:", treatments$sys_setenv$treatment)
  )
}

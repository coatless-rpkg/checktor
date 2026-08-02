# Runtime registry of user-supplied checks.
#
# checktor's built-in checks are hard-coded into each diagnose_<category>_issues()
# function. This registry lets a downstream package or script add its own check to
# a checktor() run without editing checktor's source: register_check() records a
# function, its category, and its severity tier, and the category functions append
# the registry's entries to their own list. State is session-scoped and lives in
# this internal environment, never in .GlobalEnv, so it does not outlive the R
# session or trip checktor's own policy checks.
.checktor_registry <- new.env(parent = emptyenv())

CHECK_CATEGORIES <- c(
  "code",
  "description",
  "documentation",
  "general",
  "policy"
)

#' Register a Custom Check with `checktor()`
#'
#' Adds a check of your own to every subsequent [checktor()] run without editing
#' checktor's source. It joins the panel its category already runs, appears in
#' [issues()], [tidy()] and the printed report, and counts toward the verdict at
#' the severity tier you declare.
#'
#' A registered check joins one of the five built-in categories. There is no way
#' to add a category of your own, so pick the panel your check belongs to.
#'
#' @param name Character. The check's key, used in results and reports. Must not
#'   clash with a built-in check name. Naming the function `lab_<name>()` keeps it
#'   consistent with the built-in checks, where the two always match.
#' @param fn A function returning a [checktor_check_result()], the same shape as
#'   any `lab_*` check. It is called as `fn(path, verbose)`. If it also
#'   declares a `parsed` argument (for `code` and `policy` checks) or a `desc`
#'   argument (for `description` checks), checktor forwards its shared parse cache
#'   so the check does not re-read the sources.
#' @param category Character. Which category the check joins: one of `"code"`,
#'   `"description"`, `"documentation"`, `"general"`, `"policy"`.
#' @param severity Character. The tier the check reports at: one of
#'   `"robustness"` (default), `"policy"`, or `"opinion"`. This decides whether a
#'   finding counts against a clean bill of health under `checktor()`'s `severity`
#'   argument.
#'
#' @return Invisibly, `name`.
#' @seealso [unregister_check()], [registered_checks()], [checktor()]
#' @export
#' @examples
#' # A house rule: flag any call to a banned helper.
#' lab_no_banned <- function(path, verbose = TRUE, parsed = NULL) {
#'   if (is.null(parsed)) parsed <- read_r_xml(path)
#'   issues <- undesirable_function_check(parsed, "banned_helper")
#'   checktor_check_result(length(issues) == 0L, issues, "no banned_helper()")
#' }
#' register_check("no_banned", lab_no_banned,
#'                category = "code", severity = "policy")
#'
#' registered_checks()
#' unregister_check("no_banned")
register_check <- function(
  name,
  fn,
  category = CHECK_CATEGORIES,
  severity = c("robustness", "policy", "opinion")
) {
  category <- match.arg(category)
  severity <- match.arg(severity)
  if (
    !is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)
  ) {
    cli::cli_abort("{.arg name} must be a single non-empty string.")
  }
  if (!is.function(fn)) {
    cli::cli_abort(
      "{.arg fn} must be a function returning a {.cls checktor_check_result}."
    )
  }
  # "passed" is the summary slot every category result carries, so a check may
  # not claim it, and a built-in name would shadow a shipped check.
  if (name %in% c("passed", names(CHECK_SEVERITY))) {
    cli::cli_abort(c(
      "{.val {name}} is a reserved or built-in check name.",
      i = "Choose a different name for your custom check."
    ))
  }
  if (exists(name, envir = .checktor_registry, inherits = FALSE)) {
    cli::cli_alert_info("Replacing already-registered check {.val {name}}.")
  }
  .checktor_registry[[name]] <- list(
    fn = fn,
    category = category,
    severity = severity
  )
  invisible(name)
}

#' Remove Registered Checks
#'
#' Drops checks added with [register_check()]. With no argument, clears the whole
#' registry.
#'
#' @param name Character vector of check names to remove, or `NULL` (the default)
#'   to remove every registered check.
#'
#' @return Invisibly, `NULL`.
#' @seealso [register_check()], [registered_checks()]
#' @export
#' @examples
#' register_check("tmp", function(path, verbose = TRUE) {
#'   checktor_check_result(TRUE, character(0), "noop")
#' })
#' unregister_check("tmp")
#' registered_checks()
unregister_check <- function(name = NULL) {
  if (!is.null(name) && !is.character(name)) {
    cli::cli_abort("{.arg name} must be a character vector or {.code NULL}.")
  }
  if (is.null(name)) {
    rm(
      list = ls(.checktor_registry, all.names = TRUE),
      envir = .checktor_registry
    )
    return(invisible(NULL))
  }
  present <- name[vapply(
    name,
    exists,
    logical(1),
    envir = .checktor_registry,
    inherits = FALSE
  )]
  if (length(present)) {
    rm(list = present, envir = .checktor_registry)
  }
  invisible(NULL)
}

#' List Registered Checks
#'
#' Reports the checks currently added with [register_check()].
#'
#' @return A data frame with columns `check`, `category`, and `severity`, one row
#'   per registered check (zero rows if none are registered).
#' @seealso [register_check()], [unregister_check()]
#' @export
#' @examples
#' registered_checks()
registered_checks <- function() {
  nms <- ls(.checktor_registry, all.names = TRUE, sorted = TRUE)
  if (length(nms) == 0L) {
    return(data.frame(
      check = character(0),
      category = character(0),
      severity = character(0),
      stringsAsFactors = FALSE
    ))
  }
  do.call(
    rbind,
    lapply(nms, function(nm) {
      e <- .checktor_registry[[nm]]
      data.frame(
        check = nm,
        category = e$category,
        severity = e$severity,
        stringsAsFactors = FALSE
      )
    })
  )
}

# Build run_checks-compatible closures for the registered checks of one category.
# `...` carries the category's shared cache (parsed = <xml> for code and policy,
# desc = <dcf> for description). A registered function receives a cache argument
# only if it declares one, so a simple (path, verbose) check just works.
registered_checks_for <- function(category, ...) {
  cache <- list(...)
  nms <- ls(.checktor_registry, all.names = TRUE, sorted = TRUE)
  out <- list()
  for (nm in nms) {
    e <- .checktor_registry[[nm]]
    if (!identical(e$category, category)) {
      next
    }
    extra <- cache[names(cache) %in% names(formals(e$fn))]
    out[[nm]] <- local({
      fn_local <- e$fn
      extra_local <- extra
      nm_local <- nm
      function(p, v) {
        res <- do.call(fn_local, c(list(p, v), extra_local))
        if (!inherits(res, "checktor_check_result")) {
          cli::cli_abort(
            "Registered check {.val {nm_local}} must return a {.cls checktor_check_result}."
          )
        }
        res
      }
    })
  }
  out
}

# The tier of a registered check, or NA if the name is not registered.
registered_severity <- function(name) {
  vapply(
    name,
    function(nm) {
      if (exists(nm, envir = .checktor_registry, inherits = FALSE)) {
        .checktor_registry[[nm]]$severity
      } else {
        NA_character_
      }
    },
    character(1),
    USE.NAMES = FALSE
  )
}

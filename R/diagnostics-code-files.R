# Code checks for writes to the user's home directory and for temporary files
# left behind.

#' Diagnose Writes to the User's Home Directory
#'
#' Flags a write whose destination resolves to `~` or `$HOME`.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' states that "Packages should not write in the user's home filespace ... nor
#' anywhere else on the file system apart from the R session's temporary
#' directory". See
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
#' pkg <- example_diagnose_scenario("code_examples/home_writing_bad.R",
#'                                  show_content = FALSE)
#' lab_home_writing(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_home_writing <- function(path = ".", verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("home_writing")))
  }

  # The CRAN rule is about WRITING into the user's filespace. Earlier versions of
  # this check inspected only path.expand()/normalizePath()/file.path()/Sys.getenv(),
  # which are all *reads*: it flagged `Sys.getenv("HOME")` (which writes nothing)
  # while missing `writeLines(x, "~/leaked.txt")`, the actual violation. So flag a
  # WRITE whose destination resolves to the user's home.

  # A destination resolves to the user's home if it contains a `~`-rooted literal
  # anywhere, or reads HOME / USERPROFILE from the environment. STR_CONST text
  # retains its quotes, hence the "~ / '~ alternation.
  home_pred <- paste0(
    ".//STR_CONST[", xp_str_starts("~"), "]",
    " or .//SYMBOL_FUNCTION_CALL[text() = 'Sys.getenv']/parent::expr",
    "/following-sibling::expr[1]/STR_CONST[",
    xp_str_starts(c("HOME", "USERPROFILE")),
    "]"
  )

  # Only the destination says where a write lands. Searching the whole call
  # reported `writeLines(normalizePath("~"), file)`, where the home path is the
  # text being written and the caller supplies the file, and `file.copy("~/x",
  # dest)`, which reads from home. write_destination() is how lab_file_operations()
  # finds the destination, so the two checks agree on which argument it is. A call
  # with none, such as cat() without `file =`, writes to the console.
  #
  # A destination rooted at a formal whose default is a home path, as in
  # `function(x, path = "~/x.txt") writeLines(x, path)`, writes there whenever
  # the caller leaves it out. A default counts when home_pred matches anywhere in
  # it, so `path = Sys.getenv("HOME")`, `path = normalizePath("~")` and
  # `dir = file.path("~", "c")` count too. lab_file_operations() is narrower:
  # formals_with_unsafe_default() accepts only a default that IS a `~` or
  # absolute literal, so of these it reports `path = "~/x.txt"` alone. It also
  # reports `path = "/srv/x.txt"`, which is not home and is not reported here.
  # Both read the formals of the innermost enclosing function only.
  xpath <- sprintf("//SYMBOL_FUNCTION_CALL[%s]", xp_text_in(WRITE_FUNCTIONS))
  home_test <- sprintf("boolean(%s)", home_pred)
  writes_home <- function(n) {
    dest <- write_destination(n)
    if (is.null(dest)) {
      return(FALSE)
    }
    if (xml2::xml_find_lgl(dest, home_test)) {
      return(TRUE)
    }
    root <- xml2::xml_find_first(dest_root(dest), "./SYMBOL")
    !inherits(root, "xml_missing") &&
      xml2::xml_text(root) %in% formals_with_default(n, home_pred)
  }
  issues <- xpath_filter(parsed, xpath, writes_home, function(file, nodes) {
    fn_hits(file, nodes, " writes under the home directory")
  })

  report_check(
    issues,
    verbose,
    check_label("home_writing"),
    "No home directory writing detected",
    "Writes into the user's home directory",
    paste("Treatment:", treatments$home_writing$treatment)
  )
}

# Per-tempfile cleanup detection. Only scans `tests/` since R/ helpers may
# legitimately hand temp paths back to callers. A tempfile()/tempdir() call
# is "clean" if cleanup exists either (a) in the innermost enclosing function
# body, OR (b) later in the same top-level scope (handles test scripts).
#' Diagnose Missing Temp-File Cleanup
#'
#' Flags a temporary file created without a matching cleanup.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Leaving Files in the Temporary Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#leaving-files-in-the-temporary-directory).
#' `tempdir()` is removed at session end, so an un-`unlink()`ed tempfile breaks no
#' rule, and tidiness rather than policy is why this sits at `opinion` tier. See
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
#' pkg <- example_diagnose_scenario("temp_examples/bad_temp_usage.R",
#'                                  show_content = FALSE)
#' lab_temp_cleanup(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_temp_cleanup <- function(path = ".", verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  # Scope: package code under R/, NOT tests/.
  #
  # This used to scan tests/, which is not shipped behaviour and never runs on a
  # user's machine. That is why it reported withr, fs, rlang, testthat and cli --
  # the packages that handle temp files most carefully of anyone.
  #
  # And note what CRAN's Repository Policy actually says: a package may not write
  # "anywhere else on the file system apart from the R session's temporary
  # directory". The temp directory is the one place it EXPRESSLY permits. Since
  # tempfile() returns a path INSIDE tempdir(), and R removes tempdir() when the
  # session ends, an un-unlinked tempfile() breaks no rule at all. This check is
  # therefore `opinion`: a tidiness hint about disk accumulating inside one long
  # session, not a policy violation. Writing OUTSIDE tempdir is a real breach, and
  # that is what home_writing and file_operations are for.
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("temp_cleanup")))
  }

  cleanup_funs <- c(
    "unlink",
    "file.remove",
    "on.exit",
    "defer",
    "defer_cleanup",
    "local_tempfile",
    "deferred_run"
  )
  predicate <- xp_text_in(cleanup_funs)
  # A tempfile() call is "clean" if cleanup exists in:
  #   (a) the innermost enclosing function, formals included, for a call inside a
  #       function, so `p = tempfile()` is cleaned by an on.exit() in the body;
  #   (b) the same top-level statement, or
  #   (c) a later top-level statement, for a call outside any function.
  # (b) and (c) are for top-level code only. Every top-level statement in R/ is
  # usually a function definition, so letting them excuse a call inside a
  # function let any later function's unlink() excuse an earlier leak.
  # Only tempfile() needs explicit cleanup; tempdir() returns the session
  # temp directory which R auto-cleans at session end.
  #
  # A path the function returns is the caller's to clean up, as in a small
  # factory like `callr_tempfile <- function(...) tempfile(...)`: the call is the
  # whole body, the body's last statement, inside return(), or assigned to a name
  # that the last statement returns.
  call <- "parent::expr/parent::expr"
  body_end <- "ancestor::expr[OP-LEFT-BRACE][parent::expr/FUNCTION][1]/expr[last()]"
  returned <- paste0(
    "(", call, "[parent::expr/FUNCTION][not(following-sibling::*)]",
    " or ", call, "[not(following-sibling::expr)]",
    "[parent::expr[OP-LEFT-BRACE][parent::expr/FUNCTION]]",
    " or ", call, "/parent::expr[expr[1]/SYMBOL_FUNCTION_CALL[text() = 'return']]",
    " or ", body_end, "/SYMBOL = ", call,
    "/parent::*[LEFT_ASSIGN or EQ_ASSIGN]/expr[1]/SYMBOL",
    " or ", body_end,
    "[expr[1]/SYMBOL_FUNCTION_CALL[text() = 'return' or text() = 'invisible']]",
    "/expr[2]/SYMBOL = ", call, "/parent::*[LEFT_ASSIGN or EQ_ASSIGN]/expr[1]/SYMBOL",
    ")"
  )
  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[text() = 'tempfile'][
       not(%s)
       and %s
       and (
         ancestor::expr[FUNCTION or OP-LAMBDA]
         or (
           not(
             ancestor::expr[parent::exprlist][1]
             //SYMBOL_FUNCTION_CALL[%s]
           )
           and not(
             ancestor::expr[parent::exprlist][1]
             /following-sibling::expr
             //SYMBOL_FUNCTION_CALL[%s]
           )
         )
       )
     ]",
    returned,
    not_under_fn_with_call_xpath(cleanup_funs),
    predicate,
    predicate
  )
  report_check(
    xpath_lints(parsed, xpath),
    verbose,
    check_label("temp_cleanup"),
    "Temp file usage appears to include cleanup",
    "Temp files without apparent cleanup",
    paste("Treatment:", treatments$temp_cleanup$treatment)
  )
}

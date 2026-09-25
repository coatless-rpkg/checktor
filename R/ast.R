# AST-based source inspection helpers. All code-side diagnostics that used to
# regex over file text now go through `read_r_xml(path)` and either
# `xpath_lints(parsed, xpath)` or one of the canned helpers below.
#
# Tokens of interest in the xmlparsedata XML representation of getParseData():
#   SYMBOL_FUNCTION_CALL  - function name in `fn(...)`
#   SYMBOL_PACKAGE        - prefix in `pkg::fn`
#   SYMBOL                - bare identifier (variables, T/F, ...)
#   STR_CONST             - "..." / '...' literal
#   NUM_CONST             - numeric literal
#   OP-TILDE              - the `~` operator (formulas)
#   LEFT_ASSIGN / RIGHT_ASSIGN / EQ_ASSIGN - assignment operators
#   expr                  - wrapper around any expression node
#   FUNCTION              - the keyword in `function(...)`

#' Parse a Package's R Sources into Queryable XML
#'
#' Parses every `R/*.R` file under `path` with `parse(keep.source = TRUE)` and
#' converts each file's parse data to an `xml2` document via
#' [xmlparsedata::xml_parse_data()]. This is the entry point for an AST-based
#' check: hand the result to [xpath_lints()] or one of the other helpers. A
#' syntax error in a file is caught and recorded in that file's `error` slot
#' rather than crashing the run.
#'
#' @param path Character. Path to the R package directory.
#' @return A named list with one entry per `R/*.R` file, each a list of `file`
#'   (the path), `xml` (an `xml2` document, or `NULL` if the file did not parse),
#'   and `error` (the `simpleError`, or `NULL`).
#' @seealso [xpath_lints()], [register_check()], and the *Writing Your Own
#'   Checks* vignette.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' parsed <- read_r_xml(pkg)
#' names(parsed)
read_r_xml <- function(path) {
  path <- find_package_root(path)
  # Within a checktor() run the code, policy and documentation panels share one
  # parse; see R/cache.R.
  run_cached(paste0("r_xml:", path), function() {
    r_files <- list_r_files(path)
    setNames(lapply(r_files, parse_one_r_file), r_files)
  })
}

# parse() with the token table that getParseData() reads. parse() records that
# table only while `options(keep.parse.data)` is TRUE, and sys.source() and some
# IDE tooling turn it off. With it off every file parsed to an empty tree, so each
# parse-tree check saw nothing and passed. Force it on for this one parse and hand
# the caller's setting back.
parse_with_data <- function(...) {
  old <- options(keep.parse.data = TRUE)
  on.exit(options(old), add = TRUE)
  parse(..., keep.source = TRUE)
}

# Parse a single file. parse() raises on syntax errors; we catch and report
# the file:line:col so downstream checks can surface a clear lint instead of
# crashing the whole run.
parse_one_r_file <- function(file) {
  tryCatch(
    {
      exprs <- parse_with_data(file)
      pd <- utils::getParseData(exprs)
      if (is.null(pd) || nrow(pd) == 0L) {
        return(list(file = file, xml = NULL, error = NULL))
      }
      xml <- xml2::read_xml(xmlparsedata::xml_parse_data(pd))
      list(file = file, xml = xml, error = NULL)
    },
    error = function(e) {
      list(file = file, xml = NULL, error = e)
    }
  )
}

#' Collect XPath Matches as `file:line` Strings
#'
#' Runs an XPath query against every parsed file from [read_r_xml()] and returns
#' a `"basename:line"` string for each matching node, ready to use as a check's
#' `issues`.
#'
#' @param parsed A parsed-sources list from [read_r_xml()].
#' @param xpath Character. An XPath 1.0 query, typically anchored on a
#'   `SYMBOL_FUNCTION_CALL` node.
#' @param label Optional character. Appended in parentheses after each hit.
#' @return A character vector of `"basename:line"` strings, empty if nothing
#'   matched.
#' @seealso [read_r_xml()], [xpath_per_file()], [undesirable_function_check()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/seed_setting_bad.R",
#'                                  show_content = FALSE)
#' parsed <- read_r_xml(pkg)
#' xpath_lints(parsed, "//SYMBOL_FUNCTION_CALL[text() = 'set.seed']")
xpath_lints <- function(parsed, xpath, label = NULL) {
  xpath_per_file(parsed, xpath, function(file, nodes) {
    line_hits(file, nodes, if (is.null(label)) "" else paste0(" (", label, ")"))
  })
}

#' Summarise XPath Matches per File
#'
#' A per-file variant of [xpath_lints()] for when you need to control the issue
#' string. Runs `xpath` against each parsed file and calls `summarise(file,
#' nodes)` on each non-empty match set, collecting the strings it returns.
#'
#' @param parsed A parsed-sources list from [read_r_xml()].
#' @param xpath Character. An XPath 1.0 query.
#' @param summarise A function of `(file, nodes)` returning a character vector of
#'   issue strings, where `nodes` is an `xml2` nodeset.
#' @return A character vector of the issue strings `summarise` produced.
#' @seealso [xpath_lints()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/seed_setting_bad.R",
#'                                  show_content = FALSE)
#' parsed <- read_r_xml(pkg)
#' xpath_per_file(parsed, "//SYMBOL_FUNCTION_CALL[text() = 'set.seed']",
#'                function(file, nodes) {
#'                  paste0(basename(file), ":", xml2::xml_attr(nodes, "line1"))
#'                })
xpath_per_file <- function(parsed, xpath, summarise) {
  hits <- character(0)
  for (p in parsed_docs(parsed)) {
    nodes <- xml2::xml_find_all(p$xml, xpath)
    if (length(nodes) > 0L) {
      hits <- c(hits, summarise(p$file, nodes))
    }
  }
  hits
}

# The files of a read_r_xml() list that parsed: those with a tree to query. A
# file that failed to parse has `xml = NULL` and its error in `error`.
parsed_docs <- function(parsed) {
  Filter(function(p) !is.null(p$xml), parsed)
}

# The parsed R sources a code check reads: the orchestrator's shared parse when
# it passed one, else a fresh read of `path`. A check returns early with
# pass_result() when this is empty, so an empty R/ prints no success line.
# `path` is already resolved: each check's first line is find_package_root().
code_sources <- function(path, parsed = NULL) {
  if (is.null(parsed)) read_r_xml(path) else parsed
}

# Keep the nodes `xpath` finds for which `keep(node)` is TRUE, and format each
# file's survivors with `format(file, nodes)`: xpath_per_file() with a filter.
xpath_filter <- function(parsed, xpath, keep, format = line_hits) {
  xpath_per_file(parsed, xpath, function(file, nodes) {
    nodes <- nodes[vapply(nodes, keep, logical(1))]
    if (length(nodes) == 0L) character(0) else format(file, nodes)
  })
}

# Issue strings for matched nodes: `"file.R:12"`, then `suffix`.
line_hits <- function(file, nodes, suffix = "") {
  paste0(basename(file), ":", xml2::xml_attr(nodes, "line1"), suffix)
}

# Issue strings for matched SYMBOL_FUNCTION_CALL nodes, naming the call:
# `"file.R:12 (fn())"`, or `"file.R:12 (fn() <suffix>)"` with a suffix.
fn_hits <- function(file, nodes, suffix = "") {
  line_hits(file, nodes, paste0(" (", xml2::xml_text(nodes), "()", suffix, ")"))
}

# ---- XPath predicate builders ----
#
# `xp_text_in(c("a", "b"))` is `text() = 'a' or text() = 'b'`, a node whose text
# is any of `x`. Wrap it in parentheses before joining it to another condition
# with `and`.
xp_text_in <- function(x) {
  paste(sprintf("text() = '%s'", x), collapse = " or ")
}

# A STR_CONST holding any of `x`. Its text keeps its quotes, and either quote
# style is R, so both are matched: `text() = '"a"' or text() = "'a'"`.
xp_str_const_in <- function(x) {
  paste(sprintf("text() = '\"%s\"' or text() = \"'%s'\"", x, x), collapse = " or ")
}

# A STR_CONST starting with any of `prefix`, in either quote style.
xp_str_starts <- function(prefix) {
  paste(
    sprintf("starts-with(text(), '\"%s') or starts-with(text(), \"'%s\")", prefix, prefix),
    collapse = " or "
  )
}

# A call to any of `funs`, not as a member (`obj$fn()`), meeting every further
# condition in `...`.
xp_call <- function(funs, ...) {
  sprintf(
    "//SYMBOL_FUNCTION_CALL[%s]",
    paste(c(sprintf("(%s)", xp_text_in(funs)), NOT_MEMBER_ACCESS, ...), collapse = " and ")
  )
}

# Convert parse errors into pseudo-issues so they surface in reports instead
# of being silently dropped. Returns a character vector of "file:line:col
# (parse error: ...)".
parse_error_issues <- function(parsed) {
  errs <- Filter(function(p) !is.null(p$error), parsed)
  vapply(
    errs,
    function(p) {
      paste0(basename(p$file), ": parse error: ", conditionMessage(p$error))
    },
    character(1),
    USE.NAMES = FALSE
  )
}

# `obj$cat(x)` and `self$print(y)` are METHOD CALLS on an object. R's parser still
# emits a SYMBOL_FUNCTION_CALL for the member name, so a naive
# //SYMBOL_FUNCTION_CALL[text()='cat'] matches them, even though they have nothing
# to do with base::cat. cli is built on R6-ish objects with a `$cat` member and was
# reported 25 times for calling its OWN method.
#
# The tf_usage check has always guarded against this for `df$T`; the call detectors
# never did. `base::cat(x)` is still matched, and correctly so: only `$` and `@`
# access is excluded.
# An assignment written with `=` does NOT parse as an `expr`. Inside a braced body
# `x = 1` is an `expr_or_assign_or_help` node (`equal_assign` on older R), and only
# `x <- 1` is a plain `expr`. So every XPath of the shape
# `expr[LEFT_ASSIGN or EQ_ASSIGN]` silently misses EVERY `=` assignment in R.
#
# knitr, and Yihui Xie's packages generally, assign with `=` throughout. Their
# closure factories bind `defaults = value` in an enclosing function and then
# update it with `defaults <<- ...` from a nested one -- a textbook closure, never
# touching .GlobalEnv -- and checktor reported all of it, because it could not see
# the `=` binding that made the `<<-` safe.
ASSIGN_NODE <- "*[self::expr or self::expr_or_assign_or_help or self::equal_assign]"

NOT_MEMBER_ACCESS <- paste0(
  "not(preceding-sibling::*[1][self::OP-DOLLAR or self::OP-AT])"
)

#' Flag Every Call to a Named Function
#'
#' The "flag any call to function X" pattern, checktor's analogue of
#' `lintr::undesirable_function_linter()`. Member-access calls (`obj$fn(...)`,
#' `obj@fn(...)`) are excluded, so only a genuine call to the bare function
#' matches.
#'
#' @param parsed A parsed-sources list from [read_r_xml()].
#' @param funs Character vector of function names to flag.
#' @param label Logical. If `TRUE` (default), each hit is suffixed with the
#'   matched function name in parentheses.
#' @return A character vector of `"basename:line"` strings.
#' @seealso [xpath_lints()], [not_under_fn_with_call_xpath()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/browser_calls_bad.R",
#'                                  show_content = FALSE)
#' parsed <- read_r_xml(pkg)
#' undesirable_function_check(parsed, c("browser", "install.packages"))
undesirable_function_check <- function(parsed, funs, label = TRUE) {
  if (length(funs) == 0L) {
    return(character(0))
  }
  xpath <- xp_call(funs)
  if (!isTRUE(label)) {
    return(xpath_lints(parsed, xpath))
  }
  # Per-file: include the matched function name in the issue string.
  xpath_per_file(parsed, xpath, fn_hits)
}

#' XPath Predicate: Not Guarded by a Sibling Call
#'
#' Returns an XPath predicate that restricts matches to nodes whose innermost
#' enclosing function body does *not* also contain a call to any of `funs`. This
#' is how a check enforces a guard, for instance that an `options()` call is
#' paired with an `on.exit()` in the same function.
#'
#' @details
#' The predicate anchors on `ancestor::expr[FUNCTION][1]`, the nearest function
#' definition, and searches its whole subtree. Anchoring on the innermost
#' function keeps it correct where the guard belongs to an inner function rather
#' than an outer one, and covers a call sitting in a default argument as well as
#' one in the body.
#'
#' @param funs Character vector of guard function names (e.g. `"on.exit"`).
#' @return A single character string: an XPath predicate to splice into a query
#'   after a node test.
#' @seealso [xpath_lints()].
#' @export
#' @examples
#' predicate <- not_under_fn_with_call_xpath(c("on.exit", "local_options"))
#' paste0("//SYMBOL_FUNCTION_CALL[text() = 'options'][", predicate, "]")
not_under_fn_with_call_xpath <- function(funs) {
  sprintf(
    "not(ancestor::expr[FUNCTION][1]//SYMBOL_FUNCTION_CALL[%s])",
    xp_text_in(funs)
  )
}

# Names of functions registered as on.exit() cleanup handlers anywhere in the
# sources. A function invoked from inside on.exit(...), such as
# `on.exit(restore_par(op))`, IS the restoration, so the par()/options() writes
# in its body are restores rather than leaks, even though the on.exit() lives in
# the caller. Returns the callee names found inside on.exit() calls.
on_exit_handler_names <- function(parsed) {
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'on.exit']",
    "/parent::expr/parent::expr//SYMBOL_FUNCTION_CALL"
  )
  names <- xpath_per_file(parsed, xpath, function(file, nodes) {
    xml2::xml_text(nodes)
  })
  setdiff(unique(names), "on.exit")
}

# XPath predicate that holds unless the innermost enclosing function DEFINITION is
# assigned to one of `names`. Used to exempt option/par writes inside a registered
# on.exit handler. An empty `names` yields a predicate that never excludes.
not_on_exit_handler_xpath <- function(names) {
  if (length(names) == 0L) {
    return("true()")
  }
  sprintf(
    "not(ancestor::expr[FUNCTION][1]/parent::*/expr[1]/SYMBOL[%s])",
    xp_text_in(names)
  )
}

# The name of the innermost top-level function a node sits inside, or "" when the
# node is not inside a named function. Used to attribute a hit to its function so
# call-graph reasoning can act on it.
# A function may be defined with a QUOTED name -- `"print.foo" <- function(x)` --
# in which case R parses the left-hand side as STR_CONST rather than SYMBOL. geoR
# writes almost every one of its functions that way, and a SYMBOL-only lookup
# returns "" for all of them, silently disabling every name-based exemption.
DEF_NAME_XPATH <- "parent::*/expr[1]/SYMBOL | parent::*/expr[1]/STR_CONST"

unquote_name <- function(x) gsub("^['\"`]|['\"`]$", "", x)

enclosing_function_name <- function(node) {
  fn <- xml2::xml_find_first(
    node,
    sprintf("ancestor::expr[FUNCTION][%s][1]", DEF_NAME_XPATH)
  )
  if (inherits(fn, "xml_missing")) {
    return("")
  }
  sym <- xml2::xml_find_first(fn, DEF_NAME_XPATH)
  if (inherits(sym, "xml_missing")) {
    return("")
  }
  unquote_name(xml2::xml_text(sym))
}

# The symbol a `<<-` / `->>` assigns to. For `x <<- v` the target sits to the
# LEFT of the operator; for `v ->> x` it sits to the RIGHT.
superassign_target <- function(op) {
  side <- if (identical(xml2::xml_name(op), "RIGHT_ASSIGN")) {
    "following-sibling::expr[1]"
  } else {
    "preceding-sibling::expr[1]"
  }
  e <- xml2::xml_find_first(op, side)
  if (inherits(e, "xml_missing")) {
    return("")
  }
  # `x <<- v` -> SYMBOL; `x$f <<- v` / `x[[i]] <<- v` -> the base symbol.
  sym <- xml2::xml_find_first(e, "descendant-or-self::SYMBOL[1]")
  if (inherits(sym, "xml_missing")) "" else xml2::xml_text(sym)
}

# Every name bound at package top level: `nm <- ...` at the file's top level.
# A `<<-` to one of these writes into the package namespace, not .GlobalEnv.
package_level_names <- function(parsed) {
  xpath <- sprintf(
    "/exprlist/%s[LEFT_ASSIGN[text() = '<-'] or EQ_ASSIGN]/expr[1]/SYMBOL",
    ASSIGN_NODE
  )
  unique(xpath_per_file(parsed, xpath, function(file, nodes) {
    xml2::xml_text(nodes)
  }))
}

# TRUE when `target` is already bound somewhere in an enclosing function: as a
# formal, or by an ordinary `<-` in that function's body. In that case `<<-`
# rebinds THERE and never reaches .GlobalEnv.
binds_in_enclosing_function <- function(op, target) {
  # A `local({...})` block is a binding scope just as much as a function body is,
  # and it is the classic way to give a function a private cache:
  #
  #     make_table <- local({
  #       cache <- NULL
  #       function() { if (is.null(cache)) cache <<- compute(); cache }
  #     })
  #
  # That `<<-` binds in the local() environment and never comes near .GlobalEnv.
  # But `local()` is a CALL, not an `expr` with a FUNCTION child, so an ancestor
  # search for `expr[FUNCTION]` walks straight past the scope that actually holds
  # the binding. curl, cli and rlang all use this idiom, and every one of them was
  # reported.
  fns <- xml2::xml_find_all(
    op,
    paste(
      "ancestor::expr[FUNCTION]",
      "ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[text() = 'local']]",
      sep = " | "
    )
  )
  if (length(fns) == 0L) {
    return(FALSE)
  }
  for (fn in fns) {
    formals_hit <- xml2::xml_find_all(
      fn,
      sprintf("SYMBOL_FORMALS[text() = '%s']", target)
    )
    if (length(formals_hit) > 0L) {
      return(TRUE)
    }
    # `<<-` is itself a LEFT_ASSIGN token, so the operator text has to be pinned
    # to `<-`. Without that, a super-assign matches as its own local binding and
    # every global write exempts itself.
    local_hit <- xml2::xml_find_all(
      fn,
      sprintf(
        ".//%s[LEFT_ASSIGN[text() = '<-'] or EQ_ASSIGN]/expr[1]/SYMBOL[text() = '%s']",
        ASSIGN_NODE,
        target
      )
    )
    if (length(local_hit) > 0L) return(TRUE)
  }
  FALSE
}

# Parse a code STRING (rather than a file) and return the xml2 document of its
# parse data, or NULL when it does not parse. Used for code that lives inside
# something else, e.g. the \examples{} block of an .Rd file.
parse_text_xml <- function(text) {
  exprs <- tryCatch(
    parse_with_data(text = text),
    error = function(e) NULL
  )
  if (is.null(exprs)) {
    return(NULL)
  }
  tryCatch(
    xml2::read_xml(xmlparsedata::xml_parse_data(exprs)),
    error = function(e) NULL
  )
}

# The name a top-level `<expr>` assigns to, or NA when it is not a plain
# assignment. Reading it off the tree rather than the source text means we get
# `x = 1`, backticked and quoted names, and an assignment split across lines for
# free -- none of which a "look at the next line" regex survives.
#
# `<<-` is deliberately excluded: it does not create a package-level binding.
assign_target_of <- function(expr) {
  op <- xml2::xml_find_first(expr, "./LEFT_ASSIGN | ./EQ_ASSIGN")
  if (inherits(op, "xml_missing")) {
    return(NA_character_)
  }
  if (identical(xml2::xml_text(op), "<<-")) {
    return(NA_character_)
  }
  target <- xml2::xml_find_first(expr, "./expr[1]/SYMBOL | ./expr[1]/STR_CONST")
  if (inherits(target, "xml_missing")) {
    return(NA_character_)
  }
  # A quoted name arrives with its quotes attached.
  unquote_name(xml2::xml_text(target))
}

# Is `op` inside a function whose ENCLOSING ENVIRONMENT we cannot see?
#
# R6 writes:
#
#     generator_funs$debug <- function(name) {
#       debug_names <<- union(debug_names, name)
#     }
#
# That function is stored into a list and later injected into a generator
# environment, where `debug_names` is bound. Statically we can see neither the
# injection nor the binding, so we cannot say where the `<<-` lands. What we CAN
# see is the tell: the function was assigned into a container rather than bound at
# top level, which means its closure environment is arranged at run time.
#
# "Cannot tell" must never become "accuses". This returns TRUE for such a function
# so the caller skips it, exactly as package_exports() returns NULL when NAMESPACE
# is unreadable.
in_container_assigned_function <- function(op) {
  fns <- xml2::xml_find_all(op, "ancestor::expr[FUNCTION]")
  for (fn in fns) {
    lhs <- xml2::xml_find_first(fn, "parent::*/expr[1]")
    if (inherits(lhs, "xml_missing")) {
      next
    }
    if (
      length(xml2::xml_find_all(
        lhs,
        "./OP-DOLLAR | ./OP-AT | ./LBB | ./OP-LEFT-BRACKET"
      )) >
        0L
    ) {
      return(TRUE)
    }
  }
  FALSE
}

# Does `node`'s enclosing function RETURN a value it captured earlier?
#
# This is the base-R setter/restorer contract, the same one option_changes
# already honours, but written across statements rather than in one call:
#
#     set_path <- function(path) {
#       old <- get_path()          # capture the prior state
#       Sys.setenv(PATH = path)    # set the new state
#       invisible(old)             # hand the old state back
#     }
#
# A function shaped like that is not leaking; it is a setter meant to be paired
# with a restore by its caller, which is exactly how withr's with_*/local_* are
# built on top of these setters. Sys.setenv() returns TRUE, not the old value, so
# unlike options() the capture and the return are separate statements.
#
# The signal: the function's terminal statement returns a symbol (bare, or through
# invisible()/return()) that was assigned earlier in the same body. It cannot tell
# that the captured value IS the prior state rather than an unrelated computation,
# so it can slightly over-exempt; that is the safe direction for a check that must
# not cry wolf, and a function that both leaks and returns an unrelated capture is
# itself poor code.
enclosing_fn_returns_capture <- function(node) {
  body <- enclosing_function_body(node)
  if (is.null(body)) {
    return(FALSE)
  }

  braced <- length(xml2::xml_find_all(body, "./OP-LEFT-BRACE")) > 0L
  last <- if (braced) {
    xml2::xml_find_first(body, sprintf("./%s[last()]", ASSIGN_NODE))
  } else {
    body
  }
  if (inherits(last, "xml_missing")) {
    return(FALSE)
  }

  ret <- returned_symbol(last)
  !is.na(ret) && ret %in% body_assign_targets(body)
}

# The body of `node`'s innermost enclosing function, or NULL at top level. A
# function expr is FUNCTION ( formals ) BODY, so the body is its last expr.
enclosing_function_body <- function(node) {
  fn <- xml2::xml_find_first(node, "ancestor::expr[FUNCTION][1]")
  if (inherits(fn, "xml_missing")) {
    return(NULL)
  }
  body <- xml2::xml_find_first(fn, "./expr[last()]")
  if (inherits(body, "xml_missing")) NULL else body
}

# The names a braced body's own statements assign to, one per assignment.
body_assign_targets <- function(body) {
  targets <- vapply(
    xml2::xml_find_all(body, sprintf("./%s", ASSIGN_NODE)),
    assign_target_of,
    character(1)
  )
  targets[!is.na(targets)]
}

# The bare symbol an expression evaluates to, unwrapping invisible()/return(), or
# NA when the expression is not simply a symbol.
returned_symbol <- function(expr) {
  # A lone symbol: `<expr><SYMBOL>x</SYMBOL></expr>`.
  kids <- xml2::xml_children(expr)
  if (length(kids) == 1L && identical(xml2::xml_name(kids[[1L]]), "SYMBOL")) {
    return(xml2::xml_text(kids[[1L]]))
  }
  # `invisible(x)` / `return(x)`.
  callee <- xml2::xml_text(
    xml2::xml_find_first(expr, "./expr[1]/SYMBOL_FUNCTION_CALL")
  )
  if (!is.na(callee) && callee %in% c("invisible", "return")) {
    inner <- xml2::xml_find_first(expr, "./expr[2]")
    if (!inherits(inner, "xml_missing")) {
      ik <- xml2::xml_children(inner)
      if (length(ik) == 1L && identical(xml2::xml_name(ik[[1L]]), "SYMBOL")) {
        return(xml2::xml_text(ik[[1L]]))
      }
    }
  }
  NA_character_
}

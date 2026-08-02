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
  r_files <- list_r_files(path)
  setNames(lapply(r_files, parse_one_r_file), r_files)
}

# Parse a single file. parse() raises on syntax errors; we catch and report
# the file:line:col so downstream checks can surface a clear lint instead of
# crashing the whole run.
parse_one_r_file <- function(file) {
  tryCatch(
    {
      exprs <- parse(file, keep.source = TRUE)
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
  hits <- character(0)
  for (p in parsed) {
    if (is.null(p$xml)) {
      next
    }
    nodes <- xml2::xml_find_all(p$xml, xpath)
    if (length(nodes) == 0L) {
      next
    }
    lines <- xml2::xml_attr(nodes, "line1")
    suffix <- if (is.null(label)) "" else paste0(" (", label, ")")
    hits <- c(hits, paste0(basename(p$file), ":", lines, suffix))
  }
  hits
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
  for (p in parsed) {
    if (is.null(p$xml)) {
      next
    }
    nodes <- xml2::xml_find_all(p$xml, xpath)
    if (length(nodes) > 0L) {
      hits <- c(hits, summarise(p$file, nodes))
    }
  }
  hits
}

# Convert parse errors into pseudo-issues so they surface in reports instead
# of being silently dropped. Returns a character vector of "file:line:col
# (parse error: ...)".
parse_error_issues <- function(parsed) {
  out <- character(0)
  for (p in parsed) {
    if (is.null(p$error)) {
      next
    }
    out <- c(
      out,
      paste0(basename(p$file), ": parse error: ", conditionMessage(p$error))
    )
  }
  out
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
  predicate <- paste(sprintf("text() = '%s'", funs), collapse = " or ")
  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[(%s) and %s]",
    predicate,
    NOT_MEMBER_ACCESS
  )
  if (!isTRUE(label)) {
    return(xpath_lints(parsed, xpath))
  }
  # Per-file: include the matched function name in the issue string.
  xpath_per_file(parsed, xpath, function(file, nodes) {
    paste0(
      basename(file),
      ":",
      xml2::xml_attr(nodes, "line1"),
      " (",
      xml2::xml_text(nodes),
      "())"
    )
  })
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
  predicate <- paste(sprintf("text() = '%s'", funs), collapse = " or ")
  sprintf(
    "not(ancestor::expr[FUNCTION][1]//SYMBOL_FUNCTION_CALL[%s])",
    predicate
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
  names <- character(0)
  for (p in parsed) {
    if (is.null(p$xml)) {
      next
    }
    names <- c(names, xml2::xml_text(xml2::xml_find_all(p$xml, xpath)))
  }
  setdiff(unique(names), "on.exit")
}

# XPath predicate that holds unless the innermost enclosing function DEFINITION is
# assigned to one of `names`. Used to exempt option/par writes inside a registered
# on.exit handler. An empty `names` yields a predicate that never excludes.
not_on_exit_handler_xpath <- function(names) {
  if (length(names) == 0L) {
    return("true()")
  }
  pred <- paste(sprintf("text() = '%s'", names), collapse = " or ")
  sprintf(
    "not(ancestor::expr[FUNCTION][1]/parent::*/expr[1]/SYMBOL[%s])",
    pred
  )
}

# ---- Rd helpers --------------------------------------------------------------
# tools::parse_Rd() returns a recursive list. Each section element carries
# attr(., "Rd_tag") e.g. "\\value", "\\examples", "\\dontrun", "TEXT".

#' Extract One Section from a Parsed `.Rd` File
#'
#' Returns the first top-level node of a [tools::parse_Rd()] result whose
#' `Rd_tag` matches `tag`, or `NULL` if absent. Use it to reach a specific
#' section, such as `\\value` or `\\examples`, when writing a documentation
#' check.
#'
#' @param rd A parsed `.Rd` object from [tools::parse_Rd()].
#' @param tag Character. The `Rd_tag` to find, e.g. `"\\value"` or
#'   `"\\examples"`.
#' @return The matching Rd node, or `NULL`.
#' @seealso [collect_rd_text()].
#' @export
#' @examples
#' rd_file <- tempfile(fileext = ".Rd")
#' writeLines(c("\\name{foo}", "\\title{Foo}", "\\value{A number.}"), rd_file)
#' rd <- tools::parse_Rd(rd_file)
#' collect_rd_text(extract_rd_section(rd, "\\value"))
extract_rd_section <- function(rd, tag) {
  for (sec in rd) {
    if (identical(attr(sec, "Rd_tag"), tag)) return(sec)
  }
  NULL
}

#' Flatten a Parsed `.Rd` Node to Text
#'
#' Recursively concatenates the text of a [tools::parse_Rd()] node, optionally
#' skipping subsections by `Rd_tag` (for instance `"\\dontrun"` when collecting
#' example code that is meant to run).
#'
#' @param node An Rd node, such as one returned by [extract_rd_section()].
#' @param skip Character vector of `Rd_tag` values to omit from the text.
#' @return A single character string.
#' @seealso [extract_rd_section()].
#' @export
#' @examples
#' rd_file <- tempfile(fileext = ".Rd")
#' writeLines(c("\\name{foo}", "\\title{Foo}",
#'              "\\examples{ f() \\dontrun{ g() } }"), rd_file)
#' rd <- tools::parse_Rd(rd_file)
#' collect_rd_text(extract_rd_section(rd, "\\examples"), skip = "\\dontrun")
collect_rd_text <- function(node, skip = character(0)) {
  tag <- attr(node, "Rd_tag")
  if (!is.null(tag) && tag %in% skip) {
    return("")
  }
  if (is.character(node)) {
    return(paste(node, collapse = ""))
  }
  if (is.list(node)) {
    parts <- vapply(
      node,
      collect_rd_text,
      character(1),
      skip = skip,
      USE.NAMES = FALSE
    )
    return(paste(parts, collapse = ""))
  }
  ""
}

# The complement of `skip=`: gather only what sits inside the named tags. Taking
# the whole section and subtracting the runnable text does not work, because the
# two are not contiguous once anything follows the hidden block -- a trailing
# newline is enough -- so a fixed-string removal matches nothing and hands back
# the entire section as though it were hidden.
collect_rd_text_within <- function(node, tags) {
  tag <- attr(node, "Rd_tag")
  if (!is.null(tag) && tag %in% tags) {
    return(collect_rd_text(node))
  }
  if (is.list(node)) {
    parts <- vapply(
      node,
      collect_rd_text_within,
      character(1),
      tags = tags,
      USE.NAMES = FALSE
    )
    return(paste(parts, collapse = ""))
  }
  ""
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

# Names of functions whose output is only ever reachable through an S3 output
# method, i.e. print-method delegates.
#
# An S3 print method may hand its cat()ing off to a helper (some packages do this
# with a print_structure_section() and friends). The helper is not itself a method,
# so a name-based exemption cannot see it. But if EVERY caller of the helper is
# an S3 print/format/summary method, its output is reachable only via one, which
# is behaviourally identical to inlining it. Callers are resolved across all
# parsed files. A helper with no callers, or with even one non-method caller, is
# not a delegate.
s3_output_delegates <- function(parsed) {
  s4_named <- s4_registered_method_names(parsed)
  is_method <- function(nm) {
    grepl("^(print|format|summary)\\.", nm) |
      nm == S4_SHOW_CALLER |
      nm %in% s4_named
  }

  defined <- character(0) # every top-level function name
  callers <- list() # callee -> character vector of caller names

  for (p in parsed) {
    if (!is.null(p$error) || is.null(p$xml)) {
      next
    }
    fns <- xml2::xml_find_all(
      p$xml,
      sprintf("//expr[FUNCTION][%s]", DEF_NAME_XPATH)
    )
    for (fn in fns) {
      sym <- xml2::xml_find_first(fn, DEF_NAME_XPATH)
      if (inherits(sym, "xml_missing")) {
        next
      }
      nm <- unquote_name(xml2::xml_text(sym))
      defined <- c(defined, nm)
      callees <- unique(xml2::xml_text(
        xml2::xml_find_all(fn, ".//SYMBOL_FUNCTION_CALL")
      ))
      for (ce in callees) {
        callers[[ce]] <- c(callers[[ce]], nm)
      }
    }
  }

  # An S4 output method is an ANONYMOUS function handed to setMethod("show", ...),
  # so the loop above, which only walks NAMED top-level functions, never sees it.
  # DBI hands its cat()ing to show_connection(), whose only caller is exactly such
  # a method -- so without this, show_connection() has no callers at all, is not
  # recognised as a delegate, and gets reported.
  for (p in parsed) {
    if (!is.null(p$error) || is.null(p$xml)) {
      next
    }
    for (body in xml2::xml_find_all(p$xml, s4_output_method_xpath())) {
      callees <- unique(xml2::xml_text(
        xml2::xml_find_all(body, ".//SYMBOL_FUNCTION_CALL")
      ))
      for (ce in callees) {
        callers[[ce]] <- c(callers[[ce]], S4_SHOW_CALLER)
      }
    }
  }

  defined <- unique(defined)
  if (length(defined) == 0L) {
    return(character(0))
  }

  local_defs <- setdiff(defined, defined[is_method(defined)])
  keep <- vapply(
    local_defs,
    function(nm) {
      cs <- callers[[nm]]
      length(cs) > 0L && all(is_method(cs))
    },
    logical(1)
  )
  local_defs[keep]
}

# Names of functions REGISTERED as an S4 output method by name, rather than
# written inline. DBI does this throughout:
#
#     setMethod("show", "DBIConnection", show_DBIConnection)
#
# The method is `show_DBIConnection`, a perfectly ordinary named function, so an
# XPath looking for an anonymous `function` inside the setMethod call finds
# nothing at all. Yet that function IS the show method, and cat() inside it is as
# legitimate as cat() inside print.default().
s4_registered_method_names <- function(parsed) {
  out <- character(0)
  quoted <- paste(
    sprintf(
      "text() = '\"%s\"' or text() = \"'%s'\"",
      S4_OUTPUT_GENERICS,
      S4_OUTPUT_GENERICS
    ),
    collapse = " or "
  )
  xpath <- sprintf(
    "//expr[expr[1]/SYMBOL_FUNCTION_CALL[
       text() = 'setMethod' or text() = 'setReplaceMethod'
     ]][expr[2]/STR_CONST[%s]]/expr[last()]/SYMBOL",
    quoted
  )
  for (p in parsed) {
    if (!is.null(p$error) || is.null(p$xml)) {
      next
    }
    out <- c(out, xml2::xml_text(xml2::xml_find_all(p$xml, xpath)))
  }
  unique(out)
}

# Every function whose job is producing console output: S3 methods by name prefix,
# plus S4 methods registered by name. cat() inside any of them is the idiom, not a
# leak.
output_method_names <- function(parsed) {
  defined <- character(0)
  for (p in parsed) {
    if (!is.null(p$error) || is.null(p$xml)) {
      next
    }
    syms <- xml2::xml_find_all(
      p$xml,
      "//expr[FUNCTION]/parent::*/expr[1]/SYMBOL | //expr[FUNCTION]/parent::*/expr[1]/STR_CONST"
    )
    defined <- c(defined, unquote_name(xml2::xml_text(syms)))
  }
  s3 <- unique(defined[grepl("^(print|format|summary)\\.", defined)])
  unique(c(s3, s4_registered_method_names(parsed)))
}

# A sentinel caller name for "an S4 output method". It cannot collide with a real
# R function name, because a real one cannot contain a space.
S4_SHOW_CALLER <- "<S4 output method>"

# The generics whose S4 methods exist to PRODUCE console output. CRAN's rule ends
# with the literal parenthetical "(except for print, summary, interactive
# functions)", and `show` is simply what S4 calls `print`: it is the method R
# invokes to display an object at the prompt. cat() is the required idiom inside
# one, exactly as it is inside print.default().
S4_OUTPUT_GENERICS <- c("show", "print", "format", "summary")

# XPath selecting the function body of any setMethod("show", ...) and friends.
# The method function is an argument of the setMethod call, so from the function
# expr the call is `parent::expr` and the generic is that call's second expr.
s4_output_method_xpath <- function() {
  quoted <- paste(
    sprintf(
      "text() = '\"%s\"' or text() = \"'%s'\"",
      S4_OUTPUT_GENERICS,
      S4_OUTPUT_GENERICS
    ),
    collapse = " or "
  )
  bare <- paste(sprintf("text() = '%s'", S4_OUTPUT_GENERICS), collapse = " or ")
  sprintf(
    "//expr[FUNCTION][
       parent::expr[expr[1]/SYMBOL_FUNCTION_CALL[
         text() = 'setMethod' or text() = 'setReplaceMethod'
       ]][expr[2][STR_CONST[%s] or SYMBOL[%s]]]
     ]",
    quoted,
    bare
  )
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
  out <- character(0)
  for (p in parsed) {
    if (!is.null(p$error) || is.null(p$xml)) {
      next
    }
    syms <- xml2::xml_find_all(
      p$xml,
      sprintf(
        "/exprlist/%s[LEFT_ASSIGN[text() = '<-'] or EQ_ASSIGN]/expr[1]/SYMBOL",
        ASSIGN_NODE
      )
    )
    out <- c(out, xml2::xml_text(syms))
  }
  unique(out)
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

# TRUE when a comment line inside an \examples{} block is genuinely COMMENTED-OUT
# CODE rather than explanatory prose.
#
# The old test was `grepl("^\\s*#[^'#].*\\(", ln)`, i.e. "a comment containing an
# open paren". That flags ordinary English: "# Simulate random choices (default)"
# and "# (Columns are attributes, rows are alternatives)" are prose, not disabled
# calls. Explanatory comments in examples are idiomatic and appear throughout base
# R's own Rd files.
#
# The reliable discriminator is R itself: strip the comment marker and try to
# parse. Prose does not parse ("Simulate random choices (default)" is two symbols
# juxtaposed). A disabled call does, and contains a call node.
is_commented_out_code <- function(ln) {
  if (!grepl("^\\s*#", ln, perl = TRUE)) {
    return(FALSE)
  }
  if (grepl("^\\s*#'", ln, perl = TRUE)) {
    return(FALSE)
  } # roxygen, not code
  body <- sub("^\\s*#+\\s*", "", ln, perl = TRUE)
  if (!nzchar(trimws(body))) {
    return(FALSE)
  }

  # Require the SHAPE of a function call, an identifier immediately followed by
  # `(`. Parsing alone is not enough: a decorative separator like `# --- end`
  # parses as unary minus applied three times to a symbol, which is.call() calls
  # a call. And prose alone is not enough either, since "# Simulate choices
  # (default)" contains a paren but does not parse.
  if (!grepl("[\\w.$@]\\s*\\(", body, perl = TRUE)) {
    return(FALSE)
  }

  exprs <- tryCatch(parse(text = body), error = function(e) NULL)
  if (is.null(exprs) || length(exprs) == 0L) {
    return(FALSE)
  }
  any(vapply(as.list(exprs), is.call, logical(1)))
}

# TRUE when an Rd topic carries \keyword{internal}. R's own tools::checkRdContents
# grants such pages substantive leniency (it skips the missing-\value and
# undocumented-argument checks for them), keying off the keyword alone and never
# reading NAMESPACE. It is not merely an index-hiding device.
rd_is_internal <- function(rd) {
  for (sec in rd) {
    if (!identical(attr(sec, "Rd_tag"), "\\keyword")) {
      next
    }
    if (identical(trimws(collect_rd_text(sec)), "internal")) return(TRUE)
  }
  FALSE
}

# Parse a code STRING (rather than a file) and return the xml2 document of its
# parse data, or NULL when it does not parse. Used for code that lives inside
# something else, e.g. the \examples{} block of an .Rd file.
parse_text_xml <- function(text) {
  exprs <- tryCatch(
    parse(text = text, keep.source = TRUE),
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
  gsub("^['\"`]|['\"`]$", "", xml2::xml_text(target))
}

# Is `node`'s innermost enclosing function a console REPORTER, i.e. one whose
# purpose is the output it prints?
#
# THE RULE, AND WHY IT IS THIS NARROW.
#
# The CRAN Repository Policy contains no rule about console output at all. Writing
# R Extensions forbids stdout/stderr writes only from COMPILED code. What is real
# is the CRAN reviewer request, issued constantly:
#
#   "You write information messages to the console that cannot easily be
#    suppressed. Please use message()/warning(), or if (verbose) cat()."
#
# The operative words are "information messages" and "cannot easily be suppressed".
# The harm is to a caller who wanted a VALUE and got noise alongside it. A function
# with no visible return value was called for its side effect: the output is the
# entire observable contract, and there is nothing for the noise to interfere with.
# print.default() is such a function. So is cli::cat_line(). So is every show
# method ever written.
#
# So: flag output only from a function that ALSO hands something back.
#
# This is deliberately the smallest defensible rule. An earlier version added a
# second condition -- a "dead binding", a local computed and then discarded, on the
# theory that `result <- compute(x); cat("Done!\n")` is a leftover notice rather
# than a report. It is, and we no longer flag it. That is a knowing miss. It was
# bought with a false-positive rate we could not defend, on a rule that is a
# reviewer convention rather than policy text, and precision is the only thing this
# package sells.
is_console_reporter <- function(node) {
  fn <- xml2::xml_find_first(node, "ancestor::expr[FUNCTION][1]")
  if (inherits(fn, "xml_missing")) {
    return(FALSE)
  } # top-level code: not our call

  # A function expr is FUNCTION ( formals ) BODY, so the body is its last expr.
  body <- xml2::xml_find_first(fn, "./expr[last()]")
  if (inherits(body, "xml_missing")) {
    return(FALSE)
  }

  stmt_is_side_effect_only(body)
}

# Does the function assign a local it then never reads?
has_dead_binding <- function(fn, body, braced) {
  if (!braced) {
    return(FALSE)
  } # a one-liner has no bindings

  targets <- character(0)
  for (stmt in xml2::xml_find_all(body, sprintf("./%s", ASSIGN_NODE))) {
    nm <- assign_target_of(stmt)
    if (!is.na(nm)) targets <- c(targets, nm)
  }
  if (length(targets) == 0L) {
    return(FALSE)
  }

  all_syms <- xml2::xml_text(xml2::xml_find_all(fn, ".//SYMBOL"))
  for (nm in unique(targets)) {
    n_assigned <- sum(targets == nm)
    n_total <- sum(all_syms == nm)
    # Every appearance was as an assignment target, so it is never read.
    if (n_total <= n_assigned) return(TRUE)
  }
  FALSE
}

# Calls whose value is never the point.
SIDE_EFFECT_CALLS <- c(
  "invisible",
  "cat",
  "print",
  "message",
  "packageStartupMessage",
  "writeLines",
  "warning",
  "stop",
  "show", # S4's print
  "str",
  "summary",
  "abort",
  "inform",
  "warn", # rlang's condition signallers
  "invokeRestart",
  "signalCondition", # control flow: never returns a value
  "tryInvokeRestart",
  "flush.console"
)

stmt_is_side_effect_only <- function(expr, depth = 0L) {
  if (depth > 6L) {
    return(FALSE)
  } # deeply nested if/else; give up rather than loop

  # A loop and a bare NULL both evaluate to invisible NULL.
  if (length(xml2::xml_find_all(expr, "./FOR | ./WHILE | ./REPEAT")) > 0L) {
    return(TRUE)
  }
  if (length(xml2::xml_find_all(expr, "./NULL_CONST")) > 0L) {
    return(TRUE)
  }

  # An `if` evaluates to whichever BRANCH is taken, so it is side-effect-only when
  # every branch is. Looking at `./expr[1]` here reads the CONDITION instead, which
  # is how knitr's normal_print(), a pure dispatcher whose two branches are
  # `methods::show(x)` and `print(x)`, was reported as leaking output.
  # A one-armed `if` evaluates to invisible NULL when false, so only the branches
  # that exist need checking.
  if (length(xml2::xml_find_all(expr, "./IF")) > 0L) {
    branches <- xml2::xml_find_all(expr, "./expr[position() > 1]")
    if (length(branches) == 0L) {
      return(TRUE)
    }
    return(all(vapply(
      branches,
      stmt_is_side_effect_only,
      logical(1),
      depth = depth + 1L
    )))
  }

  # A braced block evaluates to its last statement.
  if (length(xml2::xml_find_all(expr, "./OP-LEFT-BRACE")) > 0L) {
    last <- xml2::xml_find_first(expr, sprintf("./%s[last()]", ASSIGN_NODE))
    if (inherits(last, "xml_missing")) {
      return(TRUE)
    } # `{}` evaluates to NULL
    return(stmt_is_side_effect_only(last, depth + 1L))
  }

  # The callee of `f(...)` and of `pkg::f(...)` alike.
  fn <- xml2::xml_text(
    xml2::xml_find_first(expr, "./expr[1]/SYMBOL_FUNCTION_CALL")
  )
  if (is.na(fn)) {
    return(FALSE)
  }
  if (fn %in% SIDE_EFFECT_CALLS) {
    return(TRUE)
  }
  if (startsWith(fn, "cli_")) {
    return(TRUE)
  }

  # `return(invisible(x))` is still a side effect; look through the return().
  if (identical(fn, "return")) {
    inner <- xml2::xml_find_first(expr, "./expr[2]")
    if (inherits(inner, "xml_missing")) {
      return(TRUE)
    } # bare return()
    return(stmt_is_side_effect_only(inner, depth + 1L))
  }
  FALSE
}

# Is this `print()` writing a FILE rather than the console?
#
# officer defines print.rpptx(x, target, ...) and print.docx likewise, so
# `print(doc, output_file)` is how you SAVE a document. It produces no console
# output at all. A console print takes the object alone.
#
# The tell is a second positional argument that names a destination. `print(x,
# digits = 3)` is console output and passes a NAMED argument, so it is untouched.
is_file_writing_print <- function(node) {
  call <- xml2::xml_find_first(node, "parent::expr/parent::expr")
  if (inherits(call, "xml_missing")) {
    return(FALSE)
  }
  # Positional args only: a named arg arrives as SYMBOL_SUB/EQ_SUB, not an expr.
  args <- xml2::xml_find_all(call, "./expr[position() > 1]")
  if (length(args) < 2L) {
    return(FALSE)
  }

  dest <- args[[2L]]
  sym <- xml2::xml_text(xml2::xml_find_first(dest, "./SYMBOL"))
  if (
    !is.na(sym) &&
      grepl("file|path|target|output|dest|con$|dir", sym, ignore.case = TRUE)
  ) {
    return(TRUE)
  }
  # A literal path handed to print() is a write too.
  !is.na(xml2::xml_text(xml2::xml_find_first(dest, "./STR_CONST")))
}

# ---- write-destination analysis ---------------------------------------------

# Which argument of a write function names the destination. The position differs
# per function, and assuming "the second argument" (as an earlier version did)
# reads the CONTENT argument of file.create() as its path.
# Every call that sends output to a destination, mapped to the position that
# destination sits in. NA means the destination is only ever named, as in
# `save(x, file = "out.rda")`. This is the single list the write-related checks
# share, so one of them cannot quietly know about a function the others do not.
WRITE_DEST_ARG <- list(
  # base and utils
  write.csv = 2L,
  write.csv2 = 2L,
  write.table = 2L,
  writeLines = 2L,
  writeBin = 2L,
  saveRDS = 2L,
  write = 2L,
  cat = NA_integer_,
  save = NA_integer_, # `save(x, y, file = "...")`: named only
  save.image = 1L,
  capture.output = NA_integer_, # `capture.output(x, file = "...")`
  file.create = 1L,
  dir.create = 1L,
  file.copy = 2L,
  file.rename = 2L,
  file.append = 1L,
  download.file = 2L,
  sink = 1L,
  # readr
  write_csv = 2L,
  write_csv2 = 2L,
  write_tsv = 2L,
  write_delim = 2L,
  write_excel_csv = 2L,
  write_rds = 2L,
  write_lines = 2L,
  write_file = 2L,
  # data.table, and the spreadsheet writers
  fwrite = 2L,
  write_xlsx = 2L,
  write.xlsx = 2L,
  saveWorkbook = 2L,
  # other serialisers
  write_json = 2L,
  write_yaml = 2L,
  write_parquet = 2L,
  write_feather = 2L,
  # graphics devices
  png = 1L,
  pdf = 1L,
  jpeg = 1L,
  tiff = 1L,
  bmp = 1L,
  svg = 1L,
  postscript = 1L,
  cairo_pdf = 1L,
  ggsave = 1L
)

# The functions the write checks look for. Derived from the map above so the two
# can never disagree about what counts as a write.
WRITE_FUNCTIONS <- names(WRITE_DEST_ARG)

# Names a destination can travel under.
DEST_ARG_NAMES <- c(
  "file",
  "con",
  "path",
  "filename",
  "target",
  "destfile",
  "sink" # arrow's write_parquet(x, sink = ...)
)

# The expression node a write call sends its output TO, or NULL.
write_destination <- function(node) {
  fn <- xml2::xml_text(node)
  call <- xml2::xml_find_first(node, "parent::expr/parent::expr")
  if (inherits(call, "xml_missing")) {
    return(NULL)
  }

  # A named destination wins wherever it appears in the argument list.
  named <- xml2::xml_find_first(
    call,
    sprintf(
      "./SYMBOL_SUB[%s]/following-sibling::expr[1]",
      paste(sprintf("text() = '%s'", DEST_ARG_NAMES), collapse = " or ")
    )
  )
  if (!inherits(named, "xml_missing")) {
    return(named)
  }

  pos <- WRITE_DEST_ARG[[fn]]
  if (is.null(pos) || is.na(pos)) {
    return(NULL)
  }
  # Positional args are the call's expr children after the function-name expr.
  arg <- xml2::xml_find_first(
    node,
    sprintf(
      "parent::expr/following-sibling::expr[%d]",
      pos
    )
  )
  if (inherits(arg, "xml_missing")) NULL else arg
}

# Is `dest` a path we can PROVE lands in the user's filespace?
#
# CRAN's rule is about writing to the user's filespace WITHOUT PERMISSION. A
# destination the caller handed in, or one computed at run time, is not something
# we can prove anything about, and flagging every `writeLines(x, out_file)` is
# the noise this package exists to avoid. Only a literal can be proven.
#
# `formals_with_unsafe_default` closes the obvious hole: a destination that IS a
# symbol, but a symbol that DEFAULTS to a literal home or absolute path, writes
# there whenever the caller omits it.
dest_is_unsafe_literal <- function(dest, formals_unsafe = character(0)) {
  if (is.null(dest)) {
    return(FALSE)
  }

  # tempfile()/tempdir() anywhere in the destination makes it safe by definition.
  if (
    length(xml2::xml_find_all(
      dest,
      ".//SYMBOL_FUNCTION_CALL[text() = 'tempfile' or text() = 'tempdir']"
    )) >
      0L
  ) {
    return(FALSE)
  }

  # Only the ROOT of a path decides where it lands. In
  # `file.path(temp_pkg, "NEWS.md")` the literal is just the basename, and the
  # root is a variable, so the write goes wherever temp_pkg points. Looking for a
  # string literal ANYWHERE in the destination flagged exactly this, in checktor's
  # own example_diagnose_scenario().
  root <- dest_root(dest)
  if (is.null(root)) {
    return(FALSE)
  }

  sym <- xml2::xml_text(xml2::xml_find_first(root, "./SYMBOL"))
  if (!is.na(sym)) {
    # Caller-supplied or computed: unprovable, unless it defaults somewhere bad.
    return(sym %in% formals_unsafe)
  }

  # A literal root is the one destination we can prove. An absolute or `~` root
  # writes to the user's filespace; a bare relative root writes to the working
  # directory, which CRAN forbids just the same.
  !is.na(xml2::xml_text(xml2::xml_find_first(root, "./STR_CONST")))
}

# The leading component of a path expression. `file.path(a, b)` is rooted at `a`,
# and `paste0(dir, "/x")` at `dir`; a bare symbol or literal is its own root.
dest_root <- function(node, depth = 0L) {
  if (is.null(node) || depth > 5L) {
    return(node)
  }
  callee <- xml2::xml_find_first(node, "./expr[1]/SYMBOL_FUNCTION_CALL")
  if (inherits(callee, "xml_missing")) {
    return(node)
  } # not a call: this IS the root
  first_arg <- xml2::xml_find_first(node, "./expr[2]")
  if (inherits(first_arg, "xml_missing")) {
    return(node)
  }
  dest_root(first_arg, depth + 1L)
}

# Formals of the innermost enclosing function whose DEFAULT is a literal home or
# absolute path: `function(path = "~/data.csv")` writes to $HOME when called with
# no arguments.
formals_with_unsafe_default <- function(node) {
  fn <- xml2::xml_find_first(node, "ancestor::expr[FUNCTION][1]")
  if (inherits(fn, "xml_missing")) {
    return(character(0))
  }
  bad <- xml2::xml_find_all(
    fn,
    paste0(
      "./SYMBOL_FORMALS[following-sibling::*[1][self::EQ_FORMALS]]",
      "[following-sibling::*[2][self::expr]/STR_CONST[",
      "  starts-with(text(), '\"~') or starts-with(text(), \"'~\")",
      "  or starts-with(text(), '\"/') or starts-with(text(), \"'/\")",
      "]]"
    )
  )
  xml2::xml_text(bad)
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
  fn <- xml2::xml_find_first(node, "ancestor::expr[FUNCTION][1]")
  if (inherits(fn, "xml_missing")) {
    return(FALSE)
  }
  body <- xml2::xml_find_first(fn, "./expr[last()]")
  if (inherits(body, "xml_missing")) {
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
  if (is.na(ret)) {
    return(FALSE)
  }

  targets <- character(0)
  for (stmt in xml2::xml_find_all(body, sprintf("./%s", ASSIGN_NODE))) {
    nm <- assign_target_of(stmt)
    if (!is.na(nm)) targets <- c(targets, nm)
  }
  ret %in% targets
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

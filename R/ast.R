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

# Parse every R/*.R file under `path` and return a named list (one entry per
# file) of:
#   $file   - absolute path
#   $xml    - xml2 document of the parse data, or NULL if parse failed
#   $error  - simpleError if parse failed, otherwise NULL
read_r_xml <- function(path) {
  r_files <- list_r_files(path)
  setNames(lapply(r_files, parse_one_r_file), r_files)
}

# Parse a single file. parse() raises on syntax errors; we catch and report
# the file:line:col so downstream checks can surface a clear lint instead of
# crashing the whole run.
parse_one_r_file <- function(file) {
  tryCatch({
    exprs <- parse(file, keep.source = TRUE)
    pd <- utils::getParseData(exprs)
    if (is.null(pd) || nrow(pd) == 0L) {
      return(list(file = file, xml = NULL, error = NULL))
    }
    xml <- xml2::read_xml(xmlparsedata::xml_parse_data(pd))
    list(file = file, xml = xml, error = NULL)
  }, error = function(e) {
    list(file = file, xml = NULL, error = e)
  })
}

# Run an XPath query against every parsed file. Returns a character vector of
# "basename:line" hits, suitable for the existing $issues format. `label` is
# an optional suffix appended in parens (e.g. " (path.expand('~'))").
xpath_lints <- function(parsed, xpath, label = NULL) {
  hits <- character(0)
  for (p in parsed) {
    if (is.null(p$xml)) next
    nodes <- xml2::xml_find_all(p$xml, xpath)
    if (length(nodes) == 0L) next
    lines <- xml2::xml_attr(nodes, "line1")
    suffix <- if (is.null(label)) "" else paste0(" (", label, ")")
    hits <- c(hits, paste0(basename(p$file), ":", lines, suffix))
  }
  hits
}

# Per-file XPath: run `xpath` against each file separately and apply `summarise`
# to each matching node-set in turn. `summarise(file, nodes)` should return a
# character vector of issue strings.
xpath_per_file <- function(parsed, xpath, summarise) {
  hits <- character(0)
  for (p in parsed) {
    if (is.null(p$xml)) next
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
    if (is.null(p$error)) next
    out <- c(out, paste0(basename(p$file), ": parse error: ",
                         conditionMessage(p$error)))
  }
  out
}

# The "flag any call to function X" pattern. `funs` is a character vector of
# function names. Optionally pass `label` to append `(fn_name)` to each hit.
undesirable_function_check <- function(parsed, funs, label = TRUE) {
  if (length(funs) == 0L) return(character(0))
  predicate <- paste(sprintf("text() = '%s'", funs), collapse = " or ")
  xpath <- sprintf("//SYMBOL_FUNCTION_CALL[%s]", predicate)
  if (!isTRUE(label)) {
    return(xpath_lints(parsed, xpath))
  }
  # Per-file: include the matched function name in the issue string.
  xpath_per_file(parsed, xpath, function(file, nodes) {
    paste0(basename(file), ":",
           xml2::xml_attr(nodes, "line1"),
           " (", xml2::xml_text(nodes), "())")
  })
}

# XPath fragment that, placed after a node test, restricts to nodes whose
# innermost enclosing function-body does NOT contain a call to any of `funs`.
# Used by checks like option_changes (no on.exit/withr) and temp_cleanup.
not_under_fn_with_call_xpath <- function(funs) {
  predicate <- paste(sprintf("text() = '%s'", funs), collapse = " or ")
  sprintf(
    "not(ancestor::expr[parent::expr/FUNCTION][1]//SYMBOL_FUNCTION_CALL[%s])",
    predicate
  )
}

# ---- Rd helpers --------------------------------------------------------------
# tools::parse_Rd() returns a recursive list. Each section element carries
# attr(., "Rd_tag") e.g. "\\value", "\\examples", "\\dontrun", "TEXT".

# Returns the first top-level child whose Rd_tag equals `tag`, or NULL.
extract_rd_section <- function(rd, tag) {
  for (sec in rd) {
    if (identical(attr(sec, "Rd_tag"), tag)) return(sec)
  }
  NULL
}

# Recursively collects text from an Rd node, skipping any subtree whose top
# tag is in `skip` (e.g. skip = c("\\dontrun") when collecting an \examples
# block for code that would actually run).
collect_rd_text <- function(node, skip = character(0)) {
  tag <- attr(node, "Rd_tag")
  if (!is.null(tag) && tag %in% skip) return("")
  if (is.character(node)) return(paste(node, collapse = ""))
  if (is.list(node)) {
    parts <- vapply(node, collect_rd_text, character(1),
                    skip = skip, USE.NAMES = FALSE)
    return(paste(parts, collapse = ""))
  }
  ""
}

# The name of the innermost top-level function a node sits inside, or "" when the
# node is not inside a named function. Used to attribute a hit to its function so
# call-graph reasoning can act on it.
enclosing_function_name <- function(node) {
  fn <- xml2::xml_find_first(
    node,
    "ancestor::expr[FUNCTION][parent::*/expr[1]/SYMBOL][1]"
  )
  if (inherits(fn, "xml_missing")) return("")
  sym <- xml2::xml_find_first(fn, "parent::*/expr[1]/SYMBOL")
  if (inherits(sym, "xml_missing")) return("")
  xml2::xml_text(sym)
}

# Names of functions whose output is only ever reachable through an S3 output
# method, i.e. print-method delegates.
#
# An S3 print method may hand its cat()ing off to a helper (cbcTools does this
# with print_structure_section() and friends). The helper is not itself a method,
# so a name-based exemption cannot see it. But if EVERY caller of the helper is
# an S3 print/format/summary method, its output is reachable only via one, which
# is behaviourally identical to inlining it. Callers are resolved across all
# parsed files. A helper with no callers, or with even one non-method caller, is
# not a delegate.
s3_output_delegates <- function(parsed) {
  is_method <- function(nm) grepl("^(print|format|summary)\\.", nm)

  defined <- character(0)   # every top-level function name
  callers <- list()         # callee -> character vector of caller names

  for (p in parsed) {
    if (!is.null(p$error) || is.null(p$xml)) next
    fns <- xml2::xml_find_all(
      p$xml, "//expr[FUNCTION][parent::*/expr[1]/SYMBOL]"
    )
    for (fn in fns) {
      sym <- xml2::xml_find_first(fn, "parent::*/expr[1]/SYMBOL")
      if (inherits(sym, "xml_missing")) next
      nm <- xml2::xml_text(sym)
      defined <- c(defined, nm)
      callees <- unique(xml2::xml_text(
        xml2::xml_find_all(fn, ".//SYMBOL_FUNCTION_CALL")
      ))
      for (ce in callees) {
        callers[[ce]] <- c(callers[[ce]], nm)
      }
    }
  }
  defined <- unique(defined)
  if (length(defined) == 0L) return(character(0))

  local_defs <- setdiff(defined, defined[is_method(defined)])
  keep <- vapply(local_defs, function(nm) {
    cs <- callers[[nm]]
    length(cs) > 0L && all(is_method(cs))
  }, logical(1))
  local_defs[keep]
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
  if (inherits(e, "xml_missing")) return("")
  # `x <<- v` -> SYMBOL; `x$f <<- v` / `x[[i]] <<- v` -> the base symbol.
  sym <- xml2::xml_find_first(e, "descendant-or-self::SYMBOL[1]")
  if (inherits(sym, "xml_missing")) "" else xml2::xml_text(sym)
}

# Every name bound at package top level: `nm <- ...` at the file's top level.
# A `<<-` to one of these writes into the package namespace, not .GlobalEnv.
package_level_names <- function(parsed) {
  out <- character(0)
  for (p in parsed) {
    if (!is.null(p$error) || is.null(p$xml)) next
    syms <- xml2::xml_find_all(
      p$xml,
      "/exprlist/expr[LEFT_ASSIGN[text() = '<-'] or EQ_ASSIGN]/expr[1]/SYMBOL"
    )
    out <- c(out, xml2::xml_text(syms))
  }
  unique(out)
}

# TRUE when `target` is already bound somewhere in an enclosing function: as a
# formal, or by an ordinary `<-` in that function's body. In that case `<<-`
# rebinds THERE and never reaches .GlobalEnv.
binds_in_enclosing_function <- function(op, target) {
  fns <- xml2::xml_find_all(op, "ancestor::expr[FUNCTION]")
  if (length(fns) == 0L) return(FALSE)
  for (fn in fns) {
    formals_hit <- xml2::xml_find_all(
      fn, sprintf("SYMBOL_FORMALS[text() = '%s']", target)
    )
    if (length(formals_hit) > 0L) return(TRUE)
    # `<<-` is itself a LEFT_ASSIGN token, so the operator text has to be pinned
    # to `<-`. Without that, a super-assign matches as its own local binding and
    # every global write exempts itself.
    local_hit <- xml2::xml_find_all(
      fn,
      sprintf(
        ".//expr[LEFT_ASSIGN[text() = '<-'] or EQ_ASSIGN]/expr[1]/SYMBOL[text() = '%s']",
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
  if (!grepl("^\\s*#", ln, perl = TRUE)) return(FALSE)
  if (grepl("^\\s*#'", ln, perl = TRUE)) return(FALSE)   # roxygen, not code
  body <- sub("^\\s*#+\\s*", "", ln, perl = TRUE)
  if (!nzchar(trimws(body))) return(FALSE)

  # Require the SHAPE of a function call, an identifier immediately followed by
  # `(`. Parsing alone is not enough: a decorative separator like `# --- end`
  # parses as unary minus applied three times to a symbol, which is.call() calls
  # a call. And prose alone is not enough either, since "# Simulate choices
  # (default)" contains a paren but does not parse.
  if (!grepl("[\\w.$@]\\s*\\(", body, perl = TRUE)) return(FALSE)

  exprs <- tryCatch(parse(text = body), error = function(e) NULL)
  if (is.null(exprs) || length(exprs) == 0L) return(FALSE)
  any(vapply(as.list(exprs), is.call, logical(1)))
}

# TRUE when an Rd topic carries \keyword{internal}. R's own tools::checkRdContents
# grants such pages substantive leniency (it skips the missing-\value and
# undocumented-argument checks for them), keying off the keyword alone and never
# reading NAMESPACE. It is not merely an index-hiding device.
rd_is_internal <- function(rd) {
  for (sec in rd) {
    if (!identical(attr(sec, "Rd_tag"), "\\keyword")) next
    if (identical(trimws(collect_rd_text(sec)), "internal")) return(TRUE)
  }
  FALSE
}

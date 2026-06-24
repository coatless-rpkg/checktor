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

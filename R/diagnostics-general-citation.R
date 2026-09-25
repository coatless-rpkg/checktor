# General check on inst/CITATION.

#' Diagnose Old-Style or Unsafe Calls in inst/CITATION
#'
#' Flags an `inst/CITATION` that calls the old-style `citEntry()` (use
#' `bibentry()`) or `personList()` and `as.personList()` (use `c()` on `person`
#' objects), or that calls `packageDescription()`, `library()` or `require()`.
#' R passes the file a `meta` object holding the package's DESCRIPTION, so it
#' needs none of those, and each assumes the package is already installed.
#'
#' As in R, the fallback
#' `if (!exists("meta") || is.null(meta)) meta <- packageDescription("pkg")`
#' is exempt: a top-level `if` with exactly that condition and no `else`. The file is parsed and never run, so a name in a
#' comment or a string is not a call. A CITATION that does not parse is reported,
#' with the line R stops at. A CITATION that `.Rbuildignore` excludes is not in
#' the tarball and is not read.
#'
#' @section Source:
#' The [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' (`R CMD check --as-cran`) NOTEs "Package CITATION file contains call(s) to
#' old-style citEntry(). Please use bibentry() instead." and "... old-style
#' personList() or as.personList(). Please use c() on person objects instead.",
#' and lists calls to `packageDescription`, `library` and `require`.
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#CITATION-files),
#' under "CITATION files", says "It is desirable (and essential for CRAN) that the
#' CITATION file does not contain calls to functions such as packageDescription
#' which assume the package is installed in a library tree on the package search
#' path." `devtools::check()` turns the incoming check off by default. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("general_examples/citation_file_bad.CITATION",
#'                                  show_content = FALSE)
#' lab_citation_file(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_citation_file <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  file <- list_included_files(path, "inst", "^CITATION$")
  if (length(file) == 0L) {
    return(pass_result(check_label("citation_file")))
  }
  rel <- "inst/CITATION"
  lines <- citation_lines(file, path)

  # Parse only; never evaluate. parse_text_xml() says only whether it parsed, so
  # the reason comes from a plain parse() of the same text.
  err <- tryCatch(
    {
      parse(text = lines, keep.source = FALSE)
      NULL
    },
    error = function(e) conditionMessage(e)
  )
  issues <- if (!is.null(err)) {
    # R words the position "<text>:3:5: unexpected symbol" for a syntax error
    # and "invalid multibyte character in parser (<input>:1:20)" for an encoding
    # one. Either way the finding leads with the file, line and column.
    first <- strsplit(err, "\n", fixed = TRUE)[[1]][[1]]
    pos <- "<(text|input)>:([0-9]+:[0-9]+)"
    at <- regmatches(first, regexec(pos, first))[[1]]
    reason <- trimws(gsub(paste0("\\(?", pos, "\\)?:? ?"), "", first))
    if (length(at) == 3L) {
      lc <- strsplit(at[[3]], ":", fixed = TRUE)[[1]]
      sprintf(
        "%s:%s (does not parse: %s at column %s)",
        rel,
        lc[[1]],
        reason,
        lc[[2]]
      )
    } else {
      paste0(rel, " (does not parse: ", reason, ")")
    }
  } else {
    citation_call_issues(parse_text_xml(lines), rel)
  }

  report_check(
    issues,
    verbose,
    check_label("citation_file"),
    "inst/CITATION uses bibentry() and the meta object",
    if (is.null(err)) {
      "inst/CITATION has calls CRAN asks to replace"
    } else {
      "inst/CITATION does not parse"
    },
    treatment = paste("Treatment:", treatments$citation_file$treatment),
    level = "warning"
  )
}

# The CITATION's lines as UTF-8. R reads the file in the package's declared
# Encoding, so a latin1 package's CITATION is re-encoded rather than rejected.
citation_lines <- function(file, path) {
  lines <- safe_read_lines(file)
  enc <- description_value(path, "Encoding")
  if (!is.na(enc) && !toupper(enc) %in% c("UTF-8", "UTF8")) {
    converted <- iconv(lines, from = enc, to = "UTF-8")
    if (!anyNA(converted)) lines <- converted
  }
  lines
}

# What each flagged call should become.
CITATION_CALL_ADVICE <- c(
  citEntry = "is old-style; use bibentry()",
  personList = "is old-style; use c() on person objects",
  as.personList = "is old-style; use c() on person objects",
  packageDescription = paste(
    "assumes the package is installed; read the DESCRIPTION from the `meta`",
    "object R passes to the file"
  ),
  library = "assumes the package is installed; a CITATION file loads nothing",
  require = "assumes the package is installed; a CITATION file loads nothing"
)

# The exempt fallback, as R tests it: a top-level `if`, with no else, whose
# condition is `!exists("meta") || is.null(meta)`. Compared token by token, with
# the string requoted in double quotes, which is what R's deparse() comparison
# amounts to: spacing and quote style do not matter, anything else does.
META_FALLBACK <- '! exists ( "meta" ) || is.null ( meta )'
META_FALLBACK_TOKENS <- strsplit(META_FALLBACK, " ", fixed = TRUE)[[1]]

is_meta_fallback <- function(expr) {
  if (
    length(xml2::xml_find_all(expr, "./IF")) != 1L ||
      length(xml2::xml_find_all(expr, "./ELSE")) > 0L
  ) {
    return(FALSE)
  }
  cond <- xml2::xml_find_first(
    expr,
    "./OP-LEFT-PAREN/following-sibling::expr[1]"
  )
  tokens <- xml2::xml_find_all(cond, ".//*[not(*)]")
  text <- xml2::xml_text(tokens)
  str <- xml2::xml_name(tokens) == "STR_CONST"
  text[str] <- paste0('"', unquote_name(text[str]), '"')
  identical(text, META_FALLBACK_TOKENS)
}

citation_call_issues <- function(xml, rel) {
  if (is.null(xml)) {
    return(character(0))
  }
  top <- xml2::xml_find_all(xml, "/exprlist/expr")
  exempt <- xml2::xml_path(top[vapply(top, is_meta_fallback, logical(1))])

  funs <- names(CITATION_CALL_ADVICE)
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[",
    paste0("text() = '", funs, "'", collapse = " or "),
    "]"
  )
  nodes <- xml2::xml_find_all(xml, xpath)
  fn <- xml2::xml_text(nodes)
  in_fallback <- vapply(
    nodes,
    function(n) {
      owner <- xml2::xml_find_first(n, "ancestor::expr[parent::exprlist]")
      xml2::xml_path(owner) %in% exempt
    },
    logical(1)
  )
  # The fallback excuses the calls that assume an installed package, which is all
  # R lets it excuse; an old-style call is old-style wherever it sits.
  keep <- !(in_fallback & fn %in% c("packageDescription", "library", "require"))
  nodes <- nodes[keep]
  fn <- fn[keep]
  if (length(fn) == 0L) {
    return(character(0))
  }
  # "file:line (label)", the shape issues() and ci_report() read a location from.
  sprintf(
    "%s:%s (%s() %s)",
    rel,
    xml2::xml_attr(nodes, "line1"),
    fn,
    unname(CITATION_CALL_ADVICE[fn])
  )
}

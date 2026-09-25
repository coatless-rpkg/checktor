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

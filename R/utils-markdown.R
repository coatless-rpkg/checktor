# Markdown scanning shared by the checks that read a README or a vignette.
#
# A README is markdown, and the parts a renderer treats as literal are not
# markup. Scanning the raw file makes R code look like markup: because
# `knitr::opts_chunk[["set"]](` ends in `](`, a setup chunk reported its own
# arguments as a link to a file that does not exist. Blank the literal spans
# first and the rest of the scan can stay a regex.

# A fence opener or closer: up to three spaces of indent, then a run of at
# least three backticks or tildes.
MD_FENCE_RE <- "^ {0,3}(`{3,}|~{3,})"

#' Blank Out Fenced Code Blocks
#'
#' Replaces every line of every fenced code block, both fences included, with an
#' empty string. The line count is preserved, so a caller can still report the
#' line a finding sits on.
#'
#' The rules are CommonMark's, since the renderer's are what decide whether a
#' reader sees code or a link. A fence closes only on the same character, at the
#' same length or longer, with nothing after it, which is what lets a
#' ````` ```` `````-fenced block quote a ` ``` `-fenced one, as a README showing
#' markdown does. A backtick opener whose info string contains a backtick is not
#' a fence. A fence left open at the end of the file runs to the end of the file.
#'
#' The one deliberate departure from CommonMark is a knitr chunk header, which
#' may set an option from inline R and so carry backticks of its own. knitr
#' calls ```` ```{r, eval = `r ok`} ```` a chunk, and so do we.
#'
#' @param lines Character. The lines of a markdown file, as returned by
#'   [safe_read_lines()].
#'
#' @return Character, the same length as `lines`, with fenced lines blanked.
#' @noRd
blank_fenced_code <- function(lines) {
  open <- NULL
  for (i in seq_along(lines)) {
    hit <- regmatches(lines[i], regexpr(MD_FENCE_RE, lines[i]))
    fence <- if (length(hit) == 1L) sub("^ +", "", hit) else ""
    char <- substr(fence, 1L, 1L)
    if (is.null(open)) {
      if (!nzchar(fence)) {
        next
      }
      info <- sub(MD_FENCE_RE, "", lines[i])
      literal <- char == "`" && grepl("`", info, fixed = TRUE)
      if (literal && !grepl("^\\s*\\{", info)) {
        next
      }
      open <- list(char = char, len = nchar(fence))
      lines[i] <- ""
    } else {
      closes <- char == open$char &&
        nchar(fence) >= open$len &&
        grepl(paste0(MD_FENCE_RE, "[ \t]*$"), lines[i])
      lines[i] <- ""
      if (closes) {
        open <- NULL
      }
    }
  }
  lines
}

#' Blank Out Inline Code Spans
#'
#' Replaces each inline code span, its backticks included, with spaces, so the
#' line keeps its length and its columns.
#'
#' CommonMark's rule again: a run of N backticks opens a span that the next run
#' of exactly N backticks closes, and a run that never finds its partner is
#' ordinary text.
#'
#' One line at a time, which CommonMark would not do. A span may cross a line
#' break inside a paragraph, but pairing across a whole file lets one stray
#' backtick in prose find its partner hundreds of lines later and blank every
#' link in between. A README with an odd backtick in it is likelier than one
#' with a code span wrapped over two lines, and losing real links is the worse
#' way to be wrong.
#'
#' @param line Character(1). One line of a markdown file.
#'
#' @return Character(1), the line with its code spans replaced by spaces.
#' @noRd
blank_code_spans <- function(line) {
  runs <- gregexpr("`+", line, perl = TRUE)[[1L]]
  if (runs[1L] == -1L) {
    return(line)
  }
  lens <- attr(runs, "match.length")
  chars <- strsplit(line, "", fixed = TRUE)[[1L]]
  open <- 1L
  while (open <= length(runs)) {
    close <- open + 1L
    while (close <= length(runs) && lens[close] != lens[open]) {
      close <- close + 1L
    }
    if (close > length(runs)) {
      open <- open + 1L
      next
    }
    chars[seq.int(runs[open], runs[close] + lens[close] - 1L)] <- " "
    open <- close + 1L
  }
  paste(chars, collapse = "")
}

#' Blank Out Everything a Renderer Reads as Literal
#'
#' Removes the three things a markdown renderer will not turn into a link,
#' fenced code blocks, inline code spans and HTML comments, and returns what is
#' left as one string. Run this over a README or vignette before any regex that
#' looks for markup.
#'
#' The match on HTML comments is lazy on purpose, so the
#' `<!-- badges: start -->` / `<!-- badges: end -->` pair that opens most READMEs
#' stays two comments with live badge links between them rather than one comment
#' swallowing the badges.
#'
#' @param lines Character. The lines of a markdown file, as returned by
#'   [safe_read_lines()].
#'
#' @return Character(1). The lines rejoined with `"\n"`, literal spans blanked.
#' @noRd
strip_markdown_code <- function(lines) {
  # A CR is a line ending, not text. R's text-mode connections drop it, but a
  # stray one would leave a closing fence unrecognised and take the rest of the
  # file with it, which is too expensive a way to be wrong about a line ending.
  lines <- blank_fenced_code(sub("\r+$", "", lines))
  lines <- vapply(lines, blank_code_spans, character(1), USE.NAMES = FALSE)
  # (?s) so a comment wrapped over several lines is one comment, and lazy so a
  # comment ends at the first `-->` it reaches, not the last one in the file.
  gsub("(?s)<!--.*?-->", " ", paste(lines, collapse = "\n"), perl = TRUE)
}

# An Rd \examples{} section as R code, with its \dontrun{} and \donttest{}
# blocks marked, laid out on the lines of the .Rd file.

# The marker call each hidden block is wrapped in, so the parse tree records which
# block a call sits in.
HIDDEN_EXAMPLE_MARKERS <- c(
  "\\dontrun" = ".checktor_dontrun",
  "\\donttest" = ".checktor_donttest"
)

# The blocks whose body rd_example_marked() puts on lines of its own, all of
# them with `mark = FALSE` and the ones it does not mark otherwise, as Rd2ex
# lays out a block whose code runs. Rd2ex ends the line the block
# opens on with a label such as `## No test: ` or `## IGNORE_RDIFF_BEGIN`,
# starts the body on the next line, and closes it with a label line such as
# `## End(No test)`, so the code after the closing brace starts a line too. A
# \dontrun{} is the exception. Under R CMD check's default commentDontrun = TRUE
# its body is commented out, and one of a single child is written in place
# after its `## Not run: ` label, taking the rest of the line into the comment.
# With commentDontrun = FALSE it has no label, and its body is on lines of its
# own like the others. checktor reads \dontrun{} code all the same, laid out
# that way: a reader copies it, and CRAN asks about installs and writes
# wherever they appear.
RD_EXAMPLE_BLOCKS <- c(
  "\\dontrun", "\\donttest", "\\dontshow", "\\testonly", "\\dontdiff"
)

# A line break rd_example_marked() adds, told apart from the example's own so
# rd_example_lines() can put each line of code back on its line of the .Rd file.
ADDED_BREAK <- "\001"

# An example as R code, with each \dontrun{} and \donttest{} body wrapped in its
# marker call. Rd `%` comments are dropped, as R drops them. The newline before
# `})` keeps a comment on the body's last line from swallowing the close.
#
# A hidden block may hold something that is not R -- output, JavaScript, a
# `<your key>` placeholder -- which stops the whole example parsing. With
# `repair = TRUE` each block keeps only the code in it that parses, so the rest of
# the example, and any guard around the block, can still be read.
#
# With `mark = FALSE` a block is left as its body, for the checks that ask what
# an example calls rather than which block the call sits in. The body of each
# of RD_EXAMPLE_BLOCKS goes between two added line breaks, as Rd2ex lays out a
# block it runs, so that `\dontrun{f()}\donttest{g()}` reads as two calls rather
# than `f()g()`, while `suppressWarnings(\donttest{f()})` is still one, since R
# reads on past a line break inside parentheses. Those breaks are ADDED_BREAK:
# rd_example_lines() makes the ones that part code newlines, drops the rest,
# and maps each line back to its line of the .Rd file. With `mark = TRUE` the
# blocks that are not marked, such as \dontdiff{} and \dontshow{}, get the same
# breaks, so rd_marked_code() reads `\dontrun{f()}\dontdiff{g()}` as two calls.
#
# An `#ifdef` or `#ifndef` holds code for one platform, and CRAN checks on both,
# so its body is read either way. Its first child is the condition, a platform
# name that is not R. parse_Rd() folds the `#endif` line into the node as well,
# so each directive line becomes a blank one.
rd_example_marked <- function(node, repair = FALSE, mark = TRUE) {
  tag <- attr(node, "Rd_tag")
  if (identical(tag, "COMMENT")) {
    return("")
  }
  if (is.character(node)) {
    return(paste(node, collapse = ""))
  }
  if (!is.list(node)) {
    return("")
  }
  if (!is.null(tag) && tag %in% c("#ifdef", "#ifndef") && length(node) == 2L) {
    condition <- gsub("[^\n]", "", rd_example_marked(node[[1L]]))
    body <- rd_example_marked(node[[2L]], repair = repair, mark = mark)
    return(paste0(condition, body, "\n"))
  }
  body <- paste(
    vapply(
      node,
      rd_example_marked,
      character(1),
      repair = repair,
      mark = mark,
      USE.NAMES = FALSE
    ),
    collapse = ""
  )
  hidden <- !is.null(tag) && tag %in% names(HIDDEN_EXAMPLE_MARKERS)
  if (hidden && repair) {
    body <- parseable_text(body)
  }
  if (!is.null(tag) && tag %in% RD_EXAMPLE_BLOCKS && !(mark && hidden)) {
    return(paste0(ADDED_BREAK, body, ADDED_BREAK))
  }
  if (hidden) {
    return(paste0(HIDDEN_EXAMPLE_MARKERS[[tag]], "({", body, "\n})"))
  }
  body
}

# Code from rd_example_marked() with its added breaks made newlines,
# and the line of the source each line of that code comes from, counting only
# the source's own newlines. A break is kept only where it parts code from
# code: besides the ones drop_idle_breaks() drops, one at the start of a line
# would add nothing but a blank line.
rd_example_lines <- function(text) {
  b <- ADDED_BREAK
  text <- drop_idle_breaks(text)
  text <- gsub(paste0("(^|\n)([ \t]*)", b), "\\1\\2", text, perl = TRUE)
  breaks <- regmatches(text, gregexpr(paste0("[\n", b, "]"), text))[[1L]]
  list(
    code = gsub(b, "\n", text, fixed = TRUE),
    lines = 1L + c(0L, cumsum(breaks == "\n"))
  )
}

# `text` without the ADDED_BREAKs that part no code from code: those in front
# of a line break, another added break, a comment or the end, which would add
# nothing but a blank line, and those in front of whatever continues the line R
# reads: `;`, `else`, or a binary operator no line can start with, such as
# `|>`, `%>%`, `->`, `*` or `==`. A line of R cannot start with those, and at
# the top level R reads a line that starts with `else` as a new statement, so
# with the break the example did not parse. `\dontrun{f()}; g()` is read as
# `f(); g()`, and `\dontrun{f()} |> g()` as `f() |> g()`, on the line each is
# written on. `+`, `-`, `!`, `~` and `?` can start a line, so a break in front
# of them stays.
drop_idle_breaks <- function(text) {
  b <- ADDED_BREAK
  continues <- "\\|>|%[^%\n]*%|->|[*/^&|$@:=<>,)\\]]"
  gsub(
    paste0(b, "(?=[ \t]*(?:\n|", b, "|#|;|else\\b|", continues, "|$))"),
    "",
    text,
    perl = TRUE
  )
}

# The parts of `text` that parse, for code that will not parse whole, with every
# other line blanked so each part stays on its own line. A chunk grows a line at a
# time while the parser says more input could complete it, and a line nothing can
# complete is blanked. The parser's message is translated, so this reads only the
# `<text>:line:col:` position in front of it, and the INCOMPLETE_STRING token
# name, which are not.
#
# An ADDED_BREAK from a block nested in this one parts lines as a newline does,
# and is put back as it was, so `suppressWarnings(\dontrun{f()})` parses over
# three lines when one of them alone would not. The breaks rd_example_lines()
# would drop are dropped first, so `\dontrun{f()}; g()` is still one line.
parseable_text <- function(text) {
  text <- drop_idle_breaks(text)
  line_break <- paste0("[\n", ADDED_BREAK, "]")
  breaks <- regmatches(text, gregexpr(line_break, text))[[1L]]
  # strsplit() drops a trailing empty line, and that line is where whatever
  # follows the block begins.
  lines <- strsplit(paste0(text, "\n"), line_break)[[1L]]
  keep <- logical(length(lines))
  start <- 1L
  while (start <= length(lines)) {
    end <- start
    kept <- FALSE
    repeat {
      chunk <- paste(lines[start:end], collapse = "\n")
      err <- tryCatch(
        {
          parse(text = chunk, keep.source = FALSE)
          NULL
        },
        error = conditionMessage
      )
      if (is.null(err)) {
        keep[start:end] <- TRUE
        start <- end + 1L
        kept <- TRUE
        break
      }
      at_line <- suppressWarnings(
        as.integer(sub("^<text>:([0-9]+):.*", "\\1", err))
      )
      incomplete <- isTRUE(at_line > end - start + 1L) ||
        grepl("INCOMPLETE_STRING", err, fixed = TRUE)
      if (!incomplete || end >= length(lines)) {
        break
      }
      end <- end + 1L
    }
    if (!kept) {
      start <- start + 1L
    }
  }
  lines[!keep] <- ""
  paste(paste0(lines, c(breaks, "")), collapse = "")
}

# The outermost \dontrun{} and \donttest{} blocks.
rd_hidden_blocks <- function(node) {
  tag <- attr(node, "Rd_tag")
  if (!is.null(tag) && tag %in% names(HIDDEN_EXAMPLE_MARKERS)) {
    return(list(node))
  }
  if (is.list(node)) {
    return(unlist(lapply(node, rd_hidden_blocks), recursive = FALSE))
  }
  list()
}

# Whether a node sits inside one of the hidden blocks named by `tags`, read from
# the marker call rd_example_marked() wraps each block in. Any enclosing block
# counts, so a \donttest{} inside a \dontrun{} is still never run.
in_hidden_block <- function(node, tags = names(HIDDEN_EXAMPLE_MARKERS)) {
  xpath <- paste0(
    "ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[",
    paste0("text() = '", HIDDEN_EXAMPLE_MARKERS[tags], "'", collapse = " or "),
    "]]"
  )
  length(xml2::xml_find_all(node, xpath)) > 0L
}

# An \examples{} section as parsed R, with each hidden block marked, or NULL when
# even the repaired code will not parse. The code outside the hidden blocks is what
# R CMD check runs, so when that will not parse the example fails the check on its
# own, and there is nothing left for another check to judge.
rd_example_xml <- function(examples) {
  xml <- parse_text_xml(rd_marked_code(examples))
  if (is.null(xml)) {
    xml <- parse_text_xml(rd_marked_code(examples, repair = TRUE))
  }
  xml
}

# An example, or one block of it, as R code with each hidden block marked: the
# text of rd_example_marked() with its added breaks made newlines where they
# part code from code.
rd_marked_code <- function(node, repair = FALSE) {
  rd_example_lines(rd_example_marked(node, repair = repair))$code
}

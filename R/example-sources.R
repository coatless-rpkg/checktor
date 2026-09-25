# The code CRAN reviews besides R/.
#
# Every code-side check reads list_r_files(), which is R/*.R and nothing else.
# The rejections maintainers actually receive are just as often about examples,
# vignettes and demos: an install.packages() in an example, a write to getwd(),
# an options() call in inst/demo that is never put back. This collects that code
# and parses it, so a check can query it with the same XPath helpers it uses for
# R/ sources.

# Where each kind of code lives, relative to the package root.
EXAMPLE_SOURCE_DIRS <- list(
  vignette = "vignettes",
  demo = c("demo", file.path("inst", "demo")),
  test = c(file.path("tests", "testthat"), "tests")
)

# R code from a package's `.Rd` examples, one entry per file that has any. Each
# line of code is on the line of the .Rd file it came from, so a finding names the
# line a reader opens. Where a block such as \dontrun{} shares a line with other
# code, its body is put on lines of its own, as Rd2ex lays out a block it runs
# (see RD_EXAMPLE_BLOCKS), and `lines` then gives the .Rd line of each line of
# `code`.
rd_example_code <- function(path) {
  files <- list_rd_files(path)
  out <- list()
  for (file in files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    section <- extract_rd_section(rd, "\\examples")
    if (is.null(section)) {
      next
    }
    # The example as R runs it: an Rd `%` comment is not R, and kept in the text
    # it stopped the whole example parsing, which hid the example from every
    # check. \dontrun{} contents are included: a reader copies them, and CRAN
    # asks about installs and writes wherever they appear in an example.
    src <- rd_example_source(section)
    # A hidden block may hold something that is not R, such as a `<your key>`
    # placeholder. Only then is each block cut down to the lines that parse, since
    # reading a block a line at a time can split a valid `if` from its `else`.
    # lab_example_unparseable() reads the example unrepaired, so this repair lets
    # the other checks read the rest without hiding that it was needed.
    if (!parses(src$code)) {
      src <- rd_example_source(section, repair = TRUE)
    }
    if (!nzchar(trimws(src$code))) {
      next
    }
    out[[length(out) + 1L]] <- list(
      file = file,
      kind = "example",
      code = src$code,
      # NULL when every line of code is on its own line of the file.
      lines = if (!identical(src$lines, seq_along(src$lines))) src$lines
    )
  }
  out
}

# An Rd \examples{} section as R code, each line on the line of the .Rd file it
# comes from: list(code, lines), as rd_example_lines() gives it. With `repair =
# TRUE` each \dontrun{} and \donttest{} block keeps only the lines that parse.
rd_example_source <- function(section, repair = FALSE) {
  offset <- strrep("\n", rd_node_line(section) - 1L)
  rd_example_lines(
    paste0(offset, rd_example_marked(section, repair = repair, mark = FALSE))
  )
}

# Put each node of code parsed by parse_text_xml() on the line of its file that
# `lines` gives for it, for code whose lines are not the file's one for one.
remap_lines <- function(xml, lines) {
  for (attr in c("line1", "line2")) {
    nodes <- xml2::xml_find_all(xml, paste0("//*[@", attr, "]"))
    at <- as.integer(xml2::xml_attr(nodes, attr))
    xml2::xml_set_attr(nodes, attr, as.character(lines[at]))
  }
  xml
}

# The line of its .Rd file that a parsed Rd node starts on, from the srcref
# tools::parse_Rd() attaches, or 1 when there is none.
rd_node_line <- function(node) {
  ref <- attr(node, "srcref")
  if (length(ref) == 0L) 1L else as.integer(ref[[1L]])
}

# Whether `text` parses as R. keep.source = FALSE, since only the verdict is
# wanted and the parse is repeated where the tree is needed.
parses <- function(text) {
  tryCatch(
    {
      parse(text = text, keep.source = FALSE)
      TRUE
    },
    error = function(e) FALSE
  )
}

# R code from vignette sources, taking only the chunks that run.
vignette_code <- function(path) {
  files <- list_included_files(path, "vignettes", "\\.(Rmd|rmd|qmd|Rnw)$")
  out <- list()
  for (file in files) {
    code <- vignette_r_code(file)
    if (!nzchar(trimws(code))) {
      next
    }
    out[[length(out) + 1L]] <- list(file = file, kind = "vignette", code = code)
  }
  out
}

# Plain R scripts under a set of directories, such as demos and tests.
script_code <- function(path, dirs, kind) {
  out <- list()
  for (dir in dirs) {
    files <- list_included_files(path, dir, "\\.[Rr]$")
    for (file in files) {
      code <- paste(safe_read_lines(file), collapse = "\n")
      if (!nzchar(trimws(code))) {
        next
      }
      out[[length(out) + 1L]] <- list(file = file, kind = kind, code = code)
    }
  }
  out
}

# Parsed code from the places outside R/ that CRAN reads. `kinds` selects which,
# since the rules differ: library() is fine in a vignette, print() is fine in an
# example, so a check asks only for the contexts its rule applies to.
#
# Returns a list of list(file, kind, xml), skipping anything that will not parse
# rather than failing the run, exactly as read_r_xml() does.
read_example_xml <- function(path, kinds = c("example", "vignette", "demo")) {
  sources <- list()
  if ("example" %in% kinds) {
    sources <- c(sources, rd_example_code(path))
  }
  if ("vignette" %in% kinds) {
    sources <- c(sources, vignette_code(path))
  }
  if ("demo" %in% kinds) {
    sources <- c(sources, script_code(path, EXAMPLE_SOURCE_DIRS$demo, "demo"))
  }
  if ("test" %in% kinds) {
    sources <- c(sources, script_code(path, EXAMPLE_SOURCE_DIRS$test, "test"))
  }

  out <- list()
  for (src in sources) {
    xml <- parse_text_xml(src$code)
    if (is.null(xml)) {
      next
    }
    if (!is.null(src$lines)) {
      xml <- remap_lines(xml, src$lines)
    }
    out[[length(out) + 1L]] <- list(
      file = src$file,
      kind = src$kind,
      xml = xml,
      code = src$code
    )
  }
  out
}

# Run an XPath over parsed example code and report "kind file.R:line" per match,
# so a finding says which example or vignette to open.
example_lints <- function(parsed, xpath, label = NULL) {
  hits <- character(0)
  for (src in parsed) {
    nodes <- tryCatch(
      xml2::xml_find_all(src$xml, xpath),
      error = function(e) NULL
    )
    if (is.null(nodes) || length(nodes) == 0L) {
      next
    }
    lines <- xml2::xml_attr(nodes, "line1")
    text <- paste0(src$kind, " ", basename(src$file), ":", lines)
    if (!is.null(label)) {
      text <- paste0(text, " (", label, ")")
    }
    hits <- c(hits, text)
  }
  unique(hits)
}

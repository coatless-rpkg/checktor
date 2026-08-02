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

# R code from a package's `.Rd` examples, one entry per file that has any.
rd_example_code <- function(path) {
  files <- list.files(
    file.path(path, "man"),
    pattern = "\\.Rd$",
    full.names = TRUE
  )
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
    # \dontrun{} contents are included: a reader copies them, and CRAN asks about
    # installs and writes wherever they appear in an example.
    code <- collect_rd_text(section)
    if (!nzchar(trimws(code))) {
      next
    }
    out[[length(out) + 1L]] <- list(file = file, kind = "example", code = code)
  }
  out
}

# R code from vignette sources, taking only the chunks that run.
vignette_code <- function(path) {
  files <- list.files(
    file.path(path, "vignettes"),
    pattern = "\\.(Rmd|rmd|qmd|Rnw)$",
    full.names = TRUE
  )
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
    full <- file.path(path, dir)
    if (!dir.exists(full)) {
      next
    }
    files <- list.files(full, pattern = "\\.[Rr]$", full.names = TRUE)
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

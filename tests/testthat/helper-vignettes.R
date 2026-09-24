# Readers for the vignette sources, so a test can hold a vignette's tables to the
# code they describe.

# The path to a vignette source, or "" when it is absent, as in an installed
# package or under R CMD check, where the tests run without `vignettes/`.
vignette_source <- function(name) {
  path <- test_path("..", "..", "vignettes", name)
  if (file.exists(path)) path else ""
}

# Every markdown table row whose first cell is a single code-quoted name, as a
# named character vector: name -> second cell. With `section`, only the rows under
# that `## ` heading are read.
vignette_table_cells <- function(path, section = NULL) {
  lines <- readLines(path, warn = FALSE)
  if (!is.null(section)) {
    headings <- grep("^## ", lines)
    start <- headings[lines[headings] == paste("##", section)]
    if (length(start) != 1) {
      return(character(0))
    }
    end <- c(headings[headings > start], length(lines) + 1)[1] - 1
    lines <- lines[start:end]
  }
  rows <- grep("^\\|\\s*`[^`]+`\\s*\\|", lines, value = TRUE)
  cells <- strsplit(rows, "|", fixed = TRUE)
  first <- trimws(vapply(cells, `[`, character(1), 2))
  second <- trimws(vapply(cells, `[`, character(1), 3))
  stats::setNames(second, gsub("`", "", first, fixed = TRUE))
}

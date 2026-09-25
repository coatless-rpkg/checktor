# Example file showing shell commands run from package code

#' Count Lines in a File
#' @param file A path.
count_lines <- function(file) {
  # Issue: system() is not portable (no wc on Windows) and pastes a path into a
  # shell command
  as.integer(system(paste("wc -l <", file), intern = TRUE))
}

#' Current Git Branch
git_branch <- function() {
  system2("git", c("rev-parse", "--abbrev-ref", "HEAD"), stdout = TRUE) # Issue
}

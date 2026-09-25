# Example file showing installed.packages() used to test for a package

#' Can We Plot?
#' @return `TRUE` when ggplot2 is installed.
can_plot <- function() {
  # Issue: installed.packages() is slow; use requireNamespace() instead
  "ggplot2" %in% rownames(installed.packages())
}

# Example file showing a package installing software on the user's machine

#' Make Sure ggplot2 Is There
ensure_ggplot2 <- function() {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    install.packages("ggplot2") # Issue: a package must not install packages
  }
}

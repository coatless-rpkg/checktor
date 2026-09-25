# Example file showing library() and require() in package code

#' Fit a Smoother
#' @param x,y Numeric vectors.
fit_smoother <- function(x, y) {
  library(splines) # Issue: attaches splines to the user's search path
  lm(y ~ ns(x, df = 3))
}

#' Tabulate Words
#' @param x A character vector.
tabulate_words <- function(x) {
  require(utils) # Issue: require() in package code, same problem
  head(sort(table(x), decreasing = TRUE))
}

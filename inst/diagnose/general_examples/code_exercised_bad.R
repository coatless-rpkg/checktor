# An exported function with no @examples, in a package with no tests/ scripts
# and no vignettes. Nothing R CMD check runs ever calls it, and CRAN's incoming
# check WARNs "No examples, no tests, no vignettes".

#' Round and Sort Values
#'
#' @param x A numeric vector.
#' @return `x`, rounded to two places and sorted.
#' @export
tidy_values <- function(x) {
  sort(round(x, 2))
}

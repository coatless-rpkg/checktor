# Example file showing a function tagged @export that NAMESPACE does not export:
# the roxygen comment was added, but devtools::document() was never run.

#' Scale to the Unit Interval
#' @param x A numeric vector.
#' @return `x` rescaled to lie in 0 to 1.
#' @export
rescale01 <- function(x) {
  rng <- range(x, na.rm = TRUE)
  (x - rng[1]) / (rng[2] - rng[1])
}

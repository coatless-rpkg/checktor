# Example file showing an environment variable changed and never restored

#' Sort in the C Locale
#' @param x A character vector.
sort_c <- function(x) {
  Sys.setenv(LC_COLLATE = "C") # Issue: no on.exit() puts the old value back
  sort(x)
}

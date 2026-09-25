# Example file showing detectCores() used without an NA guard

#' Worker Count
#' @return One less than the number of cores.
worker_count <- function() {
  # Issue: detectCores() can return NA, and NA - 1 is NA
  parallel::detectCores() - 1
}

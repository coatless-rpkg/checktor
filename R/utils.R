#' Quick Health Check - Fast version with summary only
#'
#' @description Runs checktor with minimal output, suitable for CI/CD
#'
#' @param path Character. Path to package directory
#'
#' @return Logical. TRUE if no issues, FALSE if issues found
#'
#' @export
checkup <- function(path = ".") {
  results <- checktor(path, verbose = FALSE, progress = FALSE)
  return(results$metadata$total_issues == 0)
}

#' Configure Package Doctor
#'
#' @description Set global options for checktor behavior
#'
#' @param verbose_default Logical. Default verbosity
#' @param progress_default Logical. Default progress bar setting
#' @param color Logical. Use colored output
#'
#' @export
configure_doctor <- function(verbose_default = TRUE, progress_default = TRUE, color = TRUE) {
  options(
    checktor.verbose = verbose_default,
    checktor.progress = progress_default,
    checktor.color = color
  )

  cli::cli_alert_success("Package doctor configuration updated")
  invisible()
}


safe_read_lines <- function(file) {
  # Check if file exists first to avoid error messages
  if (!file.exists(file)) {
    return(character(0))
  }

  tryCatch({
    readLines(file)
  }, error = function(e) {
    character(0)
  })
}

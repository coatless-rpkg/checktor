# Example file showing browser() calls (debugging code)

#' Debug Function
#' @param data Input data
debug_function <- function(data) {
  browser()  # Issue: debugging call left in code
  
  processed <- process_data(data)
  
  if (is.null(processed)) {
    browser()  # Issue: another debugging call
    stop("Processing failed")
  }
  
  return(processed)
}

#' Analysis with Debug
analyze_with_debug <- function(x) {
  result <- mean(x, na.rm = TRUE)
  
  if (is.na(result)) {
    browser()  # Issue: debugging call for troubleshooting
  }
  
  return(result)
}

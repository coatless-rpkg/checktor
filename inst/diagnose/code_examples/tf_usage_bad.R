# Example file showing T/F usage issues

#' Process Data Function
#' @param data A data frame
#' @return Logical indicating success
process_data <- function(data) {
  if (is.null(data)) {
    return(F)  # Issue: should be FALSE
  }
  
  has_complete_cases <- T  # Issue: should be TRUE
  
  if (has_complete_cases) {
    cleaned_data <- data[complete.cases(data), ]
    return(T)  # Issue: should be TRUE
  }
  
  return(F)  # Issue: should be FALSE
}

# Another function with T/F issues
validate_input <- function(x, strict = T) {  # Issue: should be TRUE
  if (length(x) == 0) return(F)  # Issue: should be FALSE
  
  valid <- all(is.numeric(x))
  return(valid && strict == T)  # Issue: should be TRUE
}

# Example file showing unsuppressable print/cat usage

#' Process File Function
#' @param filename File to process
process_file <- function(filename) {
  print(paste("Processing file:", filename))  # Issue: unsuppressable output
  
  if (!file.exists(filename)) {
    cat("Error: File not found\n")  # Issue: unsuppressable output
    return(NULL)
  }
  
  data <- read.csv(filename)
  print("File loaded successfully")  # Issue: unsuppressable output
  
  return(data)
}

#' Analysis Function
analyze_data <- function(data) {
  cat("Starting analysis...\n")  # Issue: unsuppressable output
  
  result <- summary(data)
  print(result)  # Issue: unsuppressable output
  
  cat("Analysis complete!\n")  # Issue: unsuppressable output
  return(result)
}

# Example showing temp file usage without cleanup

test_temp_files <- function() {
  temp_file <- tempfile(fileext = ".csv")
  temp_dir <- tempdir()
  
  write.csv(mtcars, temp_file)
  
  # Issue: No cleanup with unlink() or on.exit()
  
  return(temp_file)
}

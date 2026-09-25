# Example showing a temp file made and never removed

#' Round-Trip a Data Frame Through CSV
#' @param data A data frame.
#' @return `data` as read back from the CSV file.
round_trip_csv <- function(data) {
  temp_file <- tempfile(fileext = ".csv")
  write.csv(data, temp_file, row.names = FALSE)
  # Issue: nothing unlinks temp_file, and it is not returned to the caller
  read.csv(temp_file)
}

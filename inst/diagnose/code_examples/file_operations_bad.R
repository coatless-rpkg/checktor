# Example file showing writes to a fixed path in the user's filespace

#' Export Summary
#' @param data A data frame.
export_summary <- function(data) {
  # Issue: a relative literal path lands in whatever the working directory is
  write.csv(summary(data), "summary.csv")
}

#' Log a Message
#' @param msg A character string.
log_message <- function(msg) {
  cat(msg, file = "analysis.log", append = TRUE) # Issue: fixed path again
}

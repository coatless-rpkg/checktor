# Example file showing writes to the user's home directory

#' Save Results
#' @param results A data frame.
#' @return The path written, invisibly.
save_results <- function(results) {
  out <- "~/results.csv"
  write.csv(results, "~/results.csv") # Issue: writes into the home directory
  invisible(out)
}

#' Cache a Model
#' @param model Any R object.
cache_model <- function(model) {
  # Issue: $HOME is the user's home directory too
  saveRDS(model, file.path(Sys.getenv("HOME"), "model.rds"))
}

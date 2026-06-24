# Example file showing unlimited core usage

library(parallel)

#' Parallel Processing
#' @param data Input data
parallel_process <- function(data) {
  num_cores <- detectCores()  # Issue: using all available cores
  cl <- makeCluster(num_cores)  # Issue: no core limit
  
  result <- parLapply(cl, data, function(x) x^2)
  stopCluster(cl)
  return(result)
}

#' Parallel Analysis
analyze_parallel <- function(datasets) {
  # Issue: using all cores without limit
  results <- mclapply(datasets, analyze_single, mc.cores = detectCores())
  return(results)
}

analyze_single <- function(data) {
  return(summary(data))
}

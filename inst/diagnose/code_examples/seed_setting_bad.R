# Example file showing hardcoded seed issues

#' Generate Random Sample
#' @param n Sample size
#' @return Random sample
generate_sample <- function(n = 100) {
  set.seed(12345)  # Issue: hardcoded seed
  return(rnorm(n))
}

#' Bootstrap Analysis
#' @param data Input data
#' @param iterations Number of bootstrap iterations
bootstrap_analysis <- function(data, iterations = 1000) {
  set.seed(42)  # Issue: hardcoded seed
  results <- replicate(iterations, {
    sample_data <- sample(data, replace = TRUE)
    mean(sample_data)
  })
  return(results)
}

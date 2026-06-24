# Example file showing option changes without proper reset

#' Plotting Function
#' @param x Data to plot
create_plot <- function(x) {
  old_par <- par(mfrow = c(2, 2))  # Changes plotting parameters
  # Missing: on.exit(par(old_par))
  
  options(warn = -1)  # Changes warning level
  # Missing: on.exit(options(warn = 0), add = TRUE)
  
  plot(x)
  hist(x)
  boxplot(x)
  qqnorm(x)
  
  # Options and par settings not restored!
}

#' Working Directory Function
process_directory <- function(target_dir) {
  current_dir <- getwd()
  setwd(target_dir)  # Changes working directory
  # Missing: on.exit(setwd(current_dir))
  
  files <- list.files()
  
  # Working directory not restored!
  return(files)
}

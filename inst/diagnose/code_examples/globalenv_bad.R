# Example file showing GlobalEnv modifications

#' Global Variable Function
set_global_config <- function(config) {
  GLOBAL_CONFIG <<- config  # Issue: modifying GlobalEnv with <<-
  return(invisible())
}

#' Direct GlobalEnv Assignment
setup_environment <- function() {
  assign("PACKAGE_LOADED", TRUE, envir = .GlobalEnv)  # Issue: direct GlobalEnv assignment
  assign("PACKAGE_VERSION", "1.0.0", envir = globalenv())  # Issue: using globalenv()
}

#' Global Counter
increment_counter <- function() {
  if (!exists("COUNTER", envir = .GlobalEnv)) {
    COUNTER <<- 0  # Issue: creating global variable
  }
  COUNTER <<- COUNTER + 1  # Issue: modifying global variable
  return(COUNTER)
}

# Example file showing ::: in package code

#' Format a Size
#' @param bytes A number of bytes.
#' @return A character string such as "1.5 Kb".
format_size <- function(bytes) {
  # Issue: ::: reaches a method utils does not export, which its authors may
  # change or remove in any release
  utils:::format.object_size(bytes, units = "auto")
}

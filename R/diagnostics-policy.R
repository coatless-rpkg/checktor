
# Additional diagnostic functions

#' Check for Common CRAN Policy Violations
#'
#' @description Checks for additional policy violations
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print output
#'
#' @export
diagnose_policy_violations <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("CRAN Policy Violations Check")
  }

  results <- list()

  # Check for browser() calls
  results$browser_calls <- diagnose_browser_calls(path, verbose)

  # Check for system calls
  results$system_calls <- diagnose_system_calls(path, verbose)

  # Check for file operations in wrong locations
  results$file_operations <- diagnose_file_operations(path, verbose)

  # Check for network operations in examples
  results$network_operations <- diagnose_network_operations(path, verbose)

  results$passed <- sapply(results, function(x) if(is.logical(x)) x else x$passed)

  return(results)
}

diagnose_browser_calls <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    browser_lines <- grep("\\bbrowser\\s*\\(", content, perl = TRUE)
    if (length(browser_lines) > 0) {
      issues <- c(issues, paste0(basename(file), ":", browser_lines))
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No {.code browser()} calls found")
    } else {
      cli::cli_alert_danger("{.code browser()} calls found (should be removed for CRAN)")
      cli::cli_ul(issues)
    }
  }

  return(list(passed = passed, issues = issues, message = "Browser calls check"))
}

diagnose_system_calls <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  dangerous_patterns <- c("system\\s*\\(", "system2\\s*\\(", "shell\\s*\\(")

  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    for (pattern in dangerous_patterns) {
      matches <- grep(pattern, content, perl = TRUE)
      if (length(matches) > 0) {
        issues <- c(issues, paste0(basename(file), ":", matches, " (", pattern, ")"))
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No dangerous system calls found")
    } else {
      cli::cli_alert_warning("Potential dangerous system calls found")
      cli::cli_ul(utils::head(issues, 5))
      if (length(issues) > 5) {
        cli::cli_text("{.emph ... and {length(issues) - 5} more}")
      }
      cli::cli_text("{.emph Treatment: Review these carefully - may need platform checks}")
    }
  }

  return(list(passed = passed, issues = issues, message = "System calls check"))
}

diagnose_file_operations <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  file_patterns <- c("write\\.csv", "write\\.table", "saveRDS", "save\\s*\\(", "file\\.create")

  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    for (pattern in file_patterns) {
      matches <- grep(pattern, content, perl = TRUE)
      if (length(matches) > 0) {
        # Check if it's writing to tempdir or has path parameter
        for (match in matches) {
          line_content <- content[match]
          if (!grepl("tempdir|tempfile", line_content, ignore.case = TRUE)) {
            issues <- c(issues, paste0(basename(file), ":", match, " (", pattern, ")"))
          }
        }
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("File operations appear safe")
    } else {
      cli::cli_alert_warning("Potential file operations without temp directory")
      cli::cli_ul(utils::head(issues, 5))
      if (length(issues) > 5) {
        cli::cli_text("{.emph ... and {length(issues) - 5} more}")
      }
      cli::cli_text("{.emph Treatment: Ensure file operations use temporary directories}")
    }
  }

  return(list(passed = passed, issues = issues, message = "File operations check"))
}

diagnose_network_operations <- function(path, verbose) {
  # Check examples and vignettes for network operations
  example_files <- list.files(file.path(path, "man"), pattern = "\\.Rd$", full.names = TRUE, recursive = TRUE)
  vignette_files <- list.files(file.path(path, "vignettes"), pattern = "\\.(Rmd|md)$", full.names = TRUE, recursive = TRUE)

  all_files <- c(example_files, vignette_files)
  if (length(all_files) == 0) return(list(passed = TRUE, message = "No example/vignette files found"))

  issues <- character(0)
  network_patterns <- c("download\\.file", "url\\s*\\(", "httr::", "curl::", "RCurl::")

  for (file in all_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    for (pattern in network_patterns) {
      matches <- grep(pattern, content, perl = TRUE)
      if (length(matches) > 0) {
        # Check if it's wrapped in dontrun or conditional
        wrapped <- any(grepl("\\\\dontrun|\\\\donttest|if.*available|if.*internet", content, ignore.case = TRUE))
        if (!wrapped) {
          issues <- c(issues, paste0(basename(file), " (", pattern, ")"))
        }
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("Network operations appear properly wrapped")
    } else {
      cli::cli_alert_warning("Potential unwrapped network operations")
      cli::cli_ul(issues)
      cli::cli_text("{.emph Treatment: Consider wrapping in \\dontrun or conditional checks}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Network operations check"))
}

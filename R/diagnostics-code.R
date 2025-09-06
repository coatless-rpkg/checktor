#' Diagnose Code Health Issues
#'
#' Runs comprehensive diagnostics on R source code to identify common CRAN
#' submission issues and coding best practices violations.
#'
#' @param path Character. Path to the R package directory. Default: `"."`.
#' @param verbose Logical. Whether to print detailed diagnostic output. Default: `TRUE`.
#'
#' @return
#' A list containing results of all code diagnostics with named elements for
#' each check (e.g., `tf_usage`, `seed_setting`). Each element contains:
#'
#' - `passed`: Logical indicating if the check passed
#' - `issues`: Character vector of specific issues found (if any)
#' - `message`: Description of what was checked
#'
#' @details
#' This function orchestrates multiple code-level diagnostics including:
#'
#' - `T`/`F` usage (should use `TRUE`/`FALSE`)
#' - Hardcoded seed setting without user control
#' - Unsuppressable print/cat statements
#' - Global option modifications without proper reset
#' - Writing to user's home directory
#' - Missing temporary file cleanup
#' - GlobalEnv modifications
#' - Use of installed.packages()
#' - Inappropriate warning suppression
#' - Software installation in functions
#' - Unlimited core usage in parallel operations
#'
#' @seealso
#' [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' \dontrun{
#' # Diagnose code issues in current package
#' code_results <- diagnose_code_issues()
#'
#' # Check specific package directory
#' code_results <- diagnose_code_issues("path/to/package")
#'
#' # Silent check
#' code_results <- diagnose_code_issues(verbose = FALSE)
#'
#' # View specific diagnostic result
#' code_results$tf_usage$passed
#' }
diagnose_code_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("Code Health Check")
  }

  # Check if R directory exists
  r_dir <- file.path(path, "R")
  if (!dir.exists(r_dir)) {
    if (verbose) {
      cli::cli_alert_info("No R/ directory found")
    }
    return(list(passed = TRUE, message = "No R directory found"))
  }

  results <- list()

  # Define diagnostics with metadata
  diagnostics <- list(
    list(name = "tf_usage", description = "T/F usage", func = diagnose_tf_usage),
    list(name = "seed_setting", description = "Seed setting", func = diagnose_seed_setting),
    list(name = "print_cat_usage", description = "Print/cat usage", func = diagnose_print_cat_usage),
    list(name = "option_changes", description = "Option changes", func = diagnose_option_changes),
    list(name = "home_writing", description = "Home directory writing", func = diagnose_home_writing),
    list(name = "temp_cleanup", description = "Temp file cleanup", func = diagnose_temp_cleanup),
    list(name = "globalenv_mod", description = "GlobalEnv modification", func = diagnose_globalenv_modification),
    list(name = "installed_packages", description = "installed.packages() usage", func = diagnose_installed_packages_usage),
    list(name = "warn_option", description = "Warn option", func = diagnose_warn_option),
    list(name = "software_install", description = "Software installation", func = diagnose_software_installation),
    list(name = "core_usage", description = "Core usage", func = diagnose_core_usage)
  )

  # Run diagnostics with error handling
  for (diagnostic in diagnostics) {
    tryCatch({
      results[[diagnostic$name]] <- diagnostic$func(path, verbose)
    }, error = function(e) {
      if (verbose) {
        cli::cli_alert_danger("Error in {diagnostic$description} diagnostic: {e$message}")
      }
      results[[diagnostic$name]] <<- list(passed = FALSE, error = e$message)
    })
  }

  results$passed <- sapply(results, function(x) if(is.logical(x)) x else x$passed)

  return(results)
}

#' Diagnose `T`/`F` Usage in R Code
#'
#' Checks for usage of `T` and `F` instead of the recommended `TRUE` and `FALSE`
#' in R source files. CRAN requires explicit use of `TRUE`/`FALSE` for clarity
#' and to avoid potential conflicts.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return
#' List with elements:
#'
#' - `passed`: Logical, TRUE if no T/F usage found
#' - `issues`: Character vector of "file:line" locations
#' - `file_issues`: Named list grouping issues by file
#' - `message`: Description of the check
#'
#' @export
#' @examples
#' \dontrun{
#' # Check for T/F usage
#' tf_result <- diagnose_tf_usage(".")
#'
#' # View issues by file
#' tf_result$file_issues
#' }
diagnose_tf_usage <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  file_issues <- list()

  for (file in r_files) {
    tryCatch({
      content <- safe_read_lines(file)
      if (length(content) == 0) next

      # Look for standalone T or F (not part of TRUE/FALSE)
      tf_lines <- grep("\\b[^A-Z]T\\b|\\bF\\b(?!ALSE)", content, perl = TRUE)
      if (length(tf_lines) > 0) {
        file_name <- basename(file)
        file_issues[[file_name]] <- tf_lines
        issues <- c(issues, paste0(file_name, ":", tf_lines))
      }
    }, error = function(e) {
      if (verbose) cli::cli_alert_warning("Could not examine file {.path {basename(file)}}")
    })
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No {.code T}/{.code F} usage found")
    } else {
      cli::cli_alert_danger("Found {.code T}/{.code F} usage (should use {.code TRUE}/{.code FALSE})")
      # Group by file for better readability
      for (file_name in names(file_issues)) {
        cli::cli_text("  {.file {file_name}}: lines {paste(file_issues[[file_name]], collapse = ', ')}")
      }
    }
  }

  return(list(passed = passed, issues = issues, file_issues = file_issues, message = "T/F usage check"))
}

#' Diagnose Hardcoded Seed Setting
#'
#' Identifies hardcoded `set.seed()` calls in R code. CRAN prefers that
#' functions allow users to control randomness through parameters rather
#' than forcing specific seeds.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return
#' List with elements:
#'
#' - `passed`: Logical, `TRUE` if no hardcoded seeds found
#' - `issues`: Character vector of `"file:line"` locations
#' - `message`: Description of the check
#'
#' @export
#' @examples
#' \dontrun{
#' # Check for hardcoded seeds
#' seed_result <- diagnose_seed_setting(".")
#' }
diagnose_seed_setting <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    seed_lines <- grep("set\\.seed\\s*\\(\\s*[0-9]+\\s*\\)", content, perl = TRUE)
    if (length(seed_lines) > 0) {
      issues <- c(issues, paste0(basename(file), ":", seed_lines))
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No hardcoded seed setting found")
    } else {
      cli::cli_alert_danger("Found hardcoded seed setting")
      cli::cli_ul(issues)
      cli::cli_text("{.emph Treatment: Add a seed parameter to allow user control}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Seed setting check"))
}

#' Diagnose Print/Cat Usage in Functions
#'
#' Identifies potentially unsuppressable `print()` and `cat()` calls that
#' could create unwanted output. CRAN prefers suppressable output using
#' `message()` or conditional verbose parameters.
#'
#' @param path Character. Path to package directory
#' @param verbose Logical. Print diagnostic messages
#'
#' @return
#' List with elements:
#'
#' - `passed`: Logical, `TRUE` if no problematic print/cat usage found
#' - `issues`: Character vector of `"file:line"` locations
#' - `message`: Description of the check
#'
#' @examples
#' \dontrun{
#' # Check for print/cat usage
#' print_result <- diagnose_print_cat_usage(".")
#' }
diagnose_print_cat_usage <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    # Look for print() or cat() calls - simplified pattern
    print_lines <- grep("\\b(print|cat)\\s*\\(", content, perl = TRUE)

    if (length(print_lines) > 0) {
      # Filter out lines that appear to be in if statements or other conditional structures
      for (line_num in print_lines) {
        line_content <- content[line_num]
        # Check if the line contains 'if(' before the print/cat call
        # or if it's indented suggesting it's inside a conditional block
        if (!grepl("if\\s*\\([^)]*\\).*\\b(print|cat)\\s*\\(", line_content, perl = TRUE) &&
            !grepl("^\\s*if\\s*\\(", line_content, perl = TRUE)) {
          # Also check a few lines before for if statements
          check_range <- max(1, line_num - 3):line_num
          preceding_lines <- content[check_range]
          has_conditional <- any(grepl("if\\s*\\(|while\\s*\\(|for\\s*\\(", preceding_lines, perl = TRUE))

          if (!has_conditional) {
            issues <- c(issues, paste0(basename(file), ":", line_num))
          }
        }
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No unsuppressable {.code print()}/{.code cat()} usage found")
    } else {
      cli::cli_alert_warning("Potential unsuppressable {.code print()}/{.code cat()} usage")
      cli::cli_ul(utils::head(issues, 5))
      if (length(issues) > 5) {
        cli::cli_text("{.emph ... and {length(issues) - 5} more}")
      }
      cli::cli_text("{.emph Treatment: Use {.code message()} or {.code if(verbose)} conditions}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Print/cat usage check"))
}

diagnose_option_changes <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    option_lines <- grep("\\b(options|par|setwd)\\s*\\(", content, perl = TRUE)
    if (length(option_lines) > 0) {
      # Check if there's an on.exit nearby
      for (line_num in option_lines) {
        # Check next few lines for on.exit
        check_range <- seq(line_num, min(line_num + 5, length(content)))
        if (!any(grepl("on\\.exit", content[check_range]))) {
          issues <- c(issues, paste0(basename(file), ":", line_num))
        }
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("Option changes appear to be properly reset")
    } else {
      cli::cli_alert_danger("Option changes without apparent reset")
      cli::cli_ul(utils::head(issues, 5))
      if (length(issues) > 5) {
        cli::cli_text("{.emph ... and {length(issues) - 5} more}")
      }
      cli::cli_text("{.emph Treatment: Use {.code on.exit()} to reset options}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Option changes check"))
}

diagnose_home_writing <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  suspicious_patterns <- c("getwd\\(\\)", "~", "Sys\\.getenv\\(.*HOME.*\\)", "file\\.path\\(.*home.*\\)")

  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    for (pattern in suspicious_patterns) {
      matches <- grep(pattern, content, perl = TRUE)
      if (length(matches) > 0) {
        issues <- c(issues, paste0(basename(file), ":", matches, " (", pattern, ")"))
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No obvious home directory writing detected")
    } else {
      cli::cli_alert_warning("Potential home directory writing patterns")
      cli::cli_ul(utils::head(issues, 5))
      if (length(issues) > 5) {
        cli::cli_text("{.emph ... and {length(issues) - 5} more}")
      }
      cli::cli_text("{.emph Treatment: Verify these don't write to user's home directory}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Home writing check"))
}

diagnose_temp_cleanup <- function(path, verbose) {
  # Check examples and tests for temp file usage without cleanup
  examples_files <- list.files(file.path(path, "man"), pattern = "\\.Rd$", full.names = TRUE, recursive = TRUE)
  test_files <- list.files(file.path(path, "tests"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)

  all_files <- c(examples_files, test_files)
  if (length(all_files) == 0) return(list(passed = TRUE, message = "No example/test files found"))

  issues <- character(0)
  for (file in all_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    temp_lines <- grep("temp(file|dir)", content, perl = TRUE)
    if (length(temp_lines) > 0) {
      # Check if there's cleanup (unlink, file.remove)
      cleanup_lines <- grep("\\b(unlink|file\\.remove|on\\.exit)\\b", content, perl = TRUE)
      if (length(cleanup_lines) == 0) {
        issues <- c(issues, paste0(basename(file), " (temp files without cleanup)"))
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("Temp file usage appears to include cleanup")
    } else {
      cli::cli_alert_warning("Temp files without apparent cleanup")
      cli::cli_ul(issues)
      cli::cli_text("{.emph Treatment: Add cleanup code}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Temp cleanup check"))
}

diagnose_globalenv_modification <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    global_lines <- grep("<<-|\\.GlobalEnv|globalenv\\(\\)|assign\\(.*envir\\s*=.*\\.GlobalEnv", content, perl = TRUE)
    if (length(global_lines) > 0) {
      issues <- c(issues, paste0(basename(file), ":", global_lines))
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No {.code .GlobalEnv} modification detected")
    } else {
      cli::cli_alert_danger("Potential {.code .GlobalEnv} modification")
      cli::cli_ul(issues)
      cli::cli_text("{.emph Treatment: Avoid modifying the global environment}")
    }
  }

  return(list(passed = passed, issues = issues, message = "GlobalEnv modification check"))
}

diagnose_installed_packages_usage <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    installed_lines <- grep("installed\\.packages\\(\\)", content, perl = TRUE)
    if (length(installed_lines) > 0) {
      issues <- c(issues, paste0(basename(file), ":", installed_lines))
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No {.code installed.packages()} usage found")
    } else {
      cli::cli_alert_danger("{.code installed.packages()} usage found")
      cli::cli_ul(issues)
      cli::cli_text("{.emph Treatment: Use {.code requireNamespace()} or {.code require()} instead}")
    }
  }

  return(list(passed = passed, issues = issues, message = "installed.packages() usage check"))
}

diagnose_warn_option <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    warn_lines <- grep("options\\(\\s*warn\\s*=\\s*-1\\s*\\)", content, perl = TRUE)
    if (length(warn_lines) > 0) {
      issues <- c(issues, paste0(basename(file), ":", warn_lines))
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No {.code options(warn = -1)} usage found")
    } else {
      cli::cli_alert_danger("{.code options(warn = -1)} usage found")
      cli::cli_ul(issues)
      cli::cli_text("{.emph Treatment: Use {.code suppressWarnings()} instead}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Warn option check"))
}

diagnose_software_installation <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  install_patterns <- c("install\\.packages", "devtools::install", "remotes::install", "install_")

  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    for (pattern in install_patterns) {
      install_lines <- grep(pattern, content, perl = TRUE)
      if (length(install_lines) > 0) {
        issues <- c(issues, paste0(basename(file), ":", install_lines, " (", pattern, ")"))
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No software installation in functions detected")
    } else {
      cli::cli_alert_warning("Potential software installation in functions")
      cli::cli_ul(utils::head(issues, 3))
      if (length(issues) > 3) {
        cli::cli_text("{.emph ... and {length(issues) - 3} more}")
      }
      cli::cli_text("{.emph Treatment: Verify this is appropriate for your package}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Software installation check"))
}

diagnose_core_usage <- function(path, verbose) {
  # Check examples and tests for high core usage
  r_files <- list.files(path, pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  core_patterns <- c("detectCores\\(\\)", "parallel::", "mclapply", "parLapply", "makeCluster")

  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    for (pattern in core_patterns) {
      core_lines <- grep(pattern, content, perl = TRUE)
      if (length(core_lines) > 0) {
        # Check if there's a limit to 2 cores
        limited <- any(grepl("min\\s*\\(.*2.*,|\\b2\\b.*cores", content))
        if (!limited) {
          issues <- c(issues, paste0(basename(file), ":", core_lines[1], " (", pattern, ")"))
        }
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("Core usage appears limited appropriately")
    } else {
      cli::cli_alert_warning("Potential unlimited core usage")
      cli::cli_ul(utils::head(issues, 3))
      if (length(issues) > 3) {
        cli::cli_text("{.emph ... and {length(issues) - 3} more}")
      }
      cli::cli_text("{.emph Treatment: Consider limiting to 2 cores for CRAN}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Core usage check"))
}

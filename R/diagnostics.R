# Enhanced diagnostic functions with better error handling
diagnose_code_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli_h2("Code Health Check")
  }

  # Check if R directory exists
  r_dir <- file.path(path, "R")
  if (!dir.exists(r_dir)) {
    if (verbose) {
      cli_alert_info("No R/ directory found")
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
        cli_alert_danger("Error in {diagnostic$description} diagnostic: {e$message}")
      }
      results[[diagnostic$name]] <<- list(passed = FALSE, error = e$message)
    })
  }

  results$passed <- sapply(results, function(x) if(is.logical(x)) x else x$passed)

  return(results)
}

# Individual diagnostic functions
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
      if (verbose) cli_alert_warning("Could not examine file {.path {basename(file)}}")
    })
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli_alert_success("No {.code T}/{.code F} usage found")
    } else {
      cli_alert_danger("Found {.code T}/{.code F} usage (should use {.code TRUE}/{.code FALSE})")
      # Group by file for better readability
      for (file_name in names(file_issues)) {
        cli_text("  {.file {file_name}}: lines {paste(file_issues[[file_name]], collapse = ', ')}")
      }
    }
  }

  return(list(passed = passed, issues = issues, file_issues = file_issues, message = "T/F usage check"))
}

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
      cli_alert_success("No hardcoded seed setting found")
    } else {
      cli_alert_danger("Found hardcoded seed setting")
      cli_ul(issues)
      cli_text("{.emph Treatment: Add a seed parameter to allow user control}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Seed setting check"))
}

diagnose_print_cat_usage <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) return(list(passed = TRUE, message = "No R files found"))

  issues <- character(0)
  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    # Look for print() or cat() that aren't in if() statements or wrapped functions
    print_lines <- grep("(?<!if\\s*\\()\\b(print|cat)\\s*\\(", content, perl = TRUE)
    if (length(print_lines) > 0) {
      issues <- c(issues, paste0(basename(file), ":", print_lines))
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli_alert_success("No unsuppressable {.code print()}/{.code cat()} usage found")
    } else {
      cli_alert_warning("Potential unsuppressable {.code print()}/{.code cat()} usage")
      cli_ul(head(issues, 5))
      if (length(issues) > 5) {
        cli_text("{.emph ... and {length(issues) - 5} more}")
      }
      cli_text("{.emph Treatment: Use {.code message()} or {.code if(verbose)} conditions}")
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
      cli_alert_success("Option changes appear to be properly reset")
    } else {
      cli_alert_danger("Option changes without apparent reset")
      cli_ul(head(issues, 5))
      if (length(issues) > 5) {
        cli_text("{.emph ... and {length(issues) - 5} more}")
      }
      cli_text("{.emph Treatment: Use {.code on.exit()} to reset options}")
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
      cli_alert_success("No obvious home directory writing detected")
    } else {
      cli_alert_warning("Potential home directory writing patterns")
      cli_ul(utils::head(issues, 5))  # FIXED: Added utils:: prefix
      if (length(issues) > 5) {
        cli_text("{.emph ... and {length(issues) - 5} more}")
      }
      cli_text("{.emph Treatment: Verify these don't write to user's home directory}")
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
      cli_alert_success("Temp file usage appears to include cleanup")
    } else {
      cli_alert_warning("Temp files without apparent cleanup")
      cli_ul(issues)
      cli_text("{.emph Treatment: Add cleanup code}")
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
      cli_alert_success("No {.code .GlobalEnv} modification detected")
    } else {
      cli_alert_danger("Potential {.code .GlobalEnv} modification")
      cli_ul(issues)
      cli_text("{.emph Treatment: Avoid modifying the global environment}")
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
      cli_alert_success("No {.code installed.packages()} usage found")
    } else {
      cli_alert_danger("{.code installed.packages()} usage found")
      cli_ul(issues)
      cli_text("{.emph Treatment: Use {.code requireNamespace()} or {.code require()} instead}")
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
      cli_alert_success("No {.code options(warn = -1)} usage found")
    } else {
      cli_alert_danger("{.code options(warn = -1)} usage found")
      cli_ul(issues)
      cli_text("{.emph Treatment: Use {.code suppressWarnings()} instead}")
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
      cli_alert_success("No software installation in functions detected")
    } else {
      cli_alert_warning("Potential software installation in functions")
      cli_ul(head(issues, 3))
      if (length(issues) > 3) {
        cli_text("{.emph ... and {length(issues) - 3} more}")
      }
      cli_text("{.emph Treatment: Verify this is appropriate for your package}")
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
      cli_alert_success("Core usage appears limited appropriately")
    } else {
      cli_alert_warning("Potential unlimited core usage")
      cli_ul(head(issues, 3))
      if (length(issues) > 3) {
        cli_text("{.emph ... and {length(issues) - 3} more}")
      }
      cli_text("{.emph Treatment: Consider limiting to 2 cores for CRAN}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Core usage check"))
}

# DESCRIPTION file diagnostics
diagnose_description_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli_h2("DESCRIPTION File Health Check")
  }

  results <- list()

  desc_file <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_file)) {
    if (verbose) cli_alert_danger("DESCRIPTION file not found")
    return(list(passed = FALSE, message = "DESCRIPTION file not found"))
  }

  desc_content <- safe_read_lines(desc_file)
  if (length(desc_content) == 0) {
    if (verbose) cli_alert_danger("Could not read DESCRIPTION file")
    return(list(passed = FALSE, message = "Could not read DESCRIPTION file"))
  }

  # Check software names formatting
  results$software_names <- diagnose_software_names_formatting(desc_content, verbose)

  # Check acronyms
  results$acronyms <- diagnose_acronym_explanation(desc_content, verbose)

  # Check license formatting
  results$license <- diagnose_license_formatting(desc_content, verbose)

  # Check title case
  results$title_case <- diagnose_title_case(desc_content, verbose)

  # Check Authors@R
  results$authors <- diagnose_authors_field(desc_content, verbose)

  # Check references
  results$references <- diagnose_references_formatting(desc_content, verbose)

  # Check description length
  results$description_length <- diagnose_description_length(desc_content, verbose)

  results$passed <- sapply(results, function(x) if(is.logical(x)) x else x$passed)

  return(results)
}

diagnose_software_names_formatting <- function(desc_content, verbose) {
  title_line <- grep("^Title:", desc_content, value = TRUE)
  desc_line <- grep("^Description:", desc_content, value = TRUE)

  # Look for common software names that should be in quotes
  software_names <- c("R", "Python", "Java", "C\\+\\+", "SQL", "HTML", "CSS", "JavaScript", "ggplot2", "dplyr", "tidyr")
  issues <- character(0)

  for (line_type in list(c("Title", title_line), c("Description", desc_line))) {
    if (length(line_type[[2]]) > 0) {
      for (name in software_names) {
        # Check if software name appears without quotes
        if (grepl(paste0("\\b", name, "\\b"), line_type[[2]]) &&
            !grepl(paste0("'", name, "'"), line_type[[2]])) {
          issues <- c(issues, paste0(line_type[[1]], ": ", name, " should be in single quotes"))
        }
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli_alert_success("Software names appear properly formatted")
    } else {
      cli_alert_warning("Potential software name formatting issues")
      cli_ul(issues)
    }
  }

  return(list(passed = passed, issues = issues, message = "Software names check"))
}

diagnose_acronym_explanation <- function(desc_content, verbose) {
  desc_line <- grep("^Description:", desc_content, value = TRUE)
  if (length(desc_line) == 0) {
    return(list(passed = TRUE, message = "No Description field found"))
  }

  # Find potential acronyms (2-6 uppercase letters)
  acronyms <- regmatches(desc_line, gregexpr("\\b[A-Z]{2,6}\\b", desc_line))[[1]]

  # Filter out common abbreviations that don't need explanation
  common_abbrevs <- c("API", "SQL", "HTML", "CSS", "PDF", "XML", "JSON", "URL", "HTTP", "FTP", "GUI", "CLI")
  unexplained_acronyms <- setdiff(acronyms, common_abbrevs)

  passed <- length(unexplained_acronyms) == 0
  if (verbose) {
    if (passed) {
      cli_alert_success("No unexplained acronyms found")
    } else {
      cli_alert_warning("Potential unexplained acronyms: {.val {paste(unexplained_acronyms, collapse = ', ')}}")
      cli_text("{.emph Treatment: Consider explaining these acronyms}")
    }
  }

  return(list(passed = passed, issues = unexplained_acronyms, message = "Acronyms check"))
}

diagnose_license_formatting <- function(desc_content, verbose) {
  license_line <- grep("^License:", desc_content, value = TRUE)
  if (length(license_line) == 0) {
    if (verbose) cli_alert_warning("No License field found")
    return(list(passed = FALSE, message = "No License field"))
  }

  # Check for unnecessary "+ file LICENSE"
  has_file_license <- grepl("\\+ file LICENSE", license_line)
  standard_licenses <- c("MIT", "GPL-2", "GPL-3", "BSD_2_clause", "BSD_3_clause", "Apache")

  is_standard <- any(sapply(standard_licenses, function(x) grepl(x, license_line)))

  passed <- !(has_file_license && is_standard)
  if (verbose) {
    if (passed) {
      cli_alert_success("License formatting appears correct")
    } else {
      cli_alert_warning("Potential unnecessary {.code '+ file LICENSE'}")
      cli_text("{.val {license_line}}")
      cli_text("{.emph Treatment: Standard licenses may not need additional LICENSE file}")
    }
  }

  return(list(passed = passed, license = license_line, message = "License check"))
}

diagnose_title_case <- function(desc_content, verbose) {
  title_line <- grep("^Title:", desc_content, value = TRUE)
  if (length(title_line) == 0) {
    if (verbose) cli_alert_warning("No Title field found")
    return(list(passed = FALSE, message = "No Title field"))
  }

  title_text <- sub("^Title:\\s*", "", title_line)

  # Simple check for title case (not perfect but catches obvious issues)
  words <- strsplit(title_text, "\\s+")[[1]]
  articles <- c("a", "an", "the", "and", "or", "but", "for", "nor", "of", "to", "in", "on", "at", "by")

  issues <- character(0)
  for (i in seq_along(words)) {
    word <- words[i]
    # First word should always be capitalized
    if (i == 1 && !grepl("^[A-Z]", word)) {
      issues <- c(issues, paste("First word should be capitalized:", word))
    }
    # Other words should be capitalized unless they're articles
    else if (i > 1 && tolower(word) %in% articles && grepl("^[A-Z]", word)) {
      # This is okay - articles can be capitalized
    }
    else if (i > 1 && !tolower(word) %in% articles && !grepl("^[A-Z]", word)) {
      issues <- c(issues, paste("Word should be capitalized:", word))
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli_alert_success("Title appears to be in Title Case")
    } else {
      cli_alert_warning("Potential Title Case issues")
      cli_ul(issues)
    }
  }

  return(list(passed = passed, issues = issues, message = "Title case check"))
}

diagnose_authors_field <- function(desc_content, verbose) {
  authors_r_line <- grep("^Authors@R:", desc_content)
  author_line <- grep("^Author:", desc_content)
  maintainer_line <- grep("^Maintainer:", desc_content)

  has_authors_r <- length(authors_r_line) > 0
  has_legacy <- length(author_line) > 0 || length(maintainer_line) > 0

  passed <- has_authors_r
  if (verbose) {
    if (passed) {
      cli_alert_success("{.code Authors@R} field found")
    } else {
      cli_alert_warning("No {.code Authors@R} field found")
      if (has_legacy) {
        cli_text("{.emph Legacy Author/Maintainer fields detected}")
      }
      cli_text("{.emph Treatment: Consider adding Authors@R field}")
    }
  }

  return(list(passed = passed, message = "Authors@R field check"))
}

diagnose_references_formatting <- function(desc_content, verbose) {
  desc_line <- grep("^Description:", desc_content, value = TRUE)
  if (length(desc_line) == 0) {
    return(list(passed = TRUE, message = "No Description field found"))
  }

  # Look for DOI or URL references
  has_doi <- grepl("<doi:", desc_line)
  has_url <- grepl("<https?:", desc_line)
  has_references <- has_doi || has_url

  issues <- character(0)
  if (has_references) {
    # Check for space after doi: or https:
    if (grepl("<doi:\\s+", desc_line)) {
      issues <- c(issues, "Space found after 'doi:' - should be no space")
    }
    if (grepl("<https?:\\s+", desc_line)) {
      issues <- c(issues, "Space found after 'https:' - should be no space")
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed && has_references) {
      cli_alert_success("Reference formatting appears correct")
    } else if (passed && !has_references) {
      cli_alert_info("No references found in Description")
    } else {
      cli_alert_warning("Reference formatting issues")
      cli_ul(issues)
    }
  }

  return(list(passed = passed, issues = issues, message = "References check"))
}

diagnose_description_length <- function(desc_content, verbose) {
  desc_line <- grep("^Description:", desc_content, value = TRUE)
  if (length(desc_line) == 0) {
    if (verbose) cli_alert_warning("No Description field found")
    return(list(passed = FALSE, message = "No Description field"))
  }

  desc_text <- sub("^Description:\\s*", "", desc_line)
  sentences <- length(strsplit(desc_text, "[.!?]")[[1]])
  word_count <- length(strsplit(desc_text, "\\s+")[[1]])

  passed <- sentences >= 2 && word_count >= 20
  if (verbose) {
    if (passed) {
      cli_alert_success("Description length appears adequate")
    } else {
      cli_alert_warning("Description may be too short: {.val {sentences}} sentences, {.val {word_count}} words")
      cli_text("{.emph Treatment: Consider expanding to 2+ sentences, 20+ words}")
    }
  }

  return(list(passed = passed, sentences = sentences, words = word_count, message = "Description length check"))
}

# Documentation diagnostics
diagnose_documentation_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli_h2("Documentation Health Check")
  }

  results <- list()

  # Check for missing \\value tags
  results$value_tags <- diagnose_value_tags(path, verbose)

  # Check roxygen2 usage
  results$roxygen_usage <- diagnose_roxygen_usage(path, verbose)

  # Check example structure
  results$example_structure <- diagnose_example_structure(path, verbose)

  results$passed <- sapply(results, function(x) if(is.logical(x)) x else x$passed)

  return(results)
}

diagnose_value_tags <- function(path, verbose) {
  rd_files <- list.files(file.path(path, "man"), pattern = "\\.Rd$", full.names = TRUE)
  if (length(rd_files) == 0) {
    if (verbose) cli_alert_info("No .Rd files found")
    return(list(passed = TRUE, message = "No .Rd files found"))
  }

  missing_value <- character(0)
  for (file in rd_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    # Skip if it's a data documentation
    if (any(grepl("\\\\docType\\{data\\}", content))) next

    # Check for \\value tag
    if (!any(grepl("\\\\value", content))) {
      missing_value <- c(missing_value, basename(file))
    }
  }

  passed <- length(missing_value) == 0
  if (verbose) {
    if (passed) {
      cli_alert_success("All function documentation has {.code \\\\value} tags")
    } else {
      cli_alert_danger("Missing {.code \\\\value} tags in")
      cli_ul(head(missing_value, 5))
      if (length(missing_value) > 5) {
        cli_text("{.emph ... and {length(missing_value) - 5} more}")
      }
    }
  }

  return(list(passed = passed, missing = missing_value, message = "Value tags check"))
}

diagnose_roxygen_usage <- function(path, verbose) {
  r_files <- list.files(file.path(path, "R"), pattern = "\\.R$", full.names = TRUE)
  if (length(r_files) == 0) {
    return(list(passed = TRUE, message = "No R files found"))
  }

  has_roxygen <- FALSE
  for (file in r_files) {
    content <- safe_read_lines(file)
    if (length(content) > 0 && any(grepl("^\\s*#'", content))) {
      has_roxygen <- TRUE
      break
    }
  }

  if (verbose) {
    if (has_roxygen) {
      cli_alert_info("Roxygen2 usage detected - ensure to run {.code roxygenize()} before submission")
    } else {
      cli_alert_info("No Roxygen2 usage detected")
    }
  }

  return(list(passed = TRUE, has_roxygen = has_roxygen, message = "Roxygen usage check"))
}

diagnose_example_structure <- function(path, verbose) {
  rd_files <- list.files(file.path(path, "man"), pattern = "\\.Rd$", full.names = TRUE)
  if (length(rd_files) == 0) {
    return(list(passed = TRUE, message = "No .Rd files found"))
  }

  issues <- character(0)
  for (file in rd_files) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    # Find examples section
    example_start <- grep("\\\\examples\\{", content)
    if (length(example_start) == 0) next

    # Check for problematic patterns
    if (any(grepl("\\\\dontrun", content))) {
      # Check if it's appropriate (look for interactive, API, etc.)
      example_content <- paste(content[example_start:length(content)], collapse = " ")
      if (!grepl("interactive|API|password|token|key", example_content, ignore.case = TRUE)) {
        issues <- c(issues, paste0(basename(file), ": potential unnecessary \\dontrun"))
      }
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli_alert_success("Example structure appears appropriate")
    } else {
      cli_alert_warning("Potential example structure issues")
      cli_ul(issues)
    }
  }

  return(list(passed = passed, issues = issues, message = "Example structure check"))
}

# General diagnostics
diagnose_general_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli_h2("General Health Check")
  }

  results <- list()

  # Check package size
  results$package_size <- diagnose_package_size(path, verbose)

  # Check for invalid URLs
  results$urls <- diagnose_urls(path, verbose)

  results$passed <- sapply(results, function(x) if(is.logical(x)) x else x$passed)

  return(results)
}

diagnose_package_size <- function(path, verbose) {
  # Get directory size
  all_files <- list.files(path, recursive = TRUE, full.names = TRUE)
  file_info <- file.info(all_files)
  size_mb <- sum(file_info$size, na.rm = TRUE) / (1024^2)

  passed <- size_mb <= 5
  if (verbose) {
    if (passed) {
      cli_alert_success("Package size: {.val {round(size_mb, 2)} MB} (under 5 MB limit)")
    } else {
      cli_alert_warning("Package size: {.val {round(size_mb, 2)} MB} (over 5 MB recommended limit)")
      cli_text("{.emph Treatment: Consider reducing package size or document in cran-comments.md}")
    }
  }

  return(list(passed = passed, size_mb = size_mb, message = "Package size check"))
}

diagnose_urls <- function(path, verbose) {
  # Check URLs in common files
  files_to_check <- c(
    file.path(path, "DESCRIPTION"),
    file.path(path, "README.md"),
    file.path(path, "README.Rmd"),
    list.files(file.path(path, "man"), pattern = "\\.Rd$", full.names = TRUE),
    list.files(file.path(path, "vignettes"), pattern = "\\.(Rmd|md)$", full.names = TRUE)
  )

  files_to_check <- files_to_check[file.exists(files_to_check)]

  if (length(files_to_check) == 0) {
    return(list(passed = TRUE, message = "No files to check for URLs"))
  }

  issues <- character(0)
  for (file in files_to_check) {
    content <- safe_read_lines(file)
    if (length(content) == 0) next

    # Look for http:// URLs (should be https://)
    http_lines <- grep("http://(?!localhost|127\\.0\\.0\\.1)", content, perl = TRUE)
    if (length(http_lines) > 0) {
      issues <- c(issues, paste0(basename(file), ": http:// URL (should be https://)"))
    }

    # Look for potential redirect patterns
    if (any(grepl("bit\\.ly|tinyurl|goo\\.gl", content))) {
      issues <- c(issues, paste0(basename(file), ": potential URL shortener (may redirect)"))
    }
  }

  passed <- length(issues) == 0
  if (verbose) {
    if (passed) {
      cli_alert_success("No obvious URL issues found")
    } else {
      cli_alert_warning("Potential URL issues")
      cli_ul(head(issues, 5))
      if (length(issues) > 5) {
        cli_text("{.emph ... and {length(issues) - 5} more}")
      }
    }
  }

  return(list(passed = passed, issues = issues, message = "URLs check"))
}

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
    cli_h2("CRAN Policy Violations Check")
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
      cli_alert_success("No {.code browser()} calls found")
    } else {
      cli_alert_danger("{.code browser()} calls found (should be removed for CRAN)")
      cli_ul(issues)
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
      cli_alert_success("No dangerous system calls found")
    } else {
      cli_alert_warning("Potential dangerous system calls found")
      cli_ul(head(issues, 5))
      if (length(issues) > 5) {
        cli_text("{.emph ... and {length(issues) - 5} more}")
      }
      cli_text("{.emph Treatment: Review these carefully - may need platform checks}")
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
      cli_alert_success("File operations appear safe")
    } else {
      cli_alert_warning("Potential file operations without temp directory")
      cli_ul(head(issues, 5))
      if (length(issues) > 5) {
        cli_text("{.emph ... and {length(issues) - 5} more}")
      }
      cli_text("{.emph Treatment: Ensure file operations use temporary directories}")
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
      cli_alert_success("Network operations appear properly wrapped")
    } else {
      cli_alert_warning("Potential unwrapped network operations")
      cli_ul(issues)
      cli_text("{.emph Treatment: Consider wrapping in \\dontrun or conditional checks}")
    }
  }

  return(list(passed = passed, issues = issues, message = "Network operations check"))
}


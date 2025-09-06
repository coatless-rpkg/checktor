# DESCRIPTION file diagnostics
diagnose_description_issues <- function(path = ".", verbose = TRUE) {
  if (verbose) {
    cli::cli_h2("DESCRIPTION File Health Check")
  }

  results <- list()

  desc_file <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_file)) {
    if (verbose) cli::cli_alert_danger("DESCRIPTION file not found")
    return(list(passed = FALSE, message = "DESCRIPTION file not found"))
  }

  desc_content <- safe_read_lines(desc_file)
  if (length(desc_content) == 0) {
    if (verbose) cli::cli_alert_danger("Could not read DESCRIPTION file")
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
      cli::cli_alert_success("Software names appear properly formatted")
    } else {
      cli::cli_alert_warning("Potential software name formatting issues")
      cli::cli_ul(issues)
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
      cli::cli_alert_success("No unexplained acronyms found")
    } else {
      cli::cli_alert_warning("Potential unexplained acronyms: {.val {paste(unexplained_acronyms, collapse = ', ')}}")
      cli::cli_text("{.emph Treatment: Consider explaining these acronyms}")
    }
  }

  return(list(passed = passed, issues = unexplained_acronyms, message = "Acronyms check"))
}

diagnose_license_formatting <- function(desc_content, verbose) {
  license_line <- grep("^License:", desc_content, value = TRUE)
  if (length(license_line) == 0) {
    if (verbose) cli::cli_alert_warning("No License field found")
    return(list(passed = FALSE, message = "No License field"))
  }

  # Check for unnecessary "+ file LICENSE"
  has_file_license <- grepl("\\+ file LICENSE", license_line)
  standard_licenses <- c("MIT", "GPL-2", "GPL-3", "BSD_2_clause", "BSD_3_clause", "Apache")

  is_standard <- any(sapply(standard_licenses, function(x) grepl(x, license_line)))

  passed <- !(has_file_license && is_standard)
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("License formatting appears correct")
    } else {
      cli::cli_alert_warning("Potential unnecessary {.code '+ file LICENSE'}")
      cli::cli_text("{.val {license_line}}")
      cli::cli_text("{.emph Treatment: Standard licenses may not need additional LICENSE file}")
    }
  }

  return(list(passed = passed, license = license_line, message = "License check"))
}

diagnose_title_case <- function(desc_content, verbose) {
  title_line <- grep("^Title:", desc_content, value = TRUE)
  if (length(title_line) == 0) {
    if (verbose) cli::cli_alert_warning("No Title field found")
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
      cli::cli_alert_success("Title appears to be in Title Case")
    } else {
      cli::cli_alert_warning("Potential Title Case issues")
      cli::cli_ul(issues)
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
      cli::cli_alert_success("{.code Authors@R} field found")
    } else {
      cli::cli_alert_warning("No {.code Authors@R} field found")
      if (has_legacy) {
        cli::cli_text("{.emph Legacy Author/Maintainer fields detected}")
      }
      cli::cli_text("{.emph Treatment: Consider adding Authors@R field}")
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
      cli::cli_alert_success("Reference formatting appears correct")
    } else if (passed && !has_references) {
      cli::cli_alert_info("No references found in Description")
    } else {
      cli::cli_alert_warning("Reference formatting issues")
      cli::cli_ul(issues)
    }
  }

  return(list(passed = passed, issues = issues, message = "References check"))
}

diagnose_description_length <- function(desc_content, verbose) {
  desc_line <- grep("^Description:", desc_content, value = TRUE)
  if (length(desc_line) == 0) {
    if (verbose) cli::cli_alert_warning("No Description field found")
    return(list(passed = FALSE, message = "No Description field"))
  }

  desc_text <- sub("^Description:\\s*", "", desc_line)
  sentences <- length(strsplit(desc_text, "[.!?]")[[1]])
  word_count <- length(strsplit(desc_text, "\\s+")[[1]])

  passed <- sentences >= 2 && word_count >= 20
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("Description length appears adequate")
    } else {
      cli::cli_alert_warning("Description may be too short: {.val {sentences}} sentences, {.val {word_count}} words")
      cli::cli_text("{.emph Treatment: Consider expanding to 2+ sentences, 20+ words}")
    }
  }

  return(list(passed = passed, sentences = sentences, words = word_count, message = "Description length check"))
}

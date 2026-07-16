# Read a package's Config/checktor/* fields from its DESCRIPTION.
#
# Returns a list with one character vector per known field. Absent fields, a
# missing DESCRIPTION, and a DESCRIPTION that will not parse all yield empty
# vectors, so a package with no config behaves exactly as an unconfigured one.
#
# Values are comma-separated lists; read.dcf folds continuation lines, so we split
# on "," and trim. Written so a dedicated config file could later be merged in
# without changing callers.
checktor_config <- function(path) {
  fields <- c("disable", "allow", "software_names", "acronyms")
  empty <- stats::setNames(rep(list(character(0)), length(fields)), fields)

  desc_file <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_file)) {
    return(empty)
  }
  dcf <- tryCatch(read.dcf(desc_file), error = function(e) NULL)
  if (is.null(dcf) || nrow(dcf) == 0L) {
    return(empty)
  }

  cols <- colnames(dcf)
  read_field <- function(key) {
    col <- paste0("Config/checktor/", key)
    if (!col %in% cols) {
      return(character(0))
    }
    raw <- dcf[1L, col]
    if (is.na(raw)) {
      return(character(0))
    }
    parts <- trimws(strsplit(raw, ",", fixed = TRUE)[[1L]])
    parts[nzchar(parts)]
  }
  lapply(stats::setNames(fields, fields), read_field)
}

# Merge a check's built-in vocabulary with the user's Config/checktor/<field>.
# Append semantics: config never removes a built-in, only adds. Routing every
# vocabulary through this one helper is what keeps the TWO software-name lists
# (software_names and SOFTWARE_NAMES) in sync with one config field.
check_vocab <- function(config, field, builtin) {
  extra <- config[[field]]
  if (is.null(extra) || length(extra) == 0L) {
    return(builtin)
  }
  union(builtin, extra)
}

# Post-filter an assembled checktor_results structure per the config.
#
# Runs AFTER the category checks and BEFORE count_results, so mutating the results
# here keeps count_results and every accessor consistent for free. `disable` drops
# a whole check; `allow` mutes findings whose text contains a substring (or the
# whole check when no substring is given). Locations are file:line, so matching is
# on the finding TEXT, never on line numbers.
apply_suppressions <- function(results, config) {
  known <- names(CHECK_SEVERITY)

  # allow specs -> named list: check -> character vector of substrings (NA = whole check)
  allow_map <- list()
  for (spec in config$allow) {
    parts <- strsplit(spec, ":", fixed = TRUE)[[1L]]
    check <- trimws(parts[[1L]])
    sub <- if (length(parts) >= 2L) {
      trimws(paste(parts[-1L], collapse = ":"))
    } else {
      NA_character_
    }
    allow_map[[check]] <- c(allow_map[[check]], sub)
  }

  # typo protection
  named <- unique(c(config$disable, names(allow_map)))
  unknown <- setdiff(named, known)
  if (length(unknown) > 0L) {
    cli::cli_warn(c(
      "Unknown check name{?s} in {.field Config/checktor}: {.val {unknown}}.",
      "i" = "Names must match a check in {.code tidy()$check}."
    ))
  }

  suppressed <- 0L
  for (cat_name in names(results)) {
    cat <- results[[cat_name]]
    if (!inherits(cat, "checktor_category_result")) {
      next
    }
    check_names <- setdiff(names(cat), "passed")

    for (nm in intersect(check_names, config$disable)) {
      cat[[nm]] <- NULL
      if (!is.null(cat$passed)) {
        cat$passed <- cat$passed[names(cat$passed) != nm]
      }
    }
    check_names <- setdiff(setdiff(names(cat), "passed"), config$disable)

    for (nm in check_names) {
      subs <- allow_map[[nm]]
      if (is.null(subs)) {
        next
      }
      iss <- cat[[nm]]$issues
      if (is.null(iss) || length(iss) == 0L) {
        next
      }
      keep <- rep(TRUE, length(iss))
      for (sub in subs) {
        keep <- if (is.na(sub)) {
          rep(FALSE, length(iss))
        } else {
          keep & !grepl(sub, iss, fixed = TRUE)
        }
      }
      suppressed <- suppressed + sum(!keep)
      cat[[nm]]$issues <- iss[keep]
      if (!any(keep)) {
        cat[[nm]]$passed <- TRUE
        if (!is.null(cat$passed)) cat$passed[[nm]] <- TRUE
      }
    }
    results[[cat_name]] <- cat
  }
  list(results = results, suppressed = suppressed)
}

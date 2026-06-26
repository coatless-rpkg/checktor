# Short-name -> results field map, reused across accessors.
.checktor_cat_map <- c(
  code          = "code_issues",
  description    = "description_issues",
  documentation = "documentation_issues",
  general       = "general_issues",
  policy        = "policy_issues"
)

# Split "file.R:12" into file + integer line; non-locational issues keep the
# raw string as `location` with file/line = NA.
.split_issue <- function(issues) {
  issues <- as.character(issues)
  m <- regmatches(issues, regexec("^(.*):([0-9]+)$", issues))
  file <- vapply(m, function(g) if (length(g) == 3L) g[[2]] else NA_character_, character(1))
  line <- vapply(m, function(g) if (length(g) == 3L) as.integer(g[[3]]) else NA_integer_, integer(1))
  data.frame(file = file, line = line, location = issues, stringsAsFactors = FALSE)
}

# Per-issue frame for one category list. `category` adds a leading column when
# not NA (used by the results-level method).
.category_issue_df <- function(cat, category = NA_character_) {
  check_names <- setdiff(names(cat), "passed")
  parts <- lapply(check_names, function(nm) {
    ch <- cat[[nm]]
    if (!is.list(ch)) return(NULL)
    iss <- ch$issues
    if (is.null(iss) || length(iss) == 0L) return(NULL)
    df <- .split_issue(iss)
    df$check <- nm
    df$message <- if (is.null(ch$message)) NA_character_ else ch$message
    df[, c("check", "file", "line", "location", "message")]
  })
  parts <- Filter(Negate(is.null), parts)
  if (length(parts) == 0L) {
    out <- data.frame(check = character(0), file = character(0), line = integer(0),
                      location = character(0), message = character(0),
                      stringsAsFactors = FALSE)
  } else {
    out <- do.call(rbind, parts)
    rownames(out) <- NULL
  }
  if (!is.na(category)) {
    cat_col <- data.frame(category = character(nrow(out)), stringsAsFactors = FALSE)
    if (nrow(out) > 0L) cat_col$category <- category
    out <- cbind(cat_col, out)
  }
  out
}

#' Extract issues, checks, or a per-category summary from checktor results
#'
#' Plain accessors over the objects returned by [checktor()] and the
#' `diagnose_*_issues()` functions, so you never navigate nested sublists.
#'
#' @param x A `checktor_results`, `checktor_category_result`, or
#'   `checktor_check_result` object.
#' @param ... Unused.
#'
#' @return `issues()` returns a `data.frame` with one row per issue. At the
#'   results level the columns are `category`, `check`, `file`, `line`,
#'   `location`, `message`; a single category drops `category`; a single check
#'   drops `category` and `check`. A healthy object yields a 0-row frame.
#'
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' issues(results)
#' @export
issues <- function(x, ...) UseMethod("issues")

#' @rdname issues
#' @export
issues.checktor_check_result <- function(x, ...) {
  if (length(x$issues) == 0L) {
    return(data.frame(file = character(0), line = integer(0),
                      location = character(0), message = character(0),
                      stringsAsFactors = FALSE))
  }
  df <- .split_issue(x$issues)
  df$message <- if (is.null(x$message)) NA_character_ else x$message
  df
}

#' @rdname issues
#' @export
issues.checktor_category_result <- function(x, ...) .category_issue_df(x, NA_character_)

#' @rdname issues
#' @export
issues.checktor_results <- function(x, ...) {
  parts <- lapply(names(.checktor_cat_map), function(short) {
    cn <- .checktor_cat_map[[short]]
    if (!cn %in% names(x)) return(NULL)
    df <- .category_issue_df(x[[cn]], category = short)
    if (nrow(df) == 0L) return(NULL)
    df[, c("category","check","file","line","location","message")]
  })
  parts <- Filter(Negate(is.null), parts)
  if (length(parts) == 0L) {
    return(data.frame(category = character(0), check = character(0),
                      file = character(0), line = integer(0),
                      location = character(0), message = character(0),
                      stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

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

#' Status predicates for checktor results
#'
#' @param x A `checktor_results`, `checktor_category_result`, or
#'   `checktor_check_result` object.
#' @param ... Unused.
#' @return `passed()`: logical — a single value for a check, a named logical by
#'   check for a category, and a named logical by category for results.
#'   `is_healthy()`: a single logical. `n_issues()` / `n_failed_checks()`:
#'   integer counts. `failed_checks()`: character vector of failing check names
#'   (qualified `"category.check"` at the results level).
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' is_healthy(results)
#' failed_checks(results)
#' @name predicates
NULL

#' @rdname predicates
#' @export
passed <- function(x, ...) UseMethod("passed")
#' @rdname predicates
#' @export
passed.checktor_check_result <- function(x, ...) isTRUE(x$passed)
#' @rdname predicates
#' @export
passed.checktor_category_result <- function(x, ...) x$passed
#' @rdname predicates
#' @export
passed.checktor_results <- function(x, ...) {
  vapply(names(.checktor_cat_map), function(short) {
    cn <- .checktor_cat_map[[short]]
    if (!cn %in% names(x)) return(NA)
    all(x[[cn]]$passed, na.rm = TRUE)
  }, logical(1))
}

#' @rdname predicates
#' @export
is_healthy <- function(x, ...) UseMethod("is_healthy")
#' @rdname predicates
#' @export
is_healthy.checktor_check_result <- function(x, ...) isTRUE(x$passed)
#' @rdname predicates
#' @export
is_healthy.checktor_category_result <- function(x, ...) all(x$passed, na.rm = TRUE)
#' @rdname predicates
#' @export
is_healthy.checktor_results <- function(x, ...) x$metadata$total_issues == 0L

#' @rdname predicates
#' @export
n_issues <- function(x, ...) UseMethod("n_issues")
#' @rdname predicates
#' @export
n_issues.checktor_check_result <- function(x, ...) length(x$issues)
#' @rdname predicates
#' @export
n_issues.checktor_category_result <- function(x, ...) {
  sum(vapply(setdiff(names(x), "passed"),
             function(nm) length(x[[nm]]$issues), integer(1)))
}
#' @rdname predicates
#' @export
n_issues.checktor_results <- function(x, ...) x$metadata$total_issues

#' @rdname predicates
#' @export
n_failed_checks <- function(x, ...) UseMethod("n_failed_checks")
#' @rdname predicates
#' @export
n_failed_checks.checktor_category_result <- function(x, ...) sum(!x$passed, na.rm = TRUE)
#' @rdname predicates
#' @export
n_failed_checks.checktor_results <- function(x, ...) x$metadata$failed_checks

#' @rdname predicates
#' @export
failed_checks <- function(x, ...) UseMethod("failed_checks")
#' @rdname predicates
#' @export
failed_checks.checktor_category_result <- function(x, ...) {
  p <- x$passed
  names(p)[!p]
}
#' @rdname predicates
#' @export
failed_checks.checktor_results <- function(x, ...) {
  out <- character(0)
  for (short in names(.checktor_cat_map)) {
    cn <- .checktor_cat_map[[short]]
    if (!cn %in% names(x)) next
    p <- x[[cn]]$passed
    failed <- names(p)[!p]
    if (length(failed)) out <- c(out, paste0(short, ".", failed))
  }
  out
}

# Per-check frame for one category list.
.category_tidy_df <- function(cat, category = NA_character_) {
  check_names <- setdiff(names(cat), "passed")
  check_names <- check_names[vapply(check_names, function(nm) is.list(cat[[nm]]), logical(1))]
  if (length(check_names) == 0L) {
    out <- data.frame(check = character(0), passed = logical(0),
                      n_issues = integer(0), message = character(0),
                      stringsAsFactors = FALSE)
  } else {
    out <- data.frame(
      check    = check_names,
      passed   = vapply(check_names, function(nm) isTRUE(cat[[nm]]$passed), logical(1)),
      n_issues = vapply(check_names, function(nm) length(cat[[nm]]$issues), integer(1)),
      message  = vapply(check_names, function(nm) {
        m <- cat[[nm]]$message; if (is.null(m)) NA_character_ else m
      }, character(1)),
      stringsAsFactors = FALSE, row.names = NULL
    )
  }
  if (!is.na(category)) {
    cat_col <- data.frame(category = character(nrow(out)), stringsAsFactors = FALSE)
    if (nrow(out) > 0L) cat_col$category <- category
    out <- cbind(cat_col, out)
  }
  out
}

#' Tidy a checktor result into a per-check data frame
#'
#' @param x A `checktor_results` or `checktor_category_result` object.
#' @param ... Unused.
#' @return A `data.frame` with one row per check: `category` (results level
#'   only), `check`, `passed`, `n_issues`, `message`.
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' tidy(results)
#' @rdname tidy
#' @exportS3Method generics::tidy
tidy.checktor_results <- function(x, ...) {
  parts <- lapply(names(.checktor_cat_map), function(short) {
    cn <- .checktor_cat_map[[short]]
    if (!cn %in% names(x)) return(NULL)
    .category_tidy_df(x[[cn]], category = short)[, c("category","check","passed","n_issues","message")]
  })
  out <- do.call(rbind, Filter(Negate(is.null), parts))
  rownames(out) <- NULL
  out
}

#' @rdname tidy
#' @exportS3Method generics::tidy
tidy.checktor_category_result <- function(x, ...) .category_tidy_df(x, NA_character_)

#' @rdname tidy
#' @export
as.data.frame.checktor_results <- function(x, ...) tidy(x)
#' @rdname tidy
#' @export
as.data.frame.checktor_category_result <- function(x, ...) tidy(x)

#' Per-category summary of checktor results
#'
#' @param object A `checktor_results` or `checktor_category_result` object.
#' @param ... Unused.
#' @return For results: a 5-row `data.frame` (`category, checks, passed,
#'   failed, issues`). For a category: a 1-row `data.frame` (`checks, passed,
#'   failed, issues`).
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' summary(results)
#' @rdname checktor-summary
#' @export
summary.checktor_category_result <- function(object, ...) {
  p <- object$passed
  checks <- length(p); passed <- sum(p, na.rm = TRUE)
  issues <- sum(vapply(setdiff(names(object), "passed"),
                       function(nm) length(object[[nm]]$issues), integer(1)))
  data.frame(checks = checks, passed = passed, failed = checks - passed,
             issues = issues, stringsAsFactors = FALSE)
}

#' @rdname checktor-summary
#' @export
summary.checktor_results <- function(object, ...) {
  rows <- lapply(names(.checktor_cat_map), function(short) {
    cn <- .checktor_cat_map[[short]]
    if (!cn %in% names(object)) return(NULL)
    s <- summary.checktor_category_result(object[[cn]])
    cbind(category = short, s, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, Filter(Negate(is.null), rows))
  rownames(out) <- NULL
  out
}

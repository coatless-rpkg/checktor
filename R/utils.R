#' Quick Health Check
#'
#' Runs [checktor()] with minimal output, suitable for CI/CD pipelines.
#'
#' @param path Character. Path to the R package directory. Default: `"."`.
#' @param severity Character. Which severity tiers count toward the result: any
#'   of `"policy"`, `"robustness"`, `"opinion"`. Defaults to
#'   `getOption("checktor.severity", c("policy", "robustness"))`, so a build is
#'   not failed by a convention nobody enforces. Pass all three to hold the
#'   package to the conventions as well. See [checktor()].
#'
#' @return
#' Logical. `TRUE` if no issues were found, `FALSE` otherwise.
#'
#' @export
#' @examples
#' # A clean synthetic package passes; a known-bad one does not
#' pkg_bad <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                      show_content = FALSE)
#' checkup(pkg_bad)
checkup <- function(
  path = ".",
  severity = getOption("checktor.severity", DEFAULT_SEVERITY)
) {
  results <- checktor(
    path,
    verbose = FALSE,
    progress = FALSE,
    severity = severity
  )
  results$metadata$total_issues == 0L
}

#' Configure Package Doctor Defaults
#'
#' Sets session-wide defaults for [checktor()] behavior. Subsequent calls to
#' `checktor()` (and helpers that delegate to it) pick up these defaults via
#' `getOption()`.
#'
#' @param verbose_default Logical. Default verbosity for `checktor()`.
#' @param progress_default Logical. Default progress-bar setting.
#' @param color Logical. Whether `cli` should emit ANSI color. Sets
#'   `cli.num_colors` via `options()`.
#'
#' @return
#' Invisibly returns the previous values of the changed options, so the call
#' can be reversed with `options(.)`.
#'
#' @export
#' @examples
#' # Save defaults so we can restore them after the example runs
#' old <- options(checktor.verbose = NULL, checktor.progress = NULL)
#' on.exit(options(old), add = TRUE)
#'
#' configure_doctor(verbose_default = FALSE)
#' getOption("checktor.verbose")
configure_doctor <- function(
  verbose_default = TRUE,
  progress_default = TRUE,
  color = TRUE
) {
  old <- options(
    checktor.verbose = verbose_default,
    checktor.progress = progress_default,
    cli.num_colors = if (isTRUE(color)) NULL else 1L
  )

  cli::cli_alert_success("Package doctor configuration updated")
  invisible(old)
}

#' Find the Root of the Package Containing a Path
#'
#' Walks up from `path` until it finds the directory holding a `DESCRIPTION`
#' file, so checktor can be run from anywhere inside a package tree rather than
#' only from the directory holding `DESCRIPTION`. That is what lets `checktor()`
#' work with your working directory set to `R/`, `tests/testthat/`, or any other
#' subdirectory.
#'
#' Every checktor entry point calls this on the `path` it is given, so you
#' rarely need it directly. It is exported for custom checks registered with
#' [register_check()], which receive a path that has already been resolved.
#'
#' @param path Character. A directory inside a package, or a file within one.
#'   Default: `"."`.
#'
#' @return
#' Character. The package root, as an absolute path, when one is found above
#' `path`. When `path` itself holds a `DESCRIPTION` it is returned unchanged, so
#' an existing caller sees exactly what it passed in. When no package root is
#' found at all, the search falls back to the directory it started from, meaning
#' `path` for a directory and its parent for a file, which leaves the caller
#' reporting the problem against the place the user pointed at.
#'
#' @seealso [checktor()], which resolves its `path` this way.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#'
#' # From the package root, the path is handed back untouched
#' identical(find_package_root(pkg), pkg)
#'
#' # From a subdirectory, the root is found by walking up
#' basename(find_package_root(file.path(pkg, "R")))
find_package_root <- function(path = ".") {
  # A file is a reasonable thing to point at, so start from its directory.
  if (!dir.exists(path) && file.exists(path)) {
    path <- dirname(path)
  }
  if (!dir.exists(path)) {
    return(path)
  }
  # Already a root: hand `path` back exactly as given, relative form and all, so
  # nothing about the existing behaviour changes for the common case.
  if (file.exists(file.path(path, "DESCRIPTION"))) {
    return(path)
  }

  current <- normalizePath(path, winslash = "/", mustWork = FALSE)
  repeat {
    parent <- dirname(current)
    # dirname() of a filesystem root is itself, which is where the walk stops.
    if (identical(parent, current)) {
      break
    }
    current <- parent
    if (file.exists(file.path(current, "DESCRIPTION"))) {
      return(current)
    }
  }

  # No package anywhere above: unchanged, so "not a package" errors name the
  # directory the caller actually asked about.
  path
}

# ---- internal helpers --------------------------------------------------------

# Escape a literal so it can be dropped into a regular expression. Names such as
# data.table, C++ and C# carry metacharacters, and an unescaped one silently
# matches text it should not.
escape_regex <- function(x) {
  gsub("([.^$*+?(){}|\\[\\]\\\\])", "\\\\\\1", x, perl = TRUE)
}

safe_read_lines <- function(file) {
  if (!file.exists(file)) {
    return(character(0))
  }
  tryCatch(readLines(file, warn = FALSE), error = function(e) character(0))
}

# Lists R source files under <path>/R/. Returns character(0) if R/ is absent.
list_r_files <- function(path) {
  r_dir <- file.path(path, "R")
  if (!dir.exists(r_dir)) {
    return(character(0))
  }
  list.files(r_dir, pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
}

# Reads .Rbuildignore patterns and returns a function(rel_path) -> logical
# that's TRUE when the path matches any ignore pattern. The always-skip set
# (.git, .Rproj.user, .DS_Store, etc.) is applied unconditionally.
build_ignore_matcher <- function(path) {
  always_skip <- c(
    "^\\.git(/|$)",
    "^\\.Rproj\\.user(/|$)",
    "^\\.Rhistory$",
    "^\\.RData$",
    "^\\.DS_Store$"
  )

  rbi <- file.path(path, ".Rbuildignore")
  patterns <- if (file.exists(rbi)) {
    lns <- safe_read_lines(rbi)
    lns <- lns[nzchar(lns)]
    lns[!grepl("^\\s*#", lns)]
  } else {
    character(0)
  }
  patterns <- c(patterns, always_skip)

  # A path is ignored if it, OR any of its ancestor directories, matches a
  # pattern. R CMD build lists directory entries (`dir(include.dirs = TRUE)`) and
  # unlinks a matched directory's whole subtree, so a top-level `^docs$` excludes
  # every file under `docs/`. Testing only the leaf path missed that and counted
  # ignored trees such as a pkgdown `docs/` or a `.quarto` cache against the size
  # limit. Matching is Perl and case-insensitive, as in `tools:::inRbuildignore()`.
  function(rel_path) {
    vapply(
      rel_path,
      function(f) {
        parts <- strsplit(f, "/", fixed = TRUE)[[1]]
        candidates <- vapply(
          seq_along(parts),
          function(k) paste(parts[seq_len(k)], collapse = "/"),
          character(1)
        )
        any(vapply(
          patterns,
          function(pat) {
            any(grepl(pat, candidates, perl = TRUE, ignore.case = TRUE))
          },
          logical(1)
        ))
      },
      logical(1),
      USE.NAMES = FALSE
    )
  }
}

# Schedule `unlink(path, recursive = TRUE)` on the caller's exit. Used by
# scenario builders that hand out temp paths the caller still needs to use.
defer_cleanup <- function(path, envir = parent.frame()) {
  do.call(
    base::on.exit,
    list(
      substitute(
        if (dir.exists(p)) unlink(p, recursive = TRUE),
        list(p = path)
      ),
      add = TRUE
    ),
    envir = envir
  )
  invisible(path)
}

# Build the named $passed logical vector from a list of checktor_check_result
# objects (one per sub-diagnostic). Tolerates entries that are themselves
# raw logicals (e.g., the no-R-files shortcut).
summarise_passed <- function(results) {
  vapply(
    results,
    function(x) if (is.logical(x)) x[[1L]] else isTRUE(x$passed),
    logical(1)
  )
}

# Runs a list of sub-diagnostics under a tryCatch wrapper. Each entry of
# `checks` is a (name -> function(path, verbose)) pair. Any error becomes a
# failing checktor_check_result with the error message as its single issue,
# so errors surface in reports rather than being silently swallowed.
run_checks <- function(checks, path, verbose, severity = SEVERITY_LEVELS) {
  # A check whose tier the caller did not ask for is not run at all. Running it
  # and hiding the result would still pay for the parse and still let it error.
  wanted <- names(checks)[check_severity(names(checks)) %in% severity]
  checks <- checks[wanted]

  results <- list()
  for (nm in names(checks)) {
    results[[nm]] <- tryCatch(
      checks[[nm]](path, verbose),
      error = function(e) {
        if (verbose) {
          cli::cli_alert_danger("Error in {nm} diagnostic: {e$message}")
        }
        checktor_check_result(
          FALSE,
          paste0("Diagnostic errored: ", conditionMessage(e)),
          paste0(nm, " (errored)")
        )
      }
    )
    # Tag the result so accessors and print methods can group by tier without
    # consulting the registry again.
    results[[nm]]$severity <- check_severity(nm)
  }
  results$passed <- summarise_passed(results[names(checks)])
  class(results) <- "checktor_category_result"
  results
}

# The R code inside a vignette, with the prose thrown away.
#
# Vignettes are mostly English. Scanning them line by line means every narrative
# mention of a function reads as a call, which is exactly the mistake the AST
# rewrite exists to prevent. Pull out the fenced R chunks and hand back just the
# code, so it can be parsed like any other R.
#
# A chunk marked `eval = FALSE` is skipped: it never runs, so it cannot do anything
# a policy check should care about.
vignette_r_code <- function(file) {
  lines <- safe_read_lines(file)
  if (length(lines) == 0L) {
    return("")
  }

  open_re <- "^\\s*```+\\s*\\{\\s*r\\b" # ```{r ...}
  close_re <- "^\\s*```+\\s*$"

  out <- character(0)
  i <- 1L
  while (i <= length(lines)) {
    if (grepl(open_re, lines[[i]], perl = TRUE)) {
      header <- lines[[i]]
      j <- i + 1L
      chunk <- character(0)
      while (j <= length(lines) && !grepl(close_re, lines[[j]], perl = TRUE)) {
        chunk <- c(chunk, lines[[j]])
        j <- j + 1L
      }
      # `eval=FALSE` chunks never execute.
      if (!grepl("eval\\s*=\\s*F", header, perl = TRUE)) {
        out <- c(out, chunk)
      }
      i <- j + 1L
    } else {
      i <- i + 1L
    }
  }
  paste(out, collapse = "\n")
}

# The package's own name, for recognising options it owns (`datatable.verbose`,
# `cli.width`, `knitr.progress`). Empty string when DESCRIPTION is unreadable.
own_option_prefix <- function(path) {
  f <- file.path(path, "DESCRIPTION")
  if (!file.exists(f)) {
    return("")
  }
  nm <- tryCatch(read.dcf(f, fields = "Package")[1, 1], error = function(e) NA)
  if (is.na(nm)) "" else as.character(nm)
}

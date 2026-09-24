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
#' # configure_doctor() returns the options it replaced
#' old <- configure_doctor(verbose_default = FALSE)
#' getOption("checktor.verbose")
#'
#' # Put them back
#' options(old)
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

# Escape text so cli prints it verbatim. cli glue-interpolates what it prints, and
# a finding quotes the package under check -- a Title, a file name, a README link
# -- so a `{...}` there would run as R code, or vanish. Doubled braces are cli's
# own escape. Apply it where text is printed, never to the stored `$issues`,
# which tidy(), ci_report() and health_report() hand on unprinted.
cli_literal <- function(x) {
  gsub("([{}])", "\\1\\1", x)
}

# A file R cannot open (a directory, or one without read permission) makes
# readLines() warn before it errors, and the warning reached the console while
# the error was caught. Both are handled here, so a bad file reads as empty.
safe_read_lines <- function(file) {
  if (!file.exists(file)) {
    return(character(0))
  }
  tryCatch(
    suppressWarnings(readLines(file, warn = FALSE)),
    error = function(e) character(0)
  )
}

# read.dcf() without the console noise. On a file R cannot open, read.dcf() stops
# with only "cannot open the connection" and leaves the reason ("it is a
# directory", "Permission denied") in a warning that reaches the console. This
# asks the file system first, so the reason does not depend on how R's messages
# are worded in the session's language, and stops with it, classed
# `checktor_unopenable` so a caller can tell it from a file that opened but does
# not parse. The message follows the file's name: "is a directory, not a file".
# Only a file that passes those checks is read, with read.dcf()'s warnings
# muffled and its error, the reason it does not parse, passed on.
read_dcf_quietly <- function(file, fields = NULL) {
  reason <- if (dir.exists(file)) {
    "is a directory, not a file"
  } else if (!file.exists(file)) {
    "file not found"
  } else if (file.access(file, 4L) != 0L) {
    "cannot be read (permission denied)"
  }
  if (!is.null(reason)) {
    stop(structure(
      class = c("checktor_unopenable", "error", "condition"),
      list(message = reason, call = NULL)
    ))
  }
  out <- tryCatch(
    suppressWarnings(read.dcf(file, fields = fields)),
    error = function(e) e
  )
  if (inherits(out, "error")) {
    stop(conditionMessage(out), call. = FALSE)
  }
  out
}

# Lists R source files under <path>/R/. Returns character(0) if R/ is absent.
list_r_files <- function(path) {
  r_dir <- file.path(path, "R")
  if (!dir.exists(r_dir)) {
    return(character(0))
  }
  list.files(r_dir, pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
}

# Lists the files under <path>/<subdir> that the built tarball includes:
# everything matching `pattern`, minus whatever .Rbuildignore excludes. Returns
# character(0) when the directory is absent.
#
# The filter is the point. `R CMD build` drops every file .Rbuildignore matches,
# so an excluded file is not in the tarball and no reviewer ever opens it. Two
# ordinary workflows rely on that. The {devtag} package's `@dev` tag documents an
# unexported function and adds the .Rd to .Rbuildignore, so contributors get the
# help page and users do not. `usethis::use_article()` puts a pkgdown-only piece
# in `vignettes/articles/` and excludes the directory. Reading either told
# maintainers to go and fix code that CRAN will never see.
list_included_files <- function(path, subdir, pattern, recursive = FALSE) {
  dir <- file.path(path, subdir)
  if (!dir.exists(dir)) {
    return(character(0))
  }
  files <- list.files(dir, pattern = pattern, recursive = recursive)
  if (length(files) == 0L) {
    return(character(0))
  }
  ignore <- build_ignore_matcher(path)
  file.path(dir, files[!ignore(file.path(subdir, files))])
}

# The help topics the tarball includes. Only the top level of man/ is listed,
# because only `man/*.Rd` becomes a topic: `man/figures/` holds images and
# `man/macros/` holds \newcommand definitions, and neither is one to check.
list_rd_files <- function(path) {
  list_included_files(path, "man", "\\.Rd$")
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
  # A disabled check does not run either, so it cannot print a finding in the live
  # output that the results then leave out.
  wanted <- setdiff(wanted, checktor_config(path)$disable)
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

# The R code inside a vignette, with the prose blanked out.
#
# Vignettes are mostly English. Scanning them line by line means every narrative
# mention of a function reads as a call, which is exactly the mistake the AST
# rewrite exists to prevent. Keep only the lines of the R chunks, so the result
# can be parsed like any other R.
#
# Every other line is blanked rather than dropped. A finding names a line, and
# with the prose gone the code was numbered from the top of the first chunk, so a
# call on line 9 of a .qmd was reported on line 2.
#
# A chunk whose options set `eval` false is skipped: it never runs, so it cannot do
# anything a policy check should care about.
vignette_r_code <- function(file) {
  lines <- safe_read_lines(file)
  if (length(lines) == 0L) {
    return("")
  }
  code <- if (grepl("\\.[Rr]nw$", file)) {
    rnw_code_lines(lines)
  } else {
    markdown_code_lines(lines)
  }
  # `<<setup>>` alone on a line splices in another chunk's code, in Sweave and in
  # knitr alike. It is not R itself.
  code <- code & !grepl("^\\s*<<.+>>\\s*$", lines, perl = TRUE)
  lines[!code] <- ""
  paste(lines, collapse = "\n")
}

# Which lines of an R Markdown or Quarto file are code in an R chunk that runs.
markdown_code_lines <- function(lines) {
  open_re <- "^\\s*```+\\s*\\{\\s*r\\b" # ```{r ...}
  close_re <- "^\\s*```+\\s*$"
  code <- logical(length(lines))
  i <- 1L
  while (i <= length(lines)) {
    if (!grepl(open_re, lines[[i]], perl = TRUE)) {
      i <- i + 1L
      next
    }
    j <- i + 1L
    while (j <= length(lines) && !grepl(close_re, lines[[j]], perl = TRUE)) {
      j <- j + 1L
    }
    body <- seq.int(i + 1L, length.out = j - i - 1L)
    # The options run to the last brace on the line, as knitr reads them: one
    # may hold braces of its own, as a LaTeX figure caption does.
    header <- sub("^\\s*```+\\s*\\{\\s*r\\b", "", lines[[i]], perl = TRUE)
    header <- sub("\\}[^}]*$", "", header, perl = TRUE)
    if (chunk_evaluates(header, lines[body])) {
      code[body] <- TRUE
    }
    i <- j + 1L
  }
  code
}

# Which lines of an Sweave (.Rnw) file are code in a chunk that runs. A chunk opens
# with `<<options>>=` and runs until a line starting with `@` or the next chunk.
# Reading only fenced chunks, as for R Markdown, found no code at all.
rnw_code_lines <- function(lines) {
  open_re <- "^\\s*<<(.*)>>=.*$"
  close_re <- "^\\s*@"
  code <- logical(length(lines))
  i <- 1L
  while (i <= length(lines)) {
    if (!grepl(open_re, lines[[i]], perl = TRUE)) {
      i <- i + 1L
      next
    }
    j <- i + 1L
    while (
      j <= length(lines) &&
        !grepl(close_re, lines[[j]], perl = TRUE) &&
        !grepl(open_re, lines[[j]], perl = TRUE)
    ) {
      j <- j + 1L
    }
    body <- seq.int(i + 1L, length.out = j - i - 1L)
    header <- sub(open_re, "\\1", lines[[i]], perl = TRUE)
    if (chunk_evaluates(header, lines[body])) {
      code[body] <- TRUE
    }
    # A chunk that ends where the next one opens leaves that line to open it.
    i <- j
  }
  code
}

# Whether a knitr or Sweave chunk runs, from the options in its header and the
# `#|` lines at its top. Quarto writes options only as `#|` lines, in YAML
# (`#| eval: false`); knitr also reads them in R form (`#| eval = FALSE`). knitr
# merges the two sets with the `#|` lines last, so an `eval` there wins over the
# header's. Only a literal false is read as false: an `eval` computed at knit time
# may well be true.
#
# knitr reads the YAML with the yaml package, which takes YAML 1.1's n, no and
# off as false too, and it evaluates an `!expr` value: `!expr FALSE` is false.
#
# An option line starts `#| `, space included, as knitr requires: `#|eval: no`
# is a comment to knitr, and the chunk runs.
chunk_evaluates <- function(header, body) {
  is_option <- grepl("^\\s*#\\| ", body, perl = TRUE)
  n <- if (all(is_option)) length(body) else which.min(is_option) - 1L
  options <- sub("^\\s*#\\|\\s*", "", body[seq_len(n)], perl = TRUE)

  set_in_chunk <- grepl("(^|,)\\s*eval\\s*[:=]", options, perl = TRUE)
  if (any(set_in_chunk)) {
    false_yaml <- paste0(
      "^eval\\s*:\\s*",
      "(?:n|N|no|No|NO|off|Off|OFF|false|False|FALSE|!expr\\s+(?:FALSE|F))",
      "\\s*(#.*)?$"
    )
    false_r <- "(^|,)\\s*eval\\s*=\\s*(FALSE|F)\\s*(,|$)"
    return(!any(
      grepl(false_yaml, options, perl = TRUE) |
        grepl(false_r, options, perl = TRUE)
    ))
  }
  # Sweave reads a logical option case-blind, so `eval=false` counts there.
  !grepl(
    "(^|[\\s,])eval\\s*=\\s*(?i:false|f)\\s*(,|$)",
    trimws(header),
    perl = TRUE
  )
}

# The package's own name, for recognising options it owns (`datatable.verbose`,
# `cli.width`, `knitr.progress`). Empty string when DESCRIPTION is unreadable.
own_option_prefix <- function(path) {
  f <- file.path(path, "DESCRIPTION")
  if (!file.exists(f)) {
    return("")
  }
  nm <- tryCatch(
    read_dcf_quietly(f, fields = "Package")[1, 1],
    error = function(e) NA
  )
  if (is.na(nm)) "" else as.character(nm)
}

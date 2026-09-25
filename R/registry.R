# The built-in checks, listed once.
#
# Each row is one check: its name, the category that runs it, its severity tier
# (see R/severity.R for what the tiers mean), its label and when it runs. Everything that
# used to keep its own copy of this is now read from here: CHECK_SEVERITY and
# CHECK_WHEN, the list each diagnose_<category>_issues() runs, the checks that
# are skipped when DESCRIPTION cannot be read, and the categories every report
# walks. Rows run in the order they appear within their category, which is the
# order tidy() and the printed report show them in.
#
# A check `lab_<name>()` must exist for every row; the orchestrators call it by
# that name, forwarding whichever shared parse its signature asks for (`parsed`
# for R sources, `desc` for the DESCRIPTION fields).
#
# `when` is one of
#   always   runs in every checktor() run
#   console  runs when a person is at the console, since it needs a network
#   backend  runs when the external tool it needs is installed
#   request  runs only when you call it, because no authority supports it or it is
#            a workflow convention rather than a package property
# A console or backend check that cannot run returns checktor_skipped_result(), so
# it is reported as skipped rather than passed. A request check never joins a run.
#
# `label` is the check's name as people read it, the `$message` of its result:
# check_label("tf_usage") is "T/F usage check". A check reports under it, and
# anything that has to name a check without running it uses the same string.
#
# `reads_desc` is TRUE for the DESCRIPTION checks that read the parsed fields.
# When R cannot read the file each of them is reported skipped under its label,
# so it prints as the check itself would have.

# The categories, in the order checktor() runs them and every report lists them.
CHECK_CATEGORIES <- c(
  "code",
  "description",
  "documentation",
  "general",
  "policy"
)

# Each category's slot in a checktor_results object, named by category.
CATEGORY_FIELDS <- stats::setNames(
  paste0(CHECK_CATEGORIES, "_issues"),
  CHECK_CATEGORIES
)

# The function that runs each category's panel.
CATEGORY_ORCHESTRATORS <- c(
  code = "diagnose_code_issues",
  description = "diagnose_description_issues",
  documentation = "diagnose_documentation_issues",
  general = "diagnose_general_issues",
  policy = "diagnose_policy_violations"
)

# The heading each category's panel prints.
CATEGORY_TITLES <- c(
  code = "Code Health Check",
  description = "DESCRIPTION File Health Check",
  documentation = "Documentation Health Check",
  general = "General Health Check",
  policy = "CRAN Policy Violations Check"
)

check_table <- function(...) {
  rows <- list(...)
  column <- function(field) vapply(rows, `[[`, character(1), field)
  data.frame(
    name = column("name"),
    category = column("category"),
    severity = column("severity"),
    label = column("label"),
    when = column("when"),
    reads_desc = vapply(rows, `[[`, logical(1), "reads_desc"),
    stringsAsFactors = FALSE
  )
}

check_row <- function(
  name,
  category,
  severity,
  label,
  when = "always",
  reads_desc = FALSE
) {
  list(
    name = name,
    category = category,
    severity = severity,
    label = label,
    when = when,
    reads_desc = reads_desc
  )
}

BUILTIN_CHECKS <- check_table(
  # ---- code ----
  # T and F are variables and can be rebound
  check_row("tf_usage", "code", "robustness", "T/F usage check"),
  # alters the user's RNG state
  check_row("seed_setting", "code", "policy", "Seed setting check"),
  # unsuppressable console output
  check_row("print_cat_usage", "code", "policy", "Print/cat usage check"),
  # must restore the user's options
  check_row("option_changes", "code", "policy", "Option changes check"),
  # no writing to the home filespace
  check_row("home_writing", "code", "policy", "Home writing check"),
  # CRAN's policy permits writing to the session temp directory; it is the one
  # place it EXPRESSLY allows. tempfile() lands inside tempdir(), and R removes
  # tempdir() at session end, so an un-unlinked tempfile() breaks no rule.
  # tidiness, not policy
  check_row("temp_cleanup", "code", "opinion", "Temp cleanup check"),
  # no modifying the global environment
  check_row("globalenv_mod", "code", "policy", "GlobalEnv modification check"),
  # a package may not install packages
  check_row(
    "installed_packages", "code", "policy",
    "installed.packages() usage check"
  ),
  # must restore options(warn=)
  check_row("warn_option", "code", "policy", "Warn option check"),
  check_row(
    "software_install", "code", "policy",
    "Software installation check"
  ),
  # "never use more than two simultaneously"
  check_row("core_usage", "code", "policy", "Core usage check"),
  # attaching alters the user's search path
  check_row(
    "library_in_pkg", "code", "robustness",
    "library() in pkg code check"
  ),
  # ?detectCores: "NA if the answer is unknown"
  check_row(
    "detect_cores_robustness", "code", "robustness",
    "detectCores() NA check"
  ),
  # must restore environment variables
  check_row("sys_setenv", "code", "policy", "Sys.setenv reset check"),
  # ::: reaches an object its author may change
  check_row("internal_ns", "code", "robustness", "Internal namespace check"),
  # A leaked secret; no CRAN citation, but a real defect.
  check_row(
    "hardcoded_credentials", "code", "robustness",
    "Hardcoded credential check"
  ),

  # ---- description ----
  # Whether R can read the file at all. R CMD build and INSTALL stop on a file R
  # cannot read. It re-reads the file rather than taking the parsed fields,
  # because the question is about the file, not about the fields.
  check_row(
    "description_file", "description", "policy",
    "DESCRIPTION file check"
  ),
  # CRAN incoming NOTE on unknown fields, Remotes
  check_row(
    "description_fields", "description", "policy",
    "DESCRIPTION fields check",
    reads_desc = TRUE
  ),
  # CRAN incoming NOTE on template text
  check_row(
    "description_placeholders", "description", "policy",
    "DESCRIPTION placeholders check",
    reads_desc = TRUE
  ),
  # WRE: single-quote other software
  check_row(
    "software_names", "description", "policy",
    "Software names check",
    reads_desc = TRUE
  ),
  # WRE: single-quote programming languages (own kind of policy)
  check_row(
    "language_names", "description", "policy",
    "Language names check",
    reads_desc = TRUE
  ),
  # JSON, HTML, SQL and the other formats are written bare by most packages CRAN
  # accepts, so a bare one breaks no rule it enforces (#16). A style choice CRAN
  # accepts either way, so it runs on request.
  check_row(
    "format_names", "description", "opinion",
    "Format names check",
    when = "request"
  ),
  # Reviewers ask; nothing enforces it.
  check_row(
    "acronyms", "description", "opinion",
    "Acronyms check",
    reads_desc = TRUE
  ),
  # An invalid license is a rejection.
  check_row(
    "license", "description", "policy",
    "License check",
    reads_desc = TRUE
  ),
  # Cookbook: R ships the GPL text itself.
  check_row(
    "license_file_unneeded", "description", "policy",
    "License file pointer check",
    reads_desc = TRUE
  ),
  # CRAN incoming NOTE
  check_row(
    "title_case", "description", "policy",
    "Title case check",
    reads_desc = TRUE
  ),
  # 65 chars is a convention
  check_row(
    "title_length", "description", "opinion",
    "Title length check",
    reads_desc = TRUE
  ),
  # WRE: do not repeat the package name
  check_row(
    "title_package_name", "description", "policy",
    "Title package-name check",
    reads_desc = TRUE
  ),
  # A mis-transplant of CRAN's real rule, whose source is
  #     if (grepl("^(The|This|A|In this|In the) package", descr)) ...
  # That rule applies to the DESCRIPTION field, not the Title, and requires the
  # literal noun "package" after the article. checktor kept the article
  # alternation, dropped the "package" anchor, and re-pointed it at the Title,
  # turning a narrow anti-boilerplate rule into a blanket ban on ordinary English.
  # jsonlite ("A Simple and Robust JSON Parser and Generator for R") and curl
  # ("A Modern and Flexible Web Client for R") are both on CRAN with such titles.
  # `description_starts_with` already enforces the real rule, in the right field.
  # No authority supports it, so it runs on request.
  check_row(
    "title_starts_with_article", "description", "opinion",
    "Title starts-with-article check",
    when = "request"
  ),
  check_row(
    "title_redundant_phrases", "description", "opinion",
    "Title redundant-phrases check",
    reads_desc = TRUE
  ),
  # It asserted that single quotes are RESERVED for software names, so a quoted
  # function name was a violation. Writing R Extensions actually says single
  # quotes are for non-English usage, INCLUDING the names of other packages and
  # external software: an inclusive list, not an exclusive one. A function name is
  # non-English usage and is legitimately single-quoted. Nothing in WRE or the
  # CRAN policy forbids `'digest()'`, and digest itself ships exactly that. No
  # authority supports it, so it runs on request.
  check_row(
    "description_function_quotes", "description", "opinion",
    "Description function-quotes check",
    when = "request"
  ),
  # A placeholder Authors@R is a rejection.
  check_row(
    "authors", "description", "policy",
    "Authors@R field check",
    reads_desc = TRUE
  ),
  # CRAN incoming NOTE on bad ORCID/ROR ids
  check_row(
    "identifier_format", "description", "policy",
    "Author identifier check",
    reads_desc = TRUE
  ),
  # ?person says authors who are natural persons are copyright holders by default
  # and need no cph role, so a package written by people is not missing anything.
  # It runs on request.
  check_row(
    "cph_role", "description", "opinion",
    "cph role check",
    when = "request"
  ),
  # CRAN incoming NOTE on <doi:> form
  check_row(
    "references", "description", "policy",
    "References check",
    reads_desc = TRUE
  ),
  # CRAN incoming NOTE on non-ISO/stale Date
  check_row(
    "date_format", "description", "policy",
    "Date field check",
    reads_desc = TRUE
  ),
  # CRAN incoming NOTE on non-UTF-8 Encoding
  check_row(
    "encoding_utf8", "description", "policy",
    "Encoding field check",
    reads_desc = TRUE
  ),
  # CRAN incoming NOTE on Version components
  check_row(
    "version_format", "description", "policy",
    "Version field check",
    reads_desc = TRUE
  ),
  # aspell NOTE; noisy, and needs aspell or hunspell
  check_row(
    "spelling", "description", "opinion",
    "Spelling check",
    when = "backend", reads_desc = TRUE
  ),
  check_row(
    "description_length", "description", "opinion",
    "Description length check",
    reads_desc = TRUE
  ),
  # CRAN incoming NOTE
  check_row(
    "description_starts_with", "description", "policy",
    "Description opening check",
    reads_desc = TRUE
  ),
  # WRE quoting rules
  check_row(
    "description_quoted_quotes", "description", "policy",
    "Description double-quotes check",
    reads_desc = TRUE
  ),
  # An unfilled LICENSE template. It reads LICENSE alone, so it runs even when
  # DESCRIPTION cannot be read.
  check_row("license_year", "description", "robustness", "License file check"),

  # ---- documentation ----
  # no R CMD check equivalent exists
  check_row("value_tags", "documentation", "opinion", "Value tags check"),
  # a convention, and a good one
  check_row(
    "missing_examples", "documentation", "opinion",
    "Missing examples check"
  ),
  # A forgotten document() unexports the function.
  check_row(
    "roxygen_usage", "documentation", "robustness",
    "Roxygen freshness check"
  ),
  check_row(
    "example_structure", "documentation", "opinion",
    "Example structure check"
  ),
  check_row(
    "commented_examples", "documentation", "opinion",
    "Commented-out examples check"
  ),
  check_row(
    "donttest_vs_dontrun", "documentation", "opinion",
    "donttest vs dontrun check"
  ),
  # The example will error when run.
  check_row(
    "unexported_example_ns", "documentation", "robustness",
    "Unexported example-namespace check"
  ),
  # WRE: Suggests must be used conditionally
  check_row(
    "suggested_in_examples", "documentation", "policy",
    "Suggested-package examples check"
  ),
  # R CMD check WARNs on a key it cannot find.
  check_row(
    "rd_bibliography", "documentation", "policy",
    "Rd bibliography check"
  ),
  # A .bib needs bibtex; only inst/ installs.
  check_row(
    "rd_bibliography_files", "documentation", "robustness",
    "Rd bibliography files check"
  ),
  # Rules CRAN sends packages back for, in the code outside R/.
  # CRAN asks for if(interactive()) over \dontrun{}.
  check_row(
    "example_interactive", "documentation", "policy",
    "Interactive example check"
  ),
  # No installing from an example or vignette.
  check_row(
    "example_installs", "documentation", "policy",
    "Example installs check"
  ),
  # No writing outside tempdir() from an example.
  check_row(
    "example_writes", "documentation", "policy",
    "Example writes check"
  ),
  # Restore options/par/wd changed in an example.
  check_row("example_state", "documentation", "policy", "Example state check"),
  # T/F can be rebound, as in R/
  check_row(
    "example_tf_usage", "documentation", "robustness",
    "Example T/F usage check"
  ),
  # Reviewers send "Unexecutable code", but WRE lets \dontrun{} hold non-R.
  check_row(
    "example_unparseable", "documentation", "robustness",
    "Example parse check"
  ),
  # ::: reaches an unexported object.
  check_row(
    "example_internal_ns", "documentation", "policy",
    "Example ::: check"
  ),

  # ---- general ----
  # CRAN's size limit
  check_row("package_size", "general", "policy", "Package size check"),
  # `urls` flags any http:// link. But CRAN's NOTE is for URLs that are INVALID or
  # that REDIRECT, which R determines by FETCHING them. checktor is offline and
  # cannot know whether a given http:// host even offers https. Plenty of packages
  # that ship http:// links are on CRAN today. "Prefer https" is good advice, not
  # a citable violation.
  check_row("urls", "general", "opinion", "URLs check"),
  # `url_liveness` fetches URLs and reports 404s/redirects, exactly as CRAN's
  # incoming check does -- a real, citable NOTE, so robustness not opinion. It runs
  # at the console and stays off in scripts, CI and R CMD check, where the network
  # would decide the result.
  check_row(
    "url_liveness", "general", "robustness",
    "URL liveness check",
    when = "console"
  ),
  check_row("news_file", "general", "opinion", "NEWS file check"),
  # A submission convention, not a CRAN requirement, and a submission workflow
  # rather than a package property, so it runs on request.
  check_row(
    "cran_comments_file", "general", "opinion",
    "cran-comments file check",
    when = "request"
  ),
  # a link that breaks in the built tarball
  check_row(
    "readme_links", "general", "robustness",
    "README relative-links check"
  ),
  # CRAN incoming WARNING: no examples, tests or vignettes
  check_row("code_exercised", "general", "policy", "Code exercised check"),
  # CRAN incoming NOTE; WRE: no packageDescription()
  check_row("citation_file", "general", "policy", "CITATION file check"),

  # ---- policy ----
  check_row("browser_calls", "policy", "policy", "Browser calls check"),
  # needs review, not a flat violation
  check_row("system_calls", "policy", "robustness", "System calls check"),
  # no writing to the user's filespace
  check_row("file_operations", "policy", "policy", "File operations check"),
  check_row(
    "network_operations", "policy", "policy",
    "Network operations check"
  )
)

# The description checks that read the parsed DESCRIPTION, with the label each
# one reports under. When R cannot read the file they are returned skipped under
# these labels, so they print as they would have.
DESCRIPTION_FIELD_CHECKS <- stats::setNames(
  BUILTIN_CHECKS$label[BUILTIN_CHECKS$reads_desc],
  BUILTIN_CHECKS$name[BUILTIN_CHECKS$reads_desc]
)

#' A built-in check's label
#'
#' The string a check reports as its result's `$message`, from the `label`
#' column of `BUILTIN_CHECKS`. A `lab_*()` check names itself with it rather than
#' repeating the literal at every return:
#' `pass_result(check_label("tf_usage"))`,
#' `report_check(issues, verbose, check_label("tf_usage"), ...)`,
#' `checktor_skipped_result(check_label("url_liveness"), reason)`.
#' A test holds every built-in check to returning its label.
#'
#' @param name Character. One or more built-in check names, without `lab_`.
#' @return Character, one label per name. An unknown name is an error, so a typo
#'   fails at once rather than printing `NA`.
#' @noRd
check_label <- function(name) {
  out <- BUILTIN_CHECKS$label[match(name, BUILTIN_CHECKS$name)]
  if (anyNA(out)) {
    stop("Unknown check: ", paste(name[is.na(out)], collapse = ", "))
  }
  out
}

# The built-in checks a category's run includes, in run order. A `request` check
# is left out: it runs only when called.
builtin_check_names <- function(category) {
  rows <- BUILTIN_CHECKS$category == category & BUILTIN_CHECKS$when != "request"
  BUILTIN_CHECKS$name[rows]
}

# Wrap a check function as the `function(p, v)` run_checks() calls, passing the
# shared parses in `cache` that its signature names and no others. So a check
# that takes `parsed` gets the category's parsed R sources, one that takes `desc`
# the parsed DESCRIPTION, and a plain (path, verbose) check neither.
forward_cache <- function(fn, cache) {
  extra <- cache[names(cache) %in% names(formals(fn))]
  function(p, v) do.call(fn, c(list(p, v), extra))
}

# The built-in checks of one category as run_checks()-ready closures, in run
# order. `...` is the category's shared parse cache (parsed = <xml> for code and
# policy, desc = <dcf> for description). Each lab_<name>() is looked up when the
# check runs, so a test can replace one with local_mocked_bindings().
builtin_checks_for <- function(category, ...) {
  cache <- list(...)
  nms <- builtin_check_names(category)
  out <- lapply(nms, function(nm) {
    force(nm)
    function(p, v) {
      fn <- get(paste0("lab_", nm), mode = "function")
      forward_cache(fn, cache)(p, v)
    }
  })
  stats::setNames(out, nms)
}

#' Run one category's panel
#'
#' The steps every `diagnose_<category>_issues()` orchestrator shares.
#' `begin_category()` resolves the package root, turns the run cache on for the
#' rest of the calling orchestrator (see R/cache.R) and prints the panel's
#' heading from `CATEGORY_TITLES`; it returns the resolved path.
#' `category_checks()` lists the category's built-in checks followed by its
#' registered ones, as closures `run_checks()` can call, and `run_category()`
#' runs them. `...` is the category's shared parse, forwarded to each check whose
#' signature asks for it (`parsed = <xml>` for code and policy, `desc = <dcf>`
#' for description). So an orchestrator reads
#'
#'     path <- begin_category("code", path, verbose)
#'     if (<nothing to check>) return(<early result>)
#'     run_category("code", path, verbose, parsed = read_r_xml(path))
#'
#' and one that has to replace some checks before they run, as description
#' does when DESCRIPTION cannot be read, edits `category_checks()`'s list and
#' passes it to `run_checks()` itself.
#'
#' @param category One of `CHECK_CATEGORIES`.
#' @param path,verbose As the orchestrator was given them; `path` already
#'   resolved for `category_checks()` and `run_category()`.
#' @param envir The frame whose exit empties the run cache.
#' @param ... The category's shared parse.
#' @noRd
begin_category <- function(category, path, verbose, envir = parent.frame()) {
  path <- find_package_root(path)
  local_run_cache(envir)
  if (verbose) {
    cli::cli_h2(CATEGORY_TITLES[[category]])
  }
  path
}

#' @rdname begin_category
#' @noRd
category_checks <- function(category, ...) {
  c(builtin_checks_for(category, ...), registered_checks_for(category, ...))
}

#' @rdname begin_category
#' @noRd
run_category <- function(category, path, verbose, ...) {
  run_checks(category_checks(category, ...), path, verbose)
}

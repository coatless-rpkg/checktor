# The built-in checks, listed once.
#
# Each row is one check: its name, the category that runs it, its severity tier
# (see R/severity.R for what the tiers mean) and when it runs. Everything that
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
# `skip_message` is set for the DESCRIPTION checks that read the parsed fields.
# When R cannot read the file each of them is reported skipped under that
# message, so it prints as the check itself would have.

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

check_table <- function(...) {
  rows <- list(...)
  column <- function(field) vapply(rows, `[[`, character(1), field)
  data.frame(
    name = column("name"),
    category = column("category"),
    severity = column("severity"),
    when = column("when"),
    skip_message = column("skip_message"),
    stringsAsFactors = FALSE
  )
}

check_row <- function(
  name,
  category,
  severity,
  when = "always",
  skip_message = NA_character_
) {
  list(
    name = name,
    category = category,
    severity = severity,
    when = when,
    skip_message = skip_message
  )
}

BUILTIN_CHECKS <- check_table(
  # ---- code ----
  check_row("tf_usage", "code", "robustness"), # T and F are variables and can be rebound
  check_row("seed_setting", "code", "policy"), # alters the user's RNG state
  check_row("print_cat_usage", "code", "policy"), # unsuppressable console output
  check_row("option_changes", "code", "policy"), # must restore the user's options
  check_row("home_writing", "code", "policy"), # no writing to the home filespace
  # CRAN's policy permits writing to the session temp directory; it is the one
  # place it EXPRESSLY allows. tempfile() lands inside tempdir(), and R removes
  # tempdir() at session end, so an un-unlinked tempfile() breaks no rule.
  check_row("temp_cleanup", "code", "opinion"), # tidiness, not policy
  check_row("globalenv_mod", "code", "policy"), # no modifying the global environment
  check_row("installed_packages", "code", "policy"), # a package may not install packages
  check_row("warn_option", "code", "policy"), # must restore options(warn=)
  check_row("software_install", "code", "policy"),
  check_row("core_usage", "code", "policy"), # "never use more than two simultaneously"
  check_row("library_in_pkg", "code", "robustness"), # attaching alters the user's search path
  # ?detectCores: "NA if the answer is unknown"
  check_row("detect_cores_robustness", "code", "robustness"),
  check_row("sys_setenv", "code", "policy"), # must restore environment variables
  check_row("internal_ns", "code", "robustness"), # ::: reaches an object its author may change
  # A leaked secret; no CRAN citation, but a real defect.
  check_row("hardcoded_credentials", "code", "robustness"),

  # ---- description ----
  # Whether R can read the file at all. R CMD build and INSTALL stop on a file R
  # cannot read. It re-reads the file rather than taking the parsed fields,
  # because the question is about the file, not about the fields.
  check_row("description_file", "description", "policy"),
  # CRAN incoming NOTE on unknown fields, Remotes
  check_row(
    "description_fields", "description", "policy",
    skip_message = "DESCRIPTION fields check"
  ),
  # CRAN incoming NOTE on template text
  check_row(
    "description_placeholders", "description", "policy",
    skip_message = "DESCRIPTION placeholders check"
  ),
  # WRE: single-quote other software
  check_row(
    "software_names", "description", "policy",
    skip_message = "Software names check"
  ),
  # WRE: single-quote programming languages (own kind of policy)
  check_row(
    "language_names", "description", "policy",
    skip_message = "Language names check"
  ),
  # JSON, HTML, SQL and the other formats are written bare by most packages CRAN
  # accepts, so a bare one breaks no rule it enforces (#16). A style choice CRAN
  # accepts either way, so it runs on request.
  check_row("format_names", "description", "opinion", when = "request"),
  # Reviewers ask; nothing enforces it.
  check_row(
    "acronyms", "description", "opinion",
    skip_message = "Acronyms check"
  ),
  # An invalid license is a rejection.
  check_row(
    "license", "description", "policy",
    skip_message = "License check"
  ),
  # Cookbook: R ships the GPL text itself.
  check_row(
    "license_file_unneeded", "description", "policy",
    skip_message = "License file pointer check"
  ),
  # CRAN incoming NOTE
  check_row(
    "title_case", "description", "policy",
    skip_message = "Title case check"
  ),
  # 65 chars is a convention
  check_row(
    "title_length", "description", "opinion",
    skip_message = "Title length check"
  ),
  # WRE: do not repeat the package name
  check_row(
    "title_package_name", "description", "policy",
    skip_message = "Title package-name check"
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
    when = "request"
  ),
  check_row(
    "title_redundant_phrases", "description", "opinion",
    skip_message = "Title redundant-phrases check"
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
    when = "request"
  ),
  # A placeholder Authors@R is a rejection.
  check_row(
    "authors", "description", "policy",
    skip_message = "Authors@R field check"
  ),
  # CRAN incoming NOTE on bad ORCID/ROR ids
  check_row(
    "identifier_format", "description", "policy",
    skip_message = "Author identifier check"
  ),
  # ?person says authors who are natural persons are copyright holders by default
  # and need no cph role, so a package written by people is not missing anything.
  # It runs on request.
  check_row("cph_role", "description", "opinion", when = "request"),
  # CRAN incoming NOTE on <doi:> form
  check_row(
    "references", "description", "policy",
    skip_message = "References check"
  ),
  # CRAN incoming NOTE on non-ISO/stale Date
  check_row(
    "date_format", "description", "policy",
    skip_message = "Date field check"
  ),
  # CRAN incoming NOTE on non-UTF-8 Encoding
  check_row(
    "encoding_utf8", "description", "policy",
    skip_message = "Encoding field check"
  ),
  # CRAN incoming NOTE on Version components
  check_row(
    "version_format", "description", "policy",
    skip_message = "Version field check"
  ),
  # aspell NOTE; noisy, and needs aspell or hunspell
  check_row(
    "spelling", "description", "opinion",
    when = "backend",
    skip_message = "Spelling check"
  ),
  check_row(
    "description_length", "description", "opinion",
    skip_message = "Description length check"
  ),
  # CRAN incoming NOTE
  check_row(
    "description_starts_with", "description", "policy",
    skip_message = "Description opening check"
  ),
  # WRE quoting rules
  check_row(
    "description_quoted_quotes", "description", "policy",
    skip_message = "Description double-quotes check"
  ),
  # An unfilled LICENSE template. It reads LICENSE alone, so it runs even when
  # DESCRIPTION cannot be read.
  check_row("license_year", "description", "robustness"),

  # ---- documentation ----
  check_row("value_tags", "documentation", "opinion"), # no R CMD check equivalent exists
  check_row("missing_examples", "documentation", "opinion"), # a convention, and a good one
  # A forgotten document() unexports the function.
  check_row("roxygen_usage", "documentation", "robustness"),
  check_row("example_structure", "documentation", "opinion"),
  check_row("commented_examples", "documentation", "opinion"),
  check_row("donttest_vs_dontrun", "documentation", "opinion"),
  # The example will error when run.
  check_row("unexported_example_ns", "documentation", "robustness"),
  # WRE: Suggests must be used conditionally
  check_row("suggested_in_examples", "documentation", "policy"),
  # R CMD check WARNs on a key it cannot find.
  check_row("rd_bibliography", "documentation", "policy"),
  # A .bib needs bibtex; only inst/ installs.
  check_row("rd_bibliography_files", "documentation", "robustness"),
  # Rules CRAN sends packages back for, in the code outside R/.
  # CRAN asks for if(interactive()) over \dontrun{}.
  check_row("example_interactive", "documentation", "policy"),
  # No installing from an example or vignette.
  check_row("example_installs", "documentation", "policy"),
  # No writing outside tempdir() from an example.
  check_row("example_writes", "documentation", "policy"),
  # Restore options/par/wd changed in an example.
  check_row("example_state", "documentation", "policy"),
  check_row("example_tf_usage", "documentation", "robustness"), # T/F can be rebound, as in R/
  # Reviewers send "Unexecutable code", but WRE lets \dontrun{} hold non-R.
  check_row("example_unparseable", "documentation", "robustness"),
  # ::: reaches an unexported object.
  check_row("example_internal_ns", "documentation", "policy"),

  # ---- general ----
  check_row("package_size", "general", "policy"), # CRAN's size limit
  # `urls` flags any http:// link. But CRAN's NOTE is for URLs that are INVALID or
  # that REDIRECT, which R determines by FETCHING them. checktor is offline and
  # cannot know whether a given http:// host even offers https. Plenty of packages
  # that ship http:// links are on CRAN today. "Prefer https" is good advice, not
  # a citable violation.
  check_row("urls", "general", "opinion"),
  # `url_liveness` fetches URLs and reports 404s/redirects, exactly as CRAN's
  # incoming check does -- a real, citable NOTE, so robustness not opinion. It runs
  # at the console and stays off in scripts, CI and R CMD check, where the network
  # would decide the result.
  check_row("url_liveness", "general", "robustness", when = "console"),
  check_row("news_file", "general", "opinion"),
  # A submission convention, not a CRAN requirement, and a submission workflow
  # rather than a package property, so it runs on request.
  check_row("cran_comments_file", "general", "opinion", when = "request"),
  check_row("readme_links", "general", "robustness"), # a link that breaks in the built tarball
  # CRAN incoming WARNING: no examples, tests or vignettes
  check_row("code_exercised", "general", "policy"),
  # CRAN incoming NOTE; WRE: no packageDescription()
  check_row("citation_file", "general", "policy"),

  # ---- policy ----
  check_row("browser_calls", "policy", "policy"),
  check_row("system_calls", "policy", "robustness"), # needs review, not a flat violation
  check_row("file_operations", "policy", "policy"), # no writing to the user's filespace
  check_row("network_operations", "policy", "policy")
)

# The description checks that read the parsed DESCRIPTION, with the message each
# one reports. When R cannot read the file they are returned skipped under these
# messages, so they print as they would have. A test holds them to the messages
# the checks themselves return.
DESCRIPTION_FIELD_CHECKS <- local({
  rows <- !is.na(BUILTIN_CHECKS$skip_message)
  stats::setNames(BUILTIN_CHECKS$skip_message[rows], BUILTIN_CHECKS$name[rows])
})

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

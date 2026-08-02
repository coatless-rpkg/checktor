# Severity tiers.
#
# Conflating these three is what made checktor's output hard to act on: a citable
# CRAN rejection and a matter of taste were printed the same way, so a run with
# 49 findings told you nothing about whether you could submit.
#
#   policy      - a citable CRAN Repository Policy / Writing R Extensions
#                 violation, or something `R CMD check --as-cran` NOTEs. Fix it
#                 or expect to be asked to.
#   robustness  - a real defect, but not a policy breach. `detectCores()` may
#                 return NA and crash the user's session; CRAN will not stop you
#                 shipping it.
#   opinion     - a convention with no authority behind it. Worth knowing, not
#                 worth blocking on. Reasonable maintainers disagree.
#
# A check's tier is where its AUTHORITY sits, not how annoying it is. Where no
# citation exists, the honest answer is `opinion`, even for a check we like.

SEVERITY_LEVELS <- c("policy", "robustness", "opinion")

# The default `checktor()` run. A clean result therefore means "nothing here will
# get you rejected, and nothing here will crash a user" -- which is the question
# people actually have before a submission.
DEFAULT_SEVERITY <- c("policy", "robustness")

CHECK_SEVERITY <- c(
  # ---- code ----
  tf_usage = "robustness", # T and F are variables and can be rebound
  seed_setting = "policy", # alters the user's RNG state
  print_cat_usage = "policy", # unsuppressable console output
  option_changes = "policy", # must restore the user's options
  home_writing = "policy", # no writing to the home filespace
  # CRAN's policy permits writing to the session temp directory; it is the one
  # place it EXPRESSLY allows. tempfile() lands inside tempdir(), and R removes
  # tempdir() at session end, so an un-unlinked tempfile() breaks no rule.
  temp_cleanup = "opinion", # tidiness, not policy
  globalenv_mod = "policy", # no modifying the global environment
  installed_packages = "policy", # a package may not install packages
  warn_option = "policy", # must restore options(warn=)
  software_install = "policy",
  core_usage = "policy", # "never use more than two simultaneously"
  library_in_pkg = "robustness", # attaching alters the user's search path
  detect_cores_robustness = "robustness", # ?detectCores: "NA if the answer is unknown"
  sys_setenv = "policy", # must restore environment variables
  hardcoded_credentials = "robustness", # a leaked secret; no CRAN citation, real defect
  internal_ns = "robustness", # ::: reaches an object its author may change

  # ---- description ----
  software_names = "policy", # WRE: single-quote other software
  language_names = "policy", # WRE: single-quote languages/markup (own kind of policy)
  acronyms = "opinion", # reviewers ask; nothing enforces it
  identifier_format = "policy", # CRAN incoming NOTE on bad ORCID/ROR ids
  date_format = "policy", # CRAN incoming NOTE on non-ISO/stale Date
  encoding_utf8 = "policy", # CRAN incoming NOTE on non-UTF-8 Encoding
  version_format = "policy", # CRAN incoming NOTE on Version components
  spelling = "opinion", # aspell NOTE; needs a backend, noisy
  license = "policy", # an invalid license is a rejection
  title_case = "policy", # CRAN incoming NOTE
  title_length = "opinion", # 65 chars is a convention
  title_starts_with_article = "opinion", # fabricated rule; not in a run
  title_redundant_phrases = "opinion",
  description_function_quotes = "opinion", # invented rule; not in a run
  authors = "policy", # a placeholder Authors@R is a rejection
  cph_role = "opinion",
  references = "policy", # CRAN incoming NOTE on <doi:> form
  description_length = "opinion",
  description_starts_with = "policy", # CRAN incoming NOTE
  description_quoted_quotes = "policy", # WRE quoting rules
  license_year = "robustness", # an unfilled LICENSE template

  # ---- documentation ----
  value_tags = "opinion", # no R CMD check equivalent exists
  missing_examples = "opinion", # a convention, and a good one
  roxygen_usage = "robustness", # a forgotten document() unexports the function
  example_structure = "opinion",
  commented_examples = "opinion",
  donttest_vs_dontrun = "opinion",
  unexported_example_ns = "robustness", # the example will error when run
  suggested_in_examples = "policy", # WRE: Suggests must be used conditionally
  # Rules CRAN sends packages back for, in the code outside R/.
  example_interactive = "policy", # asks for if(interactive()) over \dontrun{}
  example_installs = "policy", # no installing from an example or vignette
  example_writes = "policy", # no writing outside tempdir() from an example
  example_state = "policy", # restore options/par/wd changed in an example
  example_internal_ns = "policy", # ::: reaches an unexported object

  # ---- general ----
  package_size = "policy", # CRAN's size limit
  # `urls` flags any http:// link. But CRAN's NOTE is for URLs that are INVALID or
  # that REDIRECT, which R determines by FETCHING them. checktor is offline and
  # cannot know whether a given http:// host even offers https. Plenty of packages
  # that ship http:// links are on CRAN today. "Prefer https" is good advice, not
  # a citable violation.
  urls = "opinion",
  # `url_liveness` fetches URLs and reports 404s/redirects, exactly as CRAN's
  # incoming check does -- a real, citable NOTE, so robustness not opinion. It runs
  # at the console and stays off in scripts, CI and R CMD check, where the network
  # would decide the result.
  url_liveness = "robustness",
  news_file = "opinion",
  cran_comments_file = "opinion", # a submission convention, not a CRAN requirement
  readme_links = "robustness", # a link that breaks in the built tarball

  # ---- policy ----
  browser_calls = "policy",
  system_calls = "robustness", # needs review, not a flat violation
  file_operations = "policy", # no writing to the user's filespace
  network_operations = "policy"
)

# WHEN each check runs. The tier says how much a finding counts; this says whether
# the check happens at all, which used to be spread across three unrelated
# mechanisms and was invisible in the results.
#
#   always   runs in every checktor() run
#   console  runs when a person is at the console, since it needs a network
#   backend  runs when the external tool it needs is installed
#   request  runs only when you call it, because no authority supports it or it is
#            a workflow convention rather than a package property
#
# A check that does not run is reported as skipped rather than passed, so a clean
# bill of health never includes a check that never happened. `test-registry.R`
# holds this table to what actually runs.
CHECK_WHEN_DEFAULT <- "always"
CHECK_WHEN <- c(
  url_liveness = "console", # needs a network
  spelling = "backend", # needs aspell or hunspell
  cran_comments_file = "request", # a submission workflow, not a package property
  title_starts_with_article = "request", # no authority supports it
  description_function_quotes = "request" # no authority supports it
)

# Every check name checktor knows about, built in or registered at run time. Used
# wherever a name has to be recognised rather than reported as a typo.
all_check_names <- function() {
  unique(c(names(CHECK_SEVERITY), ls(.checktor_registry, all.names = TRUE)))
}

# Checks that exist but never join a run, because no authority backs them or they
# ask about a submission workflow rather than the package. They are not skipped --
# nothing tried to run them -- and being opinion tier they could not change a
# verdict anyway. Naming them is purely so you can find out they are there.
on_request_checks <- function() {
  sort(names(CHECK_WHEN)[CHECK_WHEN == "request"])
}

# When a check runs. Anything without an entry runs always, so a new check is
# active by default rather than silently absent.
check_when <- function(name) {
  out <- unname(CHECK_WHEN[name])
  out[is.na(out)] <- CHECK_WHEN_DEFAULT
  out
}

# The result a check returns when it did not run. `passed` stays TRUE so a skipped
# check never fails a verdict, and `skipped` records that nothing was actually
# examined, which is what `tidy()` and the printed summary report.
checktor_skipped_result <- function(message, reason) {
  checktor_check_result(
    TRUE,
    character(0),
    message,
    skipped = TRUE,
    skip_reason = reason
  )
}

# The tier a check sits in. A registered check (see register_check()) carries its
# own tier, consulted when the name is not a built-in. Anything still unknown is
# treated as `robustness`: a new check with no entry is a real finding until
# someone says otherwise, which fails safe rather than silently hiding it.
check_severity <- function(name) {
  out <- unname(CHECK_SEVERITY[name])
  unknown <- is.na(out)
  if (any(unknown)) {
    reg <- registered_severity(name[unknown])
    out[unknown] <- reg
  }
  out[is.na(out)] <- "robustness"
  out
}

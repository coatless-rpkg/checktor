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
  description_bare_r = "opinion", # see below: not in the default run
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

  # ---- general ----
  package_size = "policy", # CRAN's size limit
  # `urls` flags any http:// link. But CRAN's NOTE is for URLs that are INVALID or
  # that REDIRECT, which R determines by FETCHING them. checktor is offline and
  # cannot know whether a given http:// host even offers https. Plenty of packages
  # that ship http:// links are on CRAN today. "Prefer https" is good advice, not
  # a citable violation.
  urls = "opinion",
  # `url_liveness` fetches URLs and reports 404s/redirects, exactly as CRAN's
  # incoming check does -- a real, citable NOTE, so robustness not opinion. It is
  # opt-in (needs a network) and off by default, so it never colours a default run.
  url_liveness = "robustness",
  news_file = "opinion",
  readme_links = "robustness", # a link that breaks in the built tarball

  # ---- policy ----
  browser_calls = "policy",
  system_calls = "robustness", # needs review, not a flat violation
  file_operations = "policy", # no writing to the user's filespace
  network_operations = "policy"
)

# Checks excluded from the default run because no authority supports them in
# EITHER direction. They stay callable, and stay in `CHECK_SEVERITY`, so anyone
# who wants them can ask for them.
#
# `description_bare_r` demanded that every bare `R` in Description be
# single-quoted. Writing R Extensions reserves single quotes for OTHER software,
# and R is the host language, not a dependency: of the packages installed here,
# 115 write R bare and 25 quote it. The rule was inventing a requirement, and
# checktor's own DESCRIPTION quoted 'R' solely because its own check said so.
EXCLUDED_BY_DEFAULT <- c(
  "description_bare_r",
  "title_starts_with_article",
  "description_function_quotes"
)

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

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

# Each built-in check's tier, from the check table in R/registry.R.
CHECK_SEVERITY <- stats::setNames(BUILTIN_CHECKS$severity, BUILTIN_CHECKS$name)

# WHEN each check runs. The tier says how much a finding counts; this says whether
# the check happens at all, which used to be spread across three unrelated
# mechanisms and was invisible in the results. R/registry.R describes the values.
# Only the checks that do not always run are listed.
#
# A check that does not run is reported as skipped rather than passed, so a clean
# bill of health never includes a check that never happened. `test-severity.R`
# holds this table to what actually runs.
CHECK_WHEN_DEFAULT <- "always"
CHECK_WHEN <- local({
  sometimes <- BUILTIN_CHECKS$when != CHECK_WHEN_DEFAULT
  stats::setNames(BUILTIN_CHECKS$when[sometimes], BUILTIN_CHECKS$name[sometimes])
})

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

# A check's outcome: "failed", "skipped" when it did not run, or "passed". A
# skipped check keeps `passed = TRUE` so it never fails a verdict, which is why
# anything that counts or shows passes asks this instead of reading `$passed`. A
# failure wins over a skip, as it does in the verdict, so a registered check that
# sets both still reads as failing.
check_status <- function(x) {
  if (!isTRUE(x$passed)) {
    "failed"
  } else if (isTRUE(x$skipped)) {
    "skipped"
  } else {
    "passed"
  }
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

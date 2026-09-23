# Result and report helpers shared by several test files.

# setup.R pins the spelling backend and the URL fetcher off, so exactly these two
# checks do not run in the suite. The skipped tests assert the note verbatim, so
# adding another `console`/`backend` check means updating this vector too.
CI_SKIPPED <- c("spelling", "url_liveness")

# Masks the leading marker of a CI annotation for a snapshot. testthat prints a
# snapshot diff on failure, that diff reaches the runner's log, and an unmasked
# line would be read there as a real annotation against this repository.
mask_ci_markers <- function(lines) sub("^(::|##vso)", "~\\1", lines)

# small synthetic category result for precise unit tests
.mk_check <- function(passed, issues) {
  checktor_check_result(passed, issues, "m")
}

.mk_cat <- function(checks) {
  cat <- checks
  cat$passed <- vapply(checks, function(c) isTRUE(c$passed), logical(1))
  class(cat) <- "checktor_category_result"
  cat
}

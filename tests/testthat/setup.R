# lab_spelling() calls utils::aspell(), whose result depends on whether a
# spell-check backend is installed, and lab_url_liveness() fetches every URL over
# the network. Either would make the count- and severity-based tests differ from
# machine to machine, so the suite runs with both off. The dedicated tests opt
# back in.
#
# The other checktor.* options a developer might set in .Rprofile are cleared, so
# a personal checktor.disable or checktor.severity cannot change what the suite
# sees. Everything here is undone when the run ends, so a devtools::test() leaves
# the session's own settings as they were.
withr::local_options(
  checktor.spelling = FALSE,
  checktor.url_check = FALSE,
  checktor.disable = NULL,
  checktor.severity = NULL,
  checktor.verbose = NULL,
  checktor.progress = NULL,
  .local_envir = testthat::teardown_env()
)

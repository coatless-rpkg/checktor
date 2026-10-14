## Submission notes

This is an update of `checktor` from 0.1.0 to 0.2.0.

* The individual checks are renamed from `diagnose_*()` to `lab_*()`, so each
  function's name matches the check it reports. They were renamed outright,
  since the package has no reverse dependencies, and NEWS.md lists every one
  under "Breaking changes".
* The minimum R version rises from 3.5.0 to 4.5.0, the release that added
  `tools::check_package_urls()`.

## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

* local macOS (aarch64), R 4.6.1
* GitHub Actions: macOS, Windows and Ubuntu on R release, and Ubuntu on R devel
  and R oldrel-1
* win-builder, R devel

## Reverse dependencies

There are none.

## Submission notes

This is an update to `checktor`, taking version 0.1.0 to 0.2.0.

The release renames the individual check functions from `diagnose_*()` to
`lab_*()`, so that a function name matches the check name reported in the
results. Eight names released in 0.1.0 are affected. They were renamed rather
than deprecated because the package has no reverse dependencies and has been on
CRAN only briefly. The five category functions, such as
`diagnose_code_issues()`, keep their names, and NEWS.md lists every renamed
function under Breaking changes.

The minimum R version rises from 3.5.0 to 4.5.0, which is the release that added
`tools::check_package_urls()`, the function behind the new URL check.

## Test environments

* local macOS, R 4.6.0 — `R CMD check`: 0 errors, 0 warnings, 0 notes
* GitHub Actions: macOS-latest, windows-latest, ubuntu-latest (R release,
  R devel, R oldrel-1) via the standard `r-lib/actions` workflow
* win-builder (devel) — pending

## Method references

There are no published references describing the methods in this package.
`checktor` consolidates ad-hoc CRAN submission guidance that is otherwise
spread across the CRAN Repository Policy, the R Packages book, and CRAN
reviewer feedback threads.

## Reverse dependencies

There are no reverse dependencies to check.

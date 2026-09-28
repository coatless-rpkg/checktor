# Diagnose Package for CRAN Submission Issues

Runs a comprehensive diagnostic suite for common CRAN submission issues
that are not caught by standard R CMD check. Like a doctor for your
package, this function examines your code, DESCRIPTION file,
documentation, general package structure, and CRAN policy compliance to
identify potential problems that could cause CRAN submission delays or
rejections.

## Usage

``` r
checktor(
  path = ".",
  verbose = getOption("checktor.verbose", TRUE),
  progress = getOption("checktor.progress", verbose),
  severity = getOption("checktor.severity", c("policy", "robustness"))
)
```

## Arguments

- path:

  Character. Any directory inside the R package, or a file within one.
  Defaults to the working directory (`"."`). checktor walks up to find
  the `DESCRIPTION`, so running it from `R/` or `tests/testthat/`
  examines the whole package rather than failing. See
  [`find_package_root()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/find_package_root.md).

- verbose:

  Logical. Whether to print detailed diagnostic output to console.
  Defaults to `getOption("checktor.verbose", TRUE)`.

- progress:

  Logical. Whether to show progress bars during diagnostics. Defaults to
  `getOption("checktor.progress", verbose)`.

- severity:

  Character. Which severity tiers count toward the verdict: any of
  `"policy"`, `"robustness"`, `"opinion"`. Defaults to
  `getOption("checktor.severity", c("policy", "robustness"))`.

  Every check still runs, and every finding stays in the result and
  appears in
  [`issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/issues.md)
  with its tier. What this argument decides is which findings count
  against a clean bill of health. `"policy"` is a citable CRAN
  Repository Policy or Writing R Extensions violation. `"robustness"` is
  a real defect that CRAN will still accept, such as a `detectCores()`
  that may return `NA`. `"opinion"` is a convention with no authority
  behind it.

  The default therefore makes "0 issues" mean *nothing here will get you
  rejected, and nothing here will crash a user*. Pass all three tiers to
  hold yourself to the conventions as well.

## Value

A `checktor_results` object (list) containing:

- `code_issues`: Results from code diagnostics

- `description_issues`: Results from DESCRIPTION file diagnostics

- `documentation_issues`: Results from documentation diagnostics

- `general_issues`: Results from general package diagnostics

- `policy_issues`: Results from CRAN policy violation diagnostics

- `metadata`: List with the package path, the diagnosis time, the issue
  and failed-check counts (`total_issues`, `failed_checks`), the
  `severity` tiers they count, the findings outside those tiers
  (`advisory_issues`), the findings muted by `Config/checktor/allow`
  (`suppressed`), the checks that did not run (`skipped_checks`), the
  checks that run only when called (`on_request_checks`), and the
  checktor version (`checktor_version`)

Each diagnostic category contains a `passed` element showing which
individual checks did not fail, plus detailed results for each check. A
check that did not run is `TRUE` there, and its own `skipped` element
records that it did not run.

## Details

The function runs five categories of diagnostics: **Code**,
**DESCRIPTION**, **Documentation**, **General**, and **Policy**. See
[`diagnose_code_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_code_issues.md),
[`diagnose_description_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_description_issues.md),
[`diagnose_documentation_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_documentation_issues.md),
[`diagnose_general_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_general_issues.md),
and
[`diagnose_policy_violations()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_policy_violations.md)
for the specific checks within each category.

The `metadata$total_issues` figure counts the individual findings of the
checks in the `severity` tiers (e.g., 80 lines using `T`/`F` count as
80, not 1), and `metadata$failed_checks` counts how many of those checks
reported anything. Findings in the other tiers are still in the result
and are counted in `metadata$advisory_issues` instead.

A few checks never join a run, because no authority backs them or they
ask about a submission workflow rather than the package. They are not
skipped, since nothing tried to run them. `metadata$on_request_checks`
names them; call `lab_<name>()` to run one.

A package can configure checktor from `Config/checktor/*` fields in its
own `DESCRIPTION` (comma-separated lists; `DESCRIPTION` has no comment
syntax, so anything after the last name becomes part of it):

- `Config/checktor/disable`: check names to skip entirely. A disabled
  check does not run and is not counted anywhere in the results. To turn
  a check off in every package, set
  `options(checktor.disable = "news_file")` once, for example in
  `.Rprofile`; the two lists are combined.

- `Config/checktor/allow`: `check` to mute a whole check, or
  `check:substring` to mute only findings whose text contains
  `substring`. The check still runs; muted findings are dropped from the
  results and tallied in `metadata$suppressed`, while a `disable`d check
  is removed entirely and never counted there.

- `Config/checktor/software_names`, `Config/checktor/language_names`,
  `Config/checktor/format_names`, `Config/checktor/acronyms`: names
  appended to those checks' vocabularies.

## Options

- `checktor.verbose`, `checktor.progress`: the defaults for `verbose`
  and `progress`.
  [`configure_doctor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/configure_doctor.md)
  sets both.

- `checktor.severity`: the default tiers for `checktor()` and
  [`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md).

- `checktor.disable`: checks to leave out of every run, combined with
  `Config/checktor/disable`.

- `checktor.url_check`: `TRUE` or `FALSE` to run or skip
  [`lab_url_liveness()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_url_liveness.md)
  wherever you are. It defaults to
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

- `checktor.spelling`: `FALSE` turns off
  [`lab_spelling()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_spelling.md),
  which is then reported as skipped.

## See also

[`health_report()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/health_report.md)
to generate detailed reports,
[`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)
for treatment recommendations,
[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
for quick health checks

## Examples

``` r
# Run against a synthetic package with known T/F issues
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)

results              # the diagnosis summary
#> ── Package Doctor - Diagnosis Summary ──────────────────────────────────────────
#> Patient: examplepackage
#> Examined: 2026-09-28 22:25:22.665326
#> Doctor version: 0.2.0
#> 
#> CODE ISSUES: 1 failing check
#> DESCRIPTION ISSUES: HEALTHY
#> DOCUMENTATION ISSUES: HEALTHY
#> GENERAL ISSUES: HEALTHY
#> POLICY ISSUES: HEALTHY
#> 
#> ℹ 2 checks did not run: "spelling" and "url_liveness".
#> ! Overall health: NEEDS ATTENTION (7 issues)
#> Run `summary()`, `issues()`, or `prescribe()` for details
summary(results)     # per-category overview
#>        category checks passed failed skipped issues
#> 1          code     16     15      1       0      7
#> 2   description     23     22      0       1      0
#> 3 documentation     17     17      0       0      0
#> 4       general      7      6      0       1      0
#> 5        policy      4      4      0       0      0
issues(results)      # every issue as a tidy data frame
#>   category    check   severity           file line          location
#> 1     code tf_usage robustness tf_usage_bad.R    8  tf_usage_bad.R:8
#> 2     code tf_usage robustness tf_usage_bad.R   11 tf_usage_bad.R:11
#> 3     code tf_usage robustness tf_usage_bad.R   15 tf_usage_bad.R:15
#> 4     code tf_usage robustness tf_usage_bad.R   18 tf_usage_bad.R:18
#> 5     code tf_usage robustness tf_usage_bad.R   22 tf_usage_bad.R:22
#> 6     code tf_usage robustness tf_usage_bad.R   25 tf_usage_bad.R:25
#> 7     code tf_usage robustness tf_usage_bad.R   29 tf_usage_bad.R:29
#>           message
#> 1 T/F usage check
#> 2 T/F usage check
#> 3 T/F usage check
#> 4 T/F usage check
#> 5 T/F usage check
#> 6 T/F usage check
#> 7 T/F usage check
is_healthy(results)  # FALSE
#> [1] FALSE
```

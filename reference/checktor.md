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
  severity = getOption("checktor.severity", DEFAULT_SEVERITY)
)
```

## Arguments

- path:

  Character. Path to the R package directory. Defaults to current
  directory (`"."`).

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
  a real defect that CRAN will nonetheless let you ship, such as a
  `detectCores()` that may return `NA`. `"opinion"` is a convention with
  no authority behind it.

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

- `metadata`: List with package path, diagnosis time, total issue count,
  total failed-check count, and checktor version

Each diagnostic category contains a `passed` element showing which
individual checks passed/failed, plus detailed results for each check.

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

The `metadata$total_issues` figure counts the total number of distinct
issues found across all checks (e.g., 80 lines using `T`/`F` count as
80, not 1). The `metadata$failed_checks` figure counts how many
individual checks reported any issue at all.

A package can configure checktor from `Config/checktor/*` fields in its
own `DESCRIPTION` (comma-separated lists):

- `Config/checktor/disable`: check names to skip entirely. A disabled
  check does not run and is not counted anywhere in the results.

- `Config/checktor/allow`: `check` to mute a whole check, or
  `check:substring` to mute only findings whose text contains
  `substring`. The check still runs; muted findings are dropped from the
  results and tallied in `metadata$suppressed`, while a `disable`d check
  is removed entirely and never counted there.

- `Config/checktor/software_names`, `Config/checktor/acronyms`: names
  appended to those checks' vocabularies.

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
#> Examined: 2026-07-17 04:26:09.664731
#> Doctor version: 0.2.0
#> 
#> CODE ISSUES: 1 failing check
#> DESCRIPTION ISSUES: 1 failing check
#> DOCUMENTATION ISSUES: HEALTHY
#> GENERAL ISSUES: HEALTHY
#> POLICY ISSUES: HEALTHY
#> 
#> ! Overall health: NEEDS ATTENTION (7 issues)
#> Run `summary()`, `issues()`, or `prescribe()` for details
summary(results)     # per-category overview
#>        category checks passed failed issues
#> 1          code     15     14      1      7
#> 2   description     18     17      1      1
#> 3 documentation      8      8      0      0
#> 4       general      4      4      0      0
#> 5        policy      4      4      0      0
issues(results)      # every issue as a tidy data frame
#>      category    check   severity           file line
#> 1        code tf_usage robustness tf_usage_bad.R    8
#> 2        code tf_usage robustness tf_usage_bad.R   11
#> 3        code tf_usage robustness tf_usage_bad.R   15
#> 4        code tf_usage robustness tf_usage_bad.R   18
#> 5        code tf_usage robustness tf_usage_bad.R   22
#> 6        code tf_usage robustness tf_usage_bad.R   25
#> 7        code tf_usage robustness tf_usage_bad.R   29
#> 8 description cph_role    opinion           <NA>   NA
#>                                            location         message
#> 1                                  tf_usage_bad.R:8 T/F usage check
#> 2                                 tf_usage_bad.R:11 T/F usage check
#> 3                                 tf_usage_bad.R:15 T/F usage check
#> 4                                 tf_usage_bad.R:18 T/F usage check
#> 5                                 tf_usage_bad.R:22 T/F usage check
#> 6                                 tf_usage_bad.R:25 T/F usage check
#> 7                                 tf_usage_bad.R:29 T/F usage check
#> 8 Authors@R lacks any [cph] (copyright holder) role  cph role check
is_healthy(results)  # FALSE
#> [1] FALSE
```

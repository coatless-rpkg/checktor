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
  progress = getOption("checktor.progress", verbose)
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
#> Examined: 2026-06-26 04:15:06.5369
#> Doctor version: 0.1.0
#> 
#> CODE ISSUES: 1 failing check
#> DESCRIPTION ISSUES: 3 failing checks
#> DOCUMENTATION ISSUES: HEALTHY
#> GENERAL ISSUES: HEALTHY
#> POLICY ISSUES: HEALTHY
#> 
#> ! Overall health: NEEDS ATTENTION (10 issues)
#> Run `summary()`, `issues()`, or `prescribe()` for details
summary(results)     # per-category overview
#>        category checks passed failed issues
#> 1          code     13     12      1      7
#> 2   description     14     11      3      3
#> 3 documentation      6      6      0      0
#> 4       general      2      2      0      0
#> 5        policy      4      4      0      0
issues(results)      # every issue as a tidy data frame
#>       category              check           file line
#> 1         code           tf_usage tf_usage_bad.R    8
#> 2         code           tf_usage tf_usage_bad.R   11
#> 3         code           tf_usage tf_usage_bad.R   15
#> 4         code           tf_usage tf_usage_bad.R   18
#> 5         code           tf_usage tf_usage_bad.R   22
#> 6         code           tf_usage tf_usage_bad.R   23
#> 7         code           tf_usage tf_usage_bad.R   26
#> 8  description            license           <NA>   NA
#> 9  description           cph_role           <NA>   NA
#> 10 description description_length           <NA>   NA
#>                                                           location
#> 1                                                 tf_usage_bad.R:8
#> 2                                                tf_usage_bad.R:11
#> 3                                                tf_usage_bad.R:15
#> 4                                                tf_usage_bad.R:18
#> 5                                                tf_usage_bad.R:22
#> 6                                                tf_usage_bad.R:23
#> 7                                                tf_usage_bad.R:26
#> 8  MIT/BSD license requires '+ file LICENSE' for copyright holders
#> 9                Authors@R lacks any [cph] (copyright holder) role
#> 10                    Description too short: 1 sentences, 18 words
#>                     message
#> 1           T/F usage check
#> 2           T/F usage check
#> 3           T/F usage check
#> 4           T/F usage check
#> 5           T/F usage check
#> 6           T/F usage check
#> 7           T/F usage check
#> 8             License check
#> 9            cph role check
#> 10 Description length check
is_healthy(results)  # FALSE
#> [1] FALSE
```

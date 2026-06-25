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

# Inspect the metadata
results$metadata$total_issues
#> [1] 10
results$metadata$failed_checks
#> [1] 4

# Check whether a specific diagnostic passed
results$code_issues$tf_usage$passed
#> [1] FALSE
```

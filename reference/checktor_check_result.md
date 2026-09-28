# Create a Standard Diagnostic Check Result Object

Constructor function for creating consistent diagnostic check result
objects used by all individual diagnostic functions.

## Usage

``` r
checktor_check_result(passed, issues, message, ...)
```

## Arguments

- passed:

  Logical. TRUE if the check passed, FALSE if issues were found.

- issues:

  Character vector. Specific issues found, typically in "file:line"
  format.

- message:

  Character. Description of what was checked.

- ...:

  Additional named elements specific to the particular check. Two are
  read by checktor itself: `skipped = TRUE` marks a check that could not
  run, and `skip_reason` says why. See Details.

## Value

An object of class `checktor_check_result` containing:

- `passed`: The passed status

- `issues`: Vector of issues found

- `message`: Description of the check

- Additional elements passed via `...`

## Details

A check that could not run where it is, because it needs a network, a
tool or a file that is not there, should say so rather than pass. Return
`checktor_check_result(TRUE, character(0), "<message>", skipped = TRUE, skip_reason = "<why>")`.
`passed` stays `TRUE` so the skip cannot fail a verdict, and `skipped`
makes
[tidy()](https://r-pkg.thecoatlessprofessor.com/checktor/reference/tidy.md),
[summary()](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor-summary.md),
`metadata$skipped_checks`, the printed report,
[`health_report()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/health_report.md)
and
[`ci_report()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/ci_report.md)
report it as a check that did not run rather than one that passed. A
result with `passed = FALSE` reads as failed whatever `skipped` says.

## See also

Individual diagnostic functions like
[`lab_tf_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_tf_usage.md),
[`lab_seed_setting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_seed_setting.md)

## Examples

``` r
# Create a passing check result
result <- checktor_check_result(
  passed = TRUE,
  issues = character(0),
  message = "Example check"
)
print(result)
#> ✔ Example check: PASSED

# Create a failing check result with additional elements
result <- checktor_check_result(
  passed = FALSE,
  issues = c("file1.R:5", "file2.R:10"),
  message = "T/F usage check",
  file_issues = list("file1.R" = 5, "file2.R" = 10)
)
print(result)
#> ✖ T/F usage check: FAILED
#> Issues found:
#> • file1.R:5
#> • file2.R:10

# Report a check that could not run where it is
result <- checktor_check_result(
  passed = TRUE,
  issues = character(0),
  message = "License server check",
  skipped = TRUE,
  skip_reason = "no license server configured"
)
print(result)
#> ℹ License server check: SKIPPED (no license server configured)
```

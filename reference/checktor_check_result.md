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

  Additional named elements specific to the particular check.

## Value

An object of class `checktor_check_result` containing:

- `passed`: The passed status

- `issues`: Vector of issues found

- `message`: Description of the check

- Additional elements passed via `...`

## See also

Individual diagnostic functions like
[`diagnose_tf_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_tf_usage.md),
[`diagnose_seed_setting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_seed_setting.md)

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
```

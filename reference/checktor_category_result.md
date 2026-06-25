# Create a Multi-Category Diagnostic Result Object

Constructor function for creating diagnostic category result objects
used by multi-category diagnostic functions like
[`diagnose_code_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_code_issues.md).

## Usage

``` r
checktor_category_result(...)
```

## Arguments

- ...:

  Named arguments where each is a
  [checktor_check_result](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
  object representing individual checks within the category.

## Value

An object of class `checktor_category_result` containing:

- Individual
  [checktor_check_result](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
  objects for each check

- `passed`: Named logical vector showing which individual checks passed

## See also

Multi-category functions like
[`diagnose_code_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_code_issues.md),
[`diagnose_documentation_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_documentation_issues.md)

## Examples

``` r
# Create individual check results
tf_check <- checktor_check_result(FALSE, "file.R:5", "T/F usage check")
seed_check <- checktor_check_result(TRUE, character(0), "Seed setting check")

# Create category result
code_results <- checktor_category_result(
  tf_usage = tf_check,
  seed_setting = seed_check
)
print(code_results)
#> ── Diagnostic Category Results ─────────────────────────────────────────────────
#> ! 1 of 2 checks failed
#> Failed checks:
#> tf_usage: 1 issue
```

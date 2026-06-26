# Status predicates for checktor results

Status predicates for checktor results

## Usage

``` r
passed(x, ...)

# S3 method for class 'checktor_check_result'
passed(x, ...)

# S3 method for class 'checktor_category_result'
passed(x, ...)

# S3 method for class 'checktor_results'
passed(x, ...)

is_healthy(x, ...)

# S3 method for class 'checktor_check_result'
is_healthy(x, ...)

# S3 method for class 'checktor_category_result'
is_healthy(x, ...)

# S3 method for class 'checktor_results'
is_healthy(x, ...)

n_issues(x, ...)

# S3 method for class 'checktor_check_result'
n_issues(x, ...)

# S3 method for class 'checktor_category_result'
n_issues(x, ...)

# S3 method for class 'checktor_results'
n_issues(x, ...)

n_failed_checks(x, ...)

# S3 method for class 'checktor_category_result'
n_failed_checks(x, ...)

# S3 method for class 'checktor_results'
n_failed_checks(x, ...)

failed_checks(x, ...)

# S3 method for class 'checktor_category_result'
failed_checks(x, ...)

# S3 method for class 'checktor_results'
failed_checks(x, ...)
```

## Arguments

- x:

  A `checktor_results`, `checktor_category_result`, or
  `checktor_check_result` object.

- ...:

  Unused.

## Value

`passed()`: logical — a single value for a check, a named logical by
check for a category, and a named logical by category for results.
`is_healthy()`: a single logical. `n_issues()` / `n_failed_checks()`:
integer counts. `failed_checks()`: character vector of failing check
names (qualified `"category.check"` at the results level).

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
is_healthy(results)
#> [1] FALSE
failed_checks(results)
#> [1] "code.tf_usage"                  "description.license"           
#> [3] "description.cph_role"           "description.description_length"
```

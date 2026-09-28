# Status predicates for checktor results

These ask the question a verdict asks: did a check fail? `passed()`
means "did not fail", so a check that did not run, such as
`url_liveness` away from the console, is `TRUE` there. A skipped check
cannot fail a verdict, and `is_healthy()`, `failed_checks()` and
`n_failed_checks()` treat it the same way.

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

`passed()`: logical, `TRUE` for a check that did not fail, a skipped one
included. It is a single value for a check, a named logical by check for
a category, and a named logical by category for results. `is_healthy()`:
a single logical. `n_issues()` / `n_failed_checks()`: integer counts.
`failed_checks()`: character vector of failing check names (qualified
`"category.check"` at the results level).

On a `checktor_results`, `is_healthy()`, `n_issues()` and
`n_failed_checks()` count only the tiers named in
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)'s
`severity` (they read `metadata$total_issues` and
`metadata$failed_checks`), so they agree with
[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md).
`failed_checks()`, and every predicate on a category or a check, count
every tier, so an `opinion` finding can appear in `failed_checks()` and
in `nrow(issues(x))` without changing `n_issues()`.

## Details

[tidy()](https://r-pkg.thecoatlessprofessor.com/checktor/reference/tidy.md)
answers a different question. It gives each check one state, so the same
skipped check has `passed = FALSE` and `skipped = TRUE` there. To tell a
pass from a skip, use
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) or
[summary()](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor-summary.md).

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
is_healthy(results)
#> [1] FALSE
failed_checks(results)
#> [1] "code.tf_usage"
```

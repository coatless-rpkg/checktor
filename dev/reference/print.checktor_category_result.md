# Print Method for checktor_category_result Objects

Print Method for checktor_category_result Objects

## Usage

``` r
# S3 method for class 'checktor_category_result'
print(x, ...)
```

## Arguments

- x:

  A checktor_category_result object

- ...:

  Additional arguments (unused)

## Value

Returns `x` invisibly

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
print(diagnose_code_issues(pkg, verbose = FALSE))
#> ── Diagnostic Category Results ─────────────────────────────────────────────────
#> ! 1 of 16 checks failed
#> Failed checks:
#> tf_usage: 7 issues
```

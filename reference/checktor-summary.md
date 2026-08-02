# Per-category summary of checktor results

Per-category summary of checktor results

## Usage

``` r
# S3 method for class 'checktor_category_result'
summary(object, ...)

# S3 method for class 'checktor_results'
summary(object, ...)
```

## Arguments

- object:

  A `checktor_results` or `checktor_category_result` object.

- ...:

  Unused.

## Value

For results: a 5-row `data.frame`
(`category, checks, passed, failed, skipped, issues`). For a category: a
1-row `data.frame` (`checks, passed, failed, skipped, issues`).
`skipped` counts the checks that did not run, which are not counted as
passing.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
summary(results)
#>        category checks passed failed skipped issues
#> 1          code     16     15      1       0      7
#> 2   description     19     18      1       1      1
#> 3 documentation     13     13      0       0      0
#> 4       general      5      5      0       1      0
#> 5        policy      4      4      0       0      0
```

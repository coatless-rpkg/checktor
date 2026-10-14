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
1-row `data.frame` (`checks, passed, failed, skipped, issues`). Each
check is counted once, so `passed`, `failed` and `skipped` add up to
`checks`, and a check that did not run is `skipped`, never `passed`.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
summary(results)
#>        category checks passed failed skipped issues
#> 1          code     16     15      1       0      7
#> 2   description     23     22      0       1      0
#> 3 documentation     17     17      0       0      0
#> 4       general      7      6      0       1      0
#> 5        policy      4      4      0       0      0
```

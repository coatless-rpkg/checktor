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
(`category, checks, passed, failed, issues`). For a category: a 1-row
`data.frame` (`checks, passed, failed, issues`).

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
summary(results)
#>        category checks passed failed issues
#> 1          code     13     12      1      7
#> 2   description     14     11      3      3
#> 3 documentation      6      6      0      0
#> 4       general      2      2      0      0
#> 5        policy      4      4      0      0
```

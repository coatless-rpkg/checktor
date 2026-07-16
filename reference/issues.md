# Extract issues, checks, or a per-category summary from checktor results

Plain accessors over the objects returned by
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
and the `diagnose_*_issues()` functions, so you never navigate nested
sublists.

## Usage

``` r
issues(x, ...)

# S3 method for class 'checktor_check_result'
issues(x, ...)

# S3 method for class 'checktor_category_result'
issues(x, ...)

# S3 method for class 'checktor_results'
issues(x, ...)
```

## Arguments

- x:

  A `checktor_results`, `checktor_category_result`, or
  `checktor_check_result` object.

- ...:

  Unused.

## Value

`issues()` returns a `data.frame` with one row per issue. At the results
level the columns are `category`, `check`, `file`, `line`, `location`,
`message`; a single category drops `category`; a single check drops
`category` and `check`. A healthy object yields a 0-row frame.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
issues(results)
#>      category    check   severity           file line
#> 1        code tf_usage robustness tf_usage_bad.R    8
#> 2        code tf_usage robustness tf_usage_bad.R   11
#> 3        code tf_usage robustness tf_usage_bad.R   15
#> 4        code tf_usage robustness tf_usage_bad.R   18
#> 5        code tf_usage robustness tf_usage_bad.R   22
#> 6        code tf_usage robustness tf_usage_bad.R   25
#> 7        code tf_usage robustness tf_usage_bad.R   29
#> 8 description cph_role    opinion           <NA>   NA
#>                                            location         message
#> 1                                  tf_usage_bad.R:8 T/F usage check
#> 2                                 tf_usage_bad.R:11 T/F usage check
#> 3                                 tf_usage_bad.R:15 T/F usage check
#> 4                                 tf_usage_bad.R:18 T/F usage check
#> 5                                 tf_usage_bad.R:22 T/F usage check
#> 6                                 tf_usage_bad.R:25 T/F usage check
#> 7                                 tf_usage_bad.R:29 T/F usage check
#> 8 Authors@R lacks any [cph] (copyright holder) role  cph role check
```

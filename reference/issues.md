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

`issues()` returns a `data.frame` with one row per issue, whatever its
severity tier. At the results level the columns are `category`, `check`,
`severity`, `file`, `line`, `location`, `message`; a single category
drops `category`; a single check drops `category`, `check` and
`severity`. A healthy object yields a 0-row frame.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
issues(results)
#>   category    check   severity           file line          location
#> 1     code tf_usage robustness tf_usage_bad.R    8  tf_usage_bad.R:8
#> 2     code tf_usage robustness tf_usage_bad.R   11 tf_usage_bad.R:11
#> 3     code tf_usage robustness tf_usage_bad.R   15 tf_usage_bad.R:15
#> 4     code tf_usage robustness tf_usage_bad.R   18 tf_usage_bad.R:18
#> 5     code tf_usage robustness tf_usage_bad.R   22 tf_usage_bad.R:22
#> 6     code tf_usage robustness tf_usage_bad.R   25 tf_usage_bad.R:25
#> 7     code tf_usage robustness tf_usage_bad.R   29 tf_usage_bad.R:29
#>           message
#> 1 T/F usage check
#> 2 T/F usage check
#> 3 T/F usage check
#> 4 T/F usage check
#> 5 T/F usage check
#> 6 T/F usage check
#> 7 T/F usage check
```

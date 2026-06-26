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
#>       category              check           file line
#> 1         code           tf_usage tf_usage_bad.R    8
#> 2         code           tf_usage tf_usage_bad.R   11
#> 3         code           tf_usage tf_usage_bad.R   15
#> 4         code           tf_usage tf_usage_bad.R   18
#> 5         code           tf_usage tf_usage_bad.R   22
#> 6         code           tf_usage tf_usage_bad.R   23
#> 7         code           tf_usage tf_usage_bad.R   26
#> 8  description            license           <NA>   NA
#> 9  description           cph_role           <NA>   NA
#> 10 description description_length           <NA>   NA
#>                                                           location
#> 1                                                 tf_usage_bad.R:8
#> 2                                                tf_usage_bad.R:11
#> 3                                                tf_usage_bad.R:15
#> 4                                                tf_usage_bad.R:18
#> 5                                                tf_usage_bad.R:22
#> 6                                                tf_usage_bad.R:23
#> 7                                                tf_usage_bad.R:26
#> 8  MIT/BSD license requires '+ file LICENSE' for copyright holders
#> 9                Authors@R lacks any [cph] (copyright holder) role
#> 10                    Description too short: 1 sentences, 18 words
#>                     message
#> 1           T/F usage check
#> 2           T/F usage check
#> 3           T/F usage check
#> 4           T/F usage check
#> 5           T/F usage check
#> 6           T/F usage check
#> 7           T/F usage check
#> 8             License check
#> 9            cph role check
#> 10 Description length check
```

# Diagnose `T`/`F` Usage in R Code

Flags bare `T` / `F` symbols that should be `TRUE` / `FALSE`. Operates
on the parsed syntax tree, so `T` inside a string or a comment is not
reported, which a plain text search could not tell apart. Named-argument
names (`f(T = 1)`) and `$T` / `@T` extractions are excluded.

## Usage

``` r
lab_tf_usage(path, verbose = TRUE, parsed = NULL)
```

## Arguments

- path:

  Character. Path to package directory.

- verbose:

  Logical. Print diagnostic messages.

- parsed:

  Internal. Pre-parsed source cache; if `NULL`, files are read from
  `path` on demand.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

No binding rule forbids `T` and `F`, though the CRAN Cookbook keeps a
recipe for it under [T/F Instead of
TRUE/FALSE](https://contributor.r-project.org/cran-cookbook/code_issues.html#tf-instead-of-truefalse).
They are ordinary variables (see
[`?logical`](https://rdrr.io/r/base/logical.html)) that R sets to `TRUE`
and `FALSE` at startup but that any code can rebind, so a function
reading `T` after something has run `T <- 0` gets the wrong answer. A
real risk that no rule makes citable is why this sits at `robustness`
tier rather than policy. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
# show_content defaults to TRUE, so the offending file prints first
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R")
#> === Example file: tf_usage_bad.R ===
#> # Example file showing T/F usage issues
#> 
#> #' Process Data Function
#> #' @param data A data frame
#> #' @return Logical indicating success
#> process_data <- function(data) {
#>   if (is.null(data)) {
#>     return(F) # Issue: should be FALSE
#>   }
#> 
#>   has_complete_cases <- T # Issue: should be TRUE
#> 
#>   if (has_complete_cases) {
#>     cleaned_data <- data[complete.cases(data), ]
#>     return(T) # Issue: should be TRUE
#>   }
#> 
#>   return(F) # Issue: should be FALSE
#> }
#> 
#> # Another function with T/F issues
#> validate_input <- function(x, strict = T) {
#>   # Issue: should be TRUE
#>   if (length(x) == 0) {
#>     return(F)
#>   } # Issue: should be FALSE
#> 
#>   valid <- all(is.numeric(x))
#>   return(valid && strict == T) # Issue: should be TRUE
#> }
#> 
#> === End of example ===
#> 
issues(lab_tf_usage(pkg, verbose = FALSE))
#>             file line          location         message
#> 1 tf_usage_bad.R    8  tf_usage_bad.R:8 T/F usage check
#> 2 tf_usage_bad.R   11 tf_usage_bad.R:11 T/F usage check
#> 3 tf_usage_bad.R   15 tf_usage_bad.R:15 T/F usage check
#> 4 tf_usage_bad.R   18 tf_usage_bad.R:18 T/F usage check
#> 5 tf_usage_bad.R   22 tf_usage_bad.R:22 T/F usage check
#> 6 tf_usage_bad.R   25 tf_usage_bad.R:25 T/F usage check
#> 7 tf_usage_bad.R   29 tf_usage_bad.R:29 T/F usage check
```

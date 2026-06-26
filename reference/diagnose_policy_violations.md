# Check for Common CRAN Policy Violations

Runs additional diagnostics focused on CRAN policy: leftover
[`browser()`](https://rdrr.io/r/base/browser.html) calls, raw system
invocations, file writes outside
[`tempdir()`](https://rdrr.io/r/base/tempfile.html), and unwrapped
network access in examples or vignettes. Code-side checks use the parsed
AST so string/comment matches don't false-positive; Rd-side checks use
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html) for the
same reason.

## Usage

``` r
diagnose_policy_violations(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the R package directory. Default: `"."`.

- verbose:

  Logical. Whether to print diagnostic output. Default: `TRUE`.

## Value

List of
[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
objects, plus a `passed` named logical vector summarizing pass/fail per
check.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
for complete package diagnostics

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/browser_calls_bad.R",
                                 show_content = FALSE)
policy <- diagnose_policy_violations(pkg, verbose = FALSE)
summary(policy)
#>   checks passed failed issues
#> 1      4      3      1      3
issues(policy)
#>           check                file line               location
#> 1 browser_calls browser_calls_bad.R    6  browser_calls_bad.R:6
#> 2 browser_calls browser_calls_bad.R   11 browser_calls_bad.R:11
#> 3 browser_calls browser_calls_bad.R   23 browser_calls_bad.R:23
#>               message
#> 1 Browser calls check
#> 2 Browser calls check
#> 3 Browser calls check
```

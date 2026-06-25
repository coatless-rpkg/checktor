# Quick Health Check

Runs
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
with minimal output, suitable for CI/CD pipelines.

## Usage

``` r
checkup(path = ".")
```

## Arguments

- path:

  Character. Path to the R package directory. Default: `"."`.

## Value

Logical. `TRUE` if no issues were found, `FALSE` otherwise.

## Examples

``` r
# A clean synthetic package passes; a known-bad one does not
pkg_bad <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                     show_content = FALSE)
checkup(pkg_bad)
#> [1] FALSE
```

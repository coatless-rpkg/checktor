# Quick Health Check

Runs
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
with minimal output, suitable for CI/CD pipelines.

## Usage

``` r
checkup(
  path = ".",
  severity = getOption("checktor.severity", DEFAULT_SEVERITY)
)
```

## Arguments

- path:

  Character. Path to the R package directory. Default: `"."`.

- severity:

  Character. Which severity tiers count toward the result: any of
  `"policy"`, `"robustness"`, `"opinion"`. Defaults to
  `getOption("checktor.severity", c("policy", "robustness"))`, so a
  build is not failed by a convention nobody enforces. Pass all three to
  hold the package to the conventions as well. See
  [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md).

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

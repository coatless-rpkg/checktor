# Treatment Recommendations

Prints specific treatment recommendations for the checks that failed in
a
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
run, whatever their severity tier, so an advisory finding outside the
verdict still gets its remedy.

## Usage

``` r
prescribe(results)
```

## Arguments

- results:

  A `checktor_results` object.

## Value

Invisibly returns `NULL`. Called for the side effect of printing
recommendations.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
prescribe(results)
#> ── Treatment Recommendations ───────────────────────────────────────────────────
#> 
#> ── T/F Usage Issues 
#> Issues found:
#> • tf_usage_bad.R:8
#> • tf_usage_bad.R:11
#> • tf_usage_bad.R:15
#> • tf_usage_bad.R:18
#> • tf_usage_bad.R:22
#> ... and 2 more
#> Treatment: Replace `T` with `TRUE` and `F` with `FALSE`
#> # Before
#> result <- T
#> # After
#> result <- TRUE
#> 
```

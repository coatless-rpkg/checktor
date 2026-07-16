# Treatment Recommendations

Prints specific treatment recommendations for issues found by
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md).

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
#> Treatment: Replace `T` with `TRUE` and `F` with `FALSE`
#> # Before
#> result <- T
#> # After
#> result <- TRUE
#> 
#> 
#> ── cph role check 
#> Issues found:
#> • Authors@R lacks any [cph] (copyright holder) role
#> Treatment: Review the detailed diagnosis above; re-run `checktor(verbose =
#> TRUE)` for specifics.
#> 
```

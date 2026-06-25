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
#> Treatment: Replace {.code T} with {.code TRUE} and {.code F} with {.code FALSE}
#> # Before
#> result <- T
#> # After
#> result <- TRUE
#> 
```

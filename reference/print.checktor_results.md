# Print Method for checktor_results Objects

Provides a clean, formatted summary of diagnostic results from
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md).

## Usage

``` r
# S3 method for class 'checktor_results'
print(x, ...)
```

## Arguments

- x:

  A `checktor_results` object from
  [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)

- ...:

  Additional arguments passed to print methods (currently unused)

## Value

Returns `x` invisibly. Called primarily for its side effect of printing
a formatted summary to the console.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
to generate results,
[`health_report()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/health_report.md)
for detailed reports

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
print(results)
#> ── Package Doctor - Diagnosis Summary ──────────────────────────────────────────
#> Patient: examplepackage
#> Examined: 2026-06-26 20:38:23.666111
#> Doctor version: 0.1.0
#> 
#> CODE ISSUES: 1 failing check
#> DESCRIPTION ISSUES: 3 failing checks
#> DOCUMENTATION ISSUES: HEALTHY
#> GENERAL ISSUES: HEALTHY
#> POLICY ISSUES: HEALTHY
#> 
#> ! Overall health: NEEDS ATTENTION (10 issues)
#> Run `summary()`, `issues()`, or `prescribe()` for details
```

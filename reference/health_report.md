# Comprehensive Health Report

Creates a comprehensive report with specific treatment instructions

## Usage

``` r
health_report(results, file = NULL, format = "markdown")
```

## Arguments

- results:

  List. Results from checktor()

- file:

  Character. Output file path (optional)

- format:

  Character. Report format: "markdown", "html", or "text"

## Value

Character vector with report content

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
report <- health_report(results, format = "text")
head(report)
#> [1] "Package Doctor - Health Report"                                
#> [2] "Generated on: 2026-06-26 20:38:22.861319"                      
#> [3] "Patient: /tmp/RtmpQVdLzn/checktor_example_20260626_203822_5928"
#> [4] ""                                                              
#> [5] "Summary:"                                                      
#> [6] "Total Issues: 10"                                              
```

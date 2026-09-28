# Comprehensive Health Report

Creates a report of every failing check, whatever its severity tier,
with the treatment
[`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)
gives for it. Every format carries the same treatment text.

## Usage

``` r
health_report(results, file = NULL, format = "markdown")
```

## Arguments

- results:

  A `checktor_results` object from
  [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md).

- file:

  Character. A path to write the report to, or `NULL` (the default) to
  only return it.

- format:

  Character. Report format: `"markdown"` (the default), `"html"`, or
  `"text"`. Any other value gives the text format.

## Value

The report as a character vector, one element per line. It is returned
visibly even when `file` is given, so assign it to keep a console call
from printing it.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
report <- health_report(results, format = "text")
head(report)
#> [1] "Package Doctor - Health Report"                        
#> [2] "Generated on: 2026-09-28 22:25:25.66064"               
#> [3] "Patient: /tmp/RtmpX5ACEV/checktor_example_19e9339c2f09"
#> [4] ""                                                      
#> [5] "Summary:"                                              
#> [6] "Total Issues: 7"                                       
```

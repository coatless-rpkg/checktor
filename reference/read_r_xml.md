# Parse a Package's R Sources into Queryable XML

Parses every `R/*.R` file under `path` with `parse(keep.source = TRUE)`
and converts each file's parse data to an `xml2` document via
[`xmlparsedata::xml_parse_data()`](https://rdrr.io/pkg/xmlparsedata/man/xml_parse_data.html).
This is the entry point for an AST-based check: hand the result to
[`xpath_lints()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/xpath_lints.md)
or one of the other helpers. A syntax error in a file is caught and
recorded in that file's `error` slot rather than crashing the run.

## Usage

``` r
read_r_xml(path)
```

## Arguments

- path:

  Character. Path to the R package directory.

## Value

A named list with one entry per `R/*.R` file, each a list of `file` (the
path), `xml` (an `xml2` document, or `NULL` if the file did not parse),
and `error` (the `simpleError`, or `NULL`).

## See also

[`xpath_lints()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/xpath_lints.md),
[`register_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/register_check.md),
and the *Writing Your Own Checks* vignette.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
parsed <- read_r_xml(pkg)
names(parsed)
#> [1] "/tmp/RtmpuBetXh/checktor_example_20260726_175830_8330/R/tf_usage_bad.R"
```

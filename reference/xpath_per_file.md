# Summarise XPath Matches per File

A per-file variant of
[`xpath_lints()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/xpath_lints.md)
for when you need to control the issue string. Runs `xpath` against each
parsed file and calls `summarise(file, nodes)` on each non-empty match
set, collecting the strings it returns.

## Usage

``` r
xpath_per_file(parsed, xpath, summarise)
```

## Arguments

- parsed:

  A parsed-sources list from
  [`read_r_xml()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/read_r_xml.md).

- xpath:

  Character. An XPath 1.0 query.

- summarise:

  A function of `(file, nodes)` returning a character vector of issue
  strings, where `nodes` is an `xml2` nodeset.

## Value

A character vector of the issue strings `summarise` produced.

## See also

[`xpath_lints()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/xpath_lints.md).

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/seed_setting_bad.R",
                                 show_content = FALSE)
parsed <- read_r_xml(pkg)
xpath_per_file(parsed, "//SYMBOL_FUNCTION_CALL[text() = 'set.seed']",
               function(file, nodes) {
                 paste0(basename(file), ":", xml2::xml_attr(nodes, "line1"))
               })
#> [1] "seed_setting_bad.R:7"  "seed_setting_bad.R:15"
```

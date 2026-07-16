# Collect XPath Matches as `file:line` Strings

Runs an XPath query against every parsed file from
[`read_r_xml()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/read_r_xml.md)
and returns a `"basename:line"` string for each matching node, ready to
use as a check's `issues`.

## Usage

``` r
xpath_lints(parsed, xpath, label = NULL)
```

## Arguments

- parsed:

  A parsed-sources list from
  [`read_r_xml()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/read_r_xml.md).

- xpath:

  Character. An XPath 1.0 query, typically anchored on a
  `SYMBOL_FUNCTION_CALL` node.

- label:

  Optional character. Appended in parentheses after each hit.

## Value

A character vector of `"basename:line"` strings, empty if nothing
matched.

## See also

[`read_r_xml()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/read_r_xml.md),
[`xpath_per_file()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/xpath_per_file.md),
[`undesirable_function_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/undesirable_function_check.md).

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/seed_setting_bad.R",
                                 show_content = FALSE)
parsed <- read_r_xml(pkg)
xpath_lints(parsed, "//SYMBOL_FUNCTION_CALL[text() = 'set.seed']")
#> [1] "seed_setting_bad.R:7"  "seed_setting_bad.R:15"
```

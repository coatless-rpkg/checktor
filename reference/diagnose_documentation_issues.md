# Diagnose Documentation Issues

Runs diagnostics on package documentation to identify common issues that
can cause CRAN submission problems or a poor user experience.

## Usage

``` r
diagnose_documentation_issues(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

## Value

List of
[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
objects plus a `passed` named logical vector summarizing pass/fail per
check.

## Details

This function checks for:

- Missing `\value` tags in function documentation

- Roxygen2 usage

- Example structure (appropriate use of `\dontrun{}`)

`.Rd` files are parsed structurally via
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html) so analyses
look at sections by their `Rd_tag` rather than grepping LaTeX text.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
for complete package diagnostics

## Examples

``` r
pkg_path <- example_diagnose_scenario("documentation_examples/missing_value_tag.Rd",
                                      show_content = FALSE)
doc_results <- diagnose_documentation_issues(pkg_path, verbose = FALSE)
doc_results$value_tags$passed  # Should be FALSE
#> [1] FALSE
```

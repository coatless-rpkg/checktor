# Diagnose Missing Value Tags in Documentation

Walks `.Rd` files via
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html) and reports
topics that are missing a `\value{}` section. Data, class, methods,
package-level, and re-export topics are skipped (they don't need
`\value{}`).

## Usage

``` r
diagnose_value_tags(path, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory

- verbose:

  Logical. Print diagnostic messages

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `missing`, `message`.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Documenting-functions),
under "Documenting functions", describes `\value{}`, and the CRAN
Cookbook keeps the recipe reviewers cite under [Missing value-tags in
.Rd-files](https://contributor.r-project.org/cran-cookbook/docs_issues.html#missing-value-tags-in-.rd-files),
but `R CMD check` does not require it, so checktor keeps this at
`opinion` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg_path <- example_diagnose_scenario("documentation_examples/missing_value_tag.Rd",
                                      show_content = FALSE)
issues(diagnose_value_tags(pkg_path, verbose = FALSE))
#>   file line             location          message
#> 1 <NA>   NA missing_value_tag.Rd Value tags check
```

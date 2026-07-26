# Diagnose an Unfilled LICENSE Template

Flags a `LICENSE` file still carrying template placeholders such as
`<YEAR>` or `<COPYRIGHT HOLDER>`.

## Usage

``` r
diagnose_license_year(path, verbose)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

The CRAN Cookbook covers the file itself under [LICENSE
files](https://contributor.r-project.org/cran-cookbook/description_issues.html#license-files).
An unfilled template, with `<YEAR>` or `<COPYRIGHT HOLDER>` left in,
ships a placeholder, and no binding rule names it, which is why this
sits at `robustness` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_license_year(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

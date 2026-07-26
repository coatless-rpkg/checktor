# Diagnose Redundant Phrases in Title

Flags a `Title` carrying a phrase CRAN asks you to drop, such as "for
R".

## Usage

``` r
diagnose_title_redundant_phrases(path = ".", verbose = TRUE, desc = NULL)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

- desc:

  Optional pre-parsed `DESCRIPTION`, as returned by
  [`base::read.dcf()`](https://rdrr.io/r/base/dcf.html). Defaults to
  reading it from `path`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

No formal rule. Phrases like "R package to" are redundant in a `Title`,
a convention which is why this sits at `opinion` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_title_redundant_phrases(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

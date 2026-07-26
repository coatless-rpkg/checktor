# Diagnose Unexplained Acronyms in DESCRIPTION

Flags an acronym in `Description` that is never spelled out. A
parenthetical gloss in either order counts as explained.

## Usage

``` r
diagnose_acronym_explanation(path = ".", verbose = TRUE, desc = NULL)
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

The CRAN Cookbook covers this under [Explaining
Acronyms](https://contributor.r-project.org/cran-cookbook/description_issues.html#explaining-acronyms).
Reviewers ask for an acronym to be spelled out once, but nothing
enforces it, which is why this sits at `opinion` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_acronym_explanation(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

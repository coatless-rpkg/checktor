# Diagnose the Authors@R Field

Flags a missing `Authors@R`, and an unfilled `usethis` template such as
`person("First", "Last", ...)`, which is a hard CRAN rejection that
`R CMD check` says nothing about.

## Usage

``` r
diagnose_authors_field(path = ".", verbose = TRUE, desc = NULL)
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

The [CRAN Repository
Policy](https://cran.r-project.org/web/packages/policies.html) treats a
placeholder or malformed `Authors@R`, including a missing maintainer, as
a rejection. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_authors_field(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

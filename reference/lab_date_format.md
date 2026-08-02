# Diagnose the DESCRIPTION Date Field

Flags a `Date` field that is not ISO 8601 `yyyy-mm-dd`, is over a month
old, or lies in the future. Mirrors the CRAN incoming check; an absent
`Date` field (the common, preferred case) passes.

## Usage

``` r
lab_date_format(path = ".", verbose = TRUE, desc = NULL)
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

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
under "The DESCRIPTION file", says "the 'yyyy-mm-dd' format of the ISO
8601 standard is strongly recommended"; the [incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
also flags a stale or future date. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_date_format(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

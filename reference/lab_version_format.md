# Diagnose the DESCRIPTION Version Field

Flags a `Version` with a leading-zero component or a suspiciously large
one, mirroring CRAN's `version_with_leading_zeroes` and
`version_with_large_components` incoming checks. A calendar-year
component (e.g. a dated `2026.01` version) is exempt.

## Usage

``` r
lab_version_format(path = ".", verbose = TRUE, desc = NULL)
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
under "The DESCRIPTION file", says a `Version` is "a sequence of at
least two ... non-negative integers"; the [incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
flags a leading zero or an implausible value. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_version_format(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

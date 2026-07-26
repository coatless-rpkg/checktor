# Diagnose a Non-Portable DESCRIPTION Encoding

Flags an `Encoding` outside the portable set Writing R Extensions names:
`UTF-8`, `latin1`, `latin2` (compared case-insensitively). An absent
`Encoding` passes.

## Usage

``` r
diagnose_encoding_utf8(path = ".", verbose = TRUE, desc = NULL)
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
under "The DESCRIPTION file", says a non-ASCII DESCRIPTION "should
contain an 'Encoding' field"; the [incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
flags a non-portable one. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_encoding_utf8(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

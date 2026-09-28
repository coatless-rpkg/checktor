# Diagnose a DESCRIPTION Encoding Other Than UTF-8

Flags an `Encoding` that is anything but exactly `UTF-8`, which is the
test CRAN's incoming check applies. `latin1` and `latin2` are still
legal R, but CRAN NOTEs them as deprecated, and the comparison is
case-sensitive, so a lower-case `utf-8` is NOTEd too. An absent
`Encoding` passes.

## Usage

``` r
lab_encoding_utf8(path = ".", verbose = TRUE, desc = NULL)
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
run by `R CMD check --as-cran` NOTEs any value but `UTF-8` with "Package
encoding '...' is deprecated. Please change to UTF-8 for non-ASCII
content." See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/encoding_utf8_bad.txt",
                                 show_content = FALSE)
lab_encoding_utf8(pkg, verbose = FALSE)$issues
#> [1] "Encoding is \"latin1\"; CRAN's incoming check says package encoding 'latin1' is deprecated and asks for UTF-8"
unlink(pkg, recursive = TRUE)
```

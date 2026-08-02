# Diagnose Programming-Language Names in DESCRIPTION

Flags a bare programming-language, markup, or statistical-computing name
– `Python`, `Java`, `C++`, `SQL`, `HTML`, `MATLAB`, `SAS` and more – in
`Title` or `Description` that CRAN asks to see single-quoted. This is
the language counterpart to
[`lab_software_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_software_names.md):
both are policy-tier quoting checks, kept separate because a language
name and a package name are different kinds of thing. `R` itself is
never flagged – it is the host language and appears too often to quote
sensibly, and single-letter or common-word names (`C`, `Go`, `Swift`)
are left out for the same reason.

## Usage

``` r
lab_language_names(path = ".", verbose = TRUE, desc = NULL)
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

## Details

A package can extend the list through `Config/checktor/language_names`
in its own DESCRIPTION.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
under "The DESCRIPTION file", asks for single quotes around other
software; checktor applies the same to programming-language and markup
names. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_software_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_software_names.md).

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_language_names(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

# Diagnose Programming-Language Names in DESCRIPTION

Flags a bare programming-language, markup, or statistical-computing name
– `Python`, `Java`, `C++`, `SQL`, `HTML`, `MATLAB`, `SAS` and more – in
`Title` or `Description` that CRAN asks to see single-quoted. This is
the language counterpart to
[`diagnose_software_names_formatting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_software_names_formatting.md):
both are policy-tier quoting checks, kept separate because a language
name and a package name are different kinds of thing. `R` itself is
never flagged – it is the host language and appears too often to quote
sensibly, and single-letter or common-word names (`C`, `Go`, `Swift`)
are left out for the same reason.

## Usage

``` r
diagnose_language_names(path = ".", verbose = TRUE, desc = NULL)
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

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`diagnose_software_names_formatting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_software_names_formatting.md).

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_language_names(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

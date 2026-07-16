# Diagnose a Bare R in DESCRIPTION

Flags an unquoted `R` in `Description`.

## Usage

``` r
diagnose_description_bare_r(path = ".", verbose = TRUE, desc = NULL)
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

This check is NOT part of a
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
run, and is kept only for callers who want it. No authority supports the
rule: Writing R Extensions reserves single quotes for OTHER software,
and R is the host language, not a dependency. Measured against one
installed library, 115 packages write R bare and 25 quote it.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_description_bare_r(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

# Diagnose Reference Formatting in DESCRIPTION

Flags a reference that is not in CRAN's expected `<doi:...>` /
`<arXiv:...>` form.

## Usage

``` r
diagnose_references_formatting(path = ".", verbose = TRUE, desc = NULL)
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

The [CRAN incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
run by `R CMD check --as-cran` NOTEs a reference not written in the
`<doi:...>` or `<arXiv:...>` form. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_references_formatting(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

# Diagnose `:::` in Examples

Flags a `pkg:::fn()` call in an example. The triple colon reaches an
unexported object, whose behaviour the author is free to change, so CRAN
asks for one colon or for the object to be exported.

## Usage

``` r
lab_example_internal_ns(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

CRAN sends this back verbatim as "Using foo:::f instead of foo::f allows
access to unexported objects ... Please omit one colon", listing the
`.Rd` files it appears in. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_unexported_example_ns()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_unexported_example_ns.md).

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_example_internal_ns(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

# Diagnose `:::` in Package Code

Flags a `pkg:::fn()` call in `R/`. The triple colon reaches an object
another package does not export, whose behaviour its author is free to
change in routine maintenance, so a release elsewhere can break your
package without warning.

## Usage

``` r
lab_internal_ns(path, verbose = TRUE, parsed = NULL)
```

## Arguments

- path:

  Character. Path to package directory.

- verbose:

  Logical. Print diagnostic messages.

- parsed:

  Internal. Pre-parsed source cache; if `NULL`, files are read from
  `path` on demand.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Details

A call into your own package is reported too, since a package almost
never needs `:::` for its own objects: everything in the namespace is
already visible to the rest of it.

## Source

CRAN sends this back as "Using foo:::f instead of foo::f allows access
to unexported objects. This is generally not recommended ... Please omit
one colon." `R CMD check` reports it too, under dependencies in R code,
so this check is the same finding without waiting for a full check. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_example_internal_ns()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_example_internal_ns.md)
for the same rule in examples.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_internal_ns(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

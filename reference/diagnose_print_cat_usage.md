# Diagnose Print/Cat Usage in Functions

Flags [`print()`](https://rdrr.io/r/base/print.html) /
[`cat()`](https://rdrr.io/r/base/cat.html) calls not guarded by an
enclosing `if()`, `for()`, or `while()`. The check uses the ancestor
axis, so guard detection is robust regardless of formatting.

## Usage

``` r
diagnose_print_cat_usage(path, verbose = TRUE, parsed = NULL)
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

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/print_cat_bad.R",
                                 show_content = FALSE)
diagnose_print_cat_usage(pkg, verbose = FALSE)$passed
#> [1] FALSE
```

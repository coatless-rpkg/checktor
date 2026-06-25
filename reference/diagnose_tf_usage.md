# Diagnose `T`/`F` Usage in R Code

Flags bare `T` / `F` symbols that should be `TRUE` / `FALSE`. Operates
on the parsed AST, so `T` inside string literals or comments is not
flagged (a long-standing source of regex false positives).
Named-argument names (`f(T = 1)`) and `$T` / `@T` extractions are
excluded.

## Usage

``` r
diagnose_tf_usage(path, verbose = TRUE, parsed = NULL)
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
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_tf_usage(pkg, verbose = FALSE)$issues
#> [1] "tf_usage_bad.R:8"  "tf_usage_bad.R:11" "tf_usage_bad.R:15"
#> [4] "tf_usage_bad.R:18" "tf_usage_bad.R:22" "tf_usage_bad.R:23"
#> [7] "tf_usage_bad.R:26"
```

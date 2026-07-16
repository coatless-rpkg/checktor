# Diagnose Unrestored Environment Variables

Flags [`Sys.setenv()`](https://rdrr.io/r/base/Sys.setenv.html) with no
matching cleanup in the same function.

## Usage

``` r
diagnose_sys_setenv_no_reset(path, verbose = TRUE, parsed = NULL)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

- parsed:

  Optional pre-parsed source, as returned internally by the
  orchestrator. Defaults to parsing `path` afresh.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_sys_setenv_no_reset(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

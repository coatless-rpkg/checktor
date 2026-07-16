# Diagnose Parallel Core Usage

Flags a worker count that can exceed CRAN's two-core limit. Understands
parallel, snow, foreach, future, furrr, mirai, RcppParallel, data.table,
and BiocParallel.

## Usage

``` r
diagnose_core_usage(path, verbose = TRUE, parsed = NULL)
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
diagnose_core_usage(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

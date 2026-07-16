# Diagnose Unrestored Option Changes

Flags [`options()`](https://rdrr.io/r/base/options.html) /
[`par()`](https://rdrr.io/r/graphics/par.html) /
[`setwd()`](https://rdrr.io/r/base/getwd.html) changed without
restoring. A setter that captures the old value and hands it back
honours the base R contract and is not flagged.

## Usage

``` r
diagnose_option_changes(path, verbose = TRUE, parsed = NULL)
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
diagnose_option_changes(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

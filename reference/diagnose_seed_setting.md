# Diagnose Hardcoded Seed Setting

Flags `set.seed(<numeric>)` calls. Multi-line forms are handled because
the check matches the call AST node, not raw text.

## Usage

``` r
diagnose_seed_setting(path, verbose = TRUE, parsed = NULL)
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
pkg <- example_diagnose_scenario("code_examples/seed_setting_bad.R",
                                 show_content = FALSE)
diagnose_seed_setting(pkg, verbose = FALSE)   # prints PASSED/FAILED
#> ✖ Seed setting check: FAILED
#> Issues found:
#> • seed_setting_bad.R:7
#> • seed_setting_bad.R:15
```

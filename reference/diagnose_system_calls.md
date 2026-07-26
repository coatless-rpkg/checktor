# Diagnose System Calls

Flags [`system()`](https://rdrr.io/r/base/system.html) /
[`system2()`](https://rdrr.io/r/base/system2.html) / `shell()`, which
need review for portability and for shell-injection risk.

## Usage

``` r
diagnose_system_calls(path, verbose = TRUE, parsed = NULL)
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

## Source

No flat rule. A raw [`system()`](https://rdrr.io/r/base/system.html) or
[`system2()`](https://rdrr.io/r/base/system2.html) call needs review for
portability rather than being an automatic violation, which is why this
sits at `robustness` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_system_calls(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

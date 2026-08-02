# Diagnose Hardcoded Seed Setting

Flags `set.seed(<numeric>)` calls. Multi-line forms are handled because
the check matches the call AST node, not raw text.

## Usage

``` r
lab_seed_setting(path, verbose = TRUE, parsed = NULL)
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

## Source

The [CRAN Repository
Policy](https://cran.r-project.org/web/packages/policies.html) asks a
package not to modify the user's workspace, and
[`set.seed()`](https://rdrr.io/r/base/Random.html) writes `.Random.seed`
there, changing the random-number stream for the rest of the session.
See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/seed_setting_bad.R",
                                 show_content = FALSE)
lab_seed_setting(pkg, verbose = FALSE)   # prints PASSED/FAILED
#> ✖ Seed setting check: FAILED
#> Issues found:
#> • seed_setting_bad.R:7
#> • seed_setting_bad.R:15
```

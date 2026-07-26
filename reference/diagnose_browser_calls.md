# Diagnose Leftover browser() Calls

Flags a [`browser()`](https://rdrr.io/r/base/browser.html) call left in
package code.

## Usage

``` r
diagnose_browser_calls(path, verbose = TRUE, parsed = NULL)
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

The [CRAN Repository
Policy](https://cran.r-project.org/web/packages/policies.html) requires
checks to run non-interactively, so a debugging leftover such as
[`browser()`](https://rdrr.io/r/base/browser.html) must not ship. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_browser_calls(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

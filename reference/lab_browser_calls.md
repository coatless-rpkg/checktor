# Diagnose Leftover browser() Calls

Flags a [`browser()`](https://rdrr.io/r/base/browser.html) call left in
package code.

## Usage

``` r
lab_browser_calls(path = ".", verbose = TRUE, parsed = NULL)
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
[`browser()`](https://rdrr.io/r/base/browser.html) must not be left in.
See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/browser_calls_bad.R",
                                 show_content = FALSE)
lab_browser_calls(pkg, verbose = FALSE)$issues
#> [1] "browser_calls_bad.R:6"  "browser_calls_bad.R:11" "browser_calls_bad.R:23"
unlink(pkg, recursive = TRUE)
```

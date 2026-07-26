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

## Source

No clause names environment variables, but they are session state
exactly as [`options()`](https://rdrr.io/r/base/options.html) are, so
the same restore-on-exit requirement applies. The CRAN Cookbook states
it for options under [Change of Options, Graphical Parameters and
Working
Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory).
See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

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

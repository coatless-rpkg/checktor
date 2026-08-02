# Diagnose Changes to options(warn=)

Flags a change to `options(warn = )` that is not restored.

## Usage

``` r
lab_warn_option(path, verbose = TRUE, parsed = NULL)
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

The CRAN Cookbook covers this under [Setting options(warn =
-1)](https://contributor.r-project.org/cran-cookbook/code_issues.html#setting-optionswarn--1).
Suppressing warnings for the rest of the session hides them from
everything that runs afterwards, so restore the previous value via
[`on.exit()`](https://rdrr.io/r/base/on.exit.html). See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_warn_option(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

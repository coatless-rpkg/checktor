# Diagnose Session State Left Changed by Examples

Flags an example, vignette or demo that changes
[`options()`](https://rdrr.io/r/base/options.html),
[`par()`](https://rdrr.io/r/graphics/par.html) or the working directory
without putting it back. A reader who runs the example is left with a
session that behaves differently afterwards.

## Usage

``` r
lab_example_state(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

The CRAN Cookbook covers this under [Change of Options, Graphical
Parameters and Working
Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory),
and the rejection reads "Please always make sure to reset to user's
options(), working directory or par() after you changed it in examples
and vignettes and demos." See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_option_changes()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_option_changes.md)
for the same rule in `R/`.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_example_state(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

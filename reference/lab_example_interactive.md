# Diagnose Interactive Examples Wrapped in `\\dontrun{}`

Flags an `\\examples{}` block that hides an interactive function behind
`\\dontrun{}`. CRAN asks for `if (interactive())` instead, so a reader
can see the function is not meant for a script rather than only that it
does not run.

## Usage

``` r
lab_example_interactive(path = ".", verbose = TRUE)
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

The CRAN Cookbook covers this under [Structuring of
Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples),
and the rejection reads "Functions which are supposed to only run
interactively (e.g. shiny) should be wrapped in if(interactive()).
Please replace \dontrun with if(interactive()) if possible". See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_example_structure()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_example_structure.md).

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_example_interactive(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

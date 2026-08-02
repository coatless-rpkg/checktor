# Diagnose Title Case in DESCRIPTION

Flags a `Title` that is not in title case, delegating to
[`tools::toTitleCase()`](https://rdrr.io/r/tools/toTitleCase.html),
which restores single-quoted spans so `'shiny'` keeps its own
capitalisation.

## Usage

``` r
lab_title_case(path = ".", verbose = TRUE, desc = NULL)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

- desc:

  Optional pre-parsed `DESCRIPTION`, as returned by
  [`base::read.dcf()`](https://rdrr.io/r/base/dcf.html). Defaults to
  reading it from `path`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
under "The DESCRIPTION file", says the `Title` "should use title case";
the
[`--as-cran`](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
incoming check flags one that does not. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_title_case(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

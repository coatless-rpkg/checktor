# Diagnose library() in Package Code

Flags [`library()`](https://rdrr.io/r/base/library.html) /
[`require()`](https://rdrr.io/r/base/library.html) in package code,
which alters the user's search path. Code destined for a parallel worker
is exempt, since a daemon starts with an empty search path.

## Usage

``` r
lab_library_in_pkg(path, verbose = TRUE, parsed = NULL)
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

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Package-Dependencies),
under "Package Dependencies", asks package code to reach its
dependencies through `Imports` and `::` rather than attaching them with
[`library()`](https://rdrr.io/r/base/library.html). See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_library_in_pkg(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

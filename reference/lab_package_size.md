# Diagnose Package Size

Estimates the size of the source package that would be sent to CRAN
(files matched by `.Rbuildignore`, plus standard scratch directories
like `.git`, `.Rproj.user`, are excluded). Warns at the 5 MB threshold.

## Usage

``` r
lab_package_size(path, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory

- verbose:

  Logical. Print diagnostic messages

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`, and `size_mb`.

## Source

The [CRAN Repository
Policy](https://cran.r-project.org/web/packages/policies.html) limits
the size of the built tarball. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                      show_content = FALSE)
lab_package_size(pkg_path, verbose = FALSE)$size_mb
#> [1] 0.0006465912
```

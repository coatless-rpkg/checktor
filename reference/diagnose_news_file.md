# Diagnose a Missing NEWS File

CRAN expects packages (especially on resubmission) to document
user-facing changes in a `NEWS` file. Accepts `NEWS.md`, `NEWS`, or
`NEWS.Rd` at the package root or under `inst/`.

## Usage

``` r
diagnose_news_file(path, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory

- verbose:

  Logical. Print diagnostic messages

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Examples

``` r
pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                      show_content = FALSE)
file.remove(file.path(pkg_path, "NEWS.md"))   # demonstrate the failing case
#> [1] TRUE
issues(diagnose_news_file(pkg_path, verbose = FALSE))
#>   file line                                                         location
#> 1 <NA>   NA No NEWS file found (add NEWS.md to document user-facing changes)
#>           message
#> 1 NEWS file check
```

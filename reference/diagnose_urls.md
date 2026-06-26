# Diagnose URL Issues in Package Files

Checks common package files for `http://` URLs (should usually be
`https://`) and known URL shortener domains.

## Usage

``` r
diagnose_urls(path, verbose = TRUE)
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
pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt",
                                      show_content = FALSE)
issues(diagnose_urls(pkg_path, verbose = FALSE))
#>   file line                                      location    message
#> 1 <NA>   NA DESCRIPTION: http:// URL (should be https://) URLs check
```

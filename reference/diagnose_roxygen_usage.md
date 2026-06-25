# Diagnose Roxygen2 Usage

Informational check: reports whether the package appears to use
roxygen2.

## Usage

``` r
diagnose_roxygen_usage(path, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory

- verbose:

  Logical. Print diagnostic messages

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed` (always `TRUE`), `has_roxygen`, `message`.

## Examples

``` r
diagnose_roxygen_usage(".", verbose = FALSE)$has_roxygen
#> [1] FALSE
```

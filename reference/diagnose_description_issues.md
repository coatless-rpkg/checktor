# Diagnose DESCRIPTION File Issues

Runs diagnostics against the package DESCRIPTION file. Fields are parsed
with [`base::read.dcf()`](https://rdrr.io/r/base/dcf.html) so that
multi-line fields like `Description` and `Title` are inspected in full,
not just their first physical line.

## Usage

``` r
diagnose_description_issues(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the R package directory. Default: `"."`.

- verbose:

  Logical. Whether to print diagnostic output. Default: `TRUE`.

## Value

List containing one named element per check. Each element is a list with
at least `passed`, `issues`, and `message` (see
[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)).

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
for complete package diagnostics

## Examples

``` r
pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt",
                                      show_content = FALSE)
results <- diagnose_description_issues(pkg_path, verbose = FALSE)
results$license$passed       # MIT + file LICENSE flagged depends on standard
#> [1] FALSE
```

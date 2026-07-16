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
issues(results)     # description-field problems, if any
#>                     check severity file line
#> 1          software_names   policy <NA>   NA
#> 2                acronyms  opinion <NA>   NA
#> 3                 license   policy <NA>   NA
#> 4              title_case   policy <NA>   NA
#> 5                 authors   policy <NA>   NA
#> 6                cph_role  opinion <NA>   NA
#> 7 description_starts_with   policy <NA>   NA
#>                                                                             location
#> 1                                    Description: ggplot2 should be in single quotes
#> 2                                                                                 ML
#> 3                               License points at a LICENSE file that does not exist
#> 4 Title is not in title case. R would write it as: Example Package for Data Analysis
#> 5                                                            Missing Authors@R field
#> 6                                                                  Authors@R missing
#> 7    Description should not start with "This package"; describe what it does instead
#>                     message
#> 1      Software names check
#> 2            Acronyms check
#> 3             License check
#> 4          Title case check
#> 5     Authors@R field check
#> 6            cph role check
#> 7 Description opening check
```

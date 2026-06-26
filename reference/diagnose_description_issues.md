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
#>                      check file line
#> 1           software_names <NA>   NA
#> 2                 acronyms <NA>   NA
#> 3                  license <NA>   NA
#> 4               title_case <NA>   NA
#> 5               title_case <NA>   NA
#> 6               title_case <NA>   NA
#> 7               title_case <NA>   NA
#> 8                  authors <NA>   NA
#> 9                 cph_role <NA>   NA
#> 10      description_length <NA>   NA
#> 11 description_starts_with <NA>   NA
#>                                                       location
#> 1              Description: ggplot2 should be in single quotes
#> 2                                                           ML
#> 3  License declares '+ file LICENSE' but no LICENSE file found
#> 4                    First word should be capitalized: example
#> 5                          Word should be capitalized: package
#> 6                             Word should be capitalized: data
#> 7                         Word should be capitalized: analysis
#> 8                                      Missing Authors@R field
#> 9                                            Authors@R missing
#> 10                Description too short: 2 sentences, 16 words
#> 11    Description starts with forbidden phrase: 'This package'
#>                          message
#> 1           Software names check
#> 2                 Acronyms check
#> 3                  License check
#> 4               Title case check
#> 5               Title case check
#> 6               Title case check
#> 7               Title case check
#> 8          Authors@R field check
#> 9                 cph role check
#> 10      Description length check
#> 11 Description starts-with check
```

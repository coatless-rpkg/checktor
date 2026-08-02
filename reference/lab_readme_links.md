# Diagnose Relative Links in the README

Relative links in `README.md`/`README.Rmd` render on GitHub but break on
CRAN when the target is not included in the built tarball. This flags
relative links whose target is missing on disk or excluded by
`.Rbuildignore` (and therefore absent after `R CMD build`). Relative
links to files that are included (e.g. `man/figures/logo.png`) are not
flagged.

## Usage

``` r
lab_readme_links(path, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory

- verbose:

  Logical. Print diagnostic messages

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

No formal rule. A relative README link whose target is excluded from the
tarball breaks on the package page, which is why this sits at
`robustness` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                      show_content = FALSE)
writeLines("See [the guide](docs/guide.md) for details.",
           file.path(pkg_path, "README.md"))
issues(lab_readme_links(pkg_path, verbose = FALSE))
#>   file line                                                 location
#> 1 <NA>   NA README.md: relative link to missing file 'docs/guide.md'
#>                       message
#> 1 README relative-links check
```

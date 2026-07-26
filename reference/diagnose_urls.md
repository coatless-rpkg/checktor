# Diagnose URL Issues in Package Files

Flags `http://` URLs (which should almost always be `https://`) and
known URL shortener domains, across DESCRIPTION, README, vignettes and
the `.Rd` files.

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

## Details

This is a fast, **offline** pre-flight. `R CMD check --as-cran` does
fetch every URL and report status codes and redirect targets, but only
with a network and only under `--as-cran`, which is the slow end of the
loop. This catches the two problems you can find without leaving the
room, before you spend ten minutes on a full check.

Literal spans are skipped, so documenting the string `http://` inside
`\verb{}`, `\code{}` or a fenced markdown block is not mistaken for
linking to it.

## Source

No formal rule. Preferring `https://` is good advice, but CRAN's NOTE is
about broken URLs rather than the scheme, which is why this sits at
`opinion` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt",
                                      show_content = FALSE)
issues(diagnose_urls(pkg_path, verbose = FALSE))
#>   file line                                       location    message
#> 1 <NA>   NA DESCRIPTION: http://example.com (use https://) URLs check
```

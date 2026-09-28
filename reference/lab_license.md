# Diagnose the License Field

Flags a `License` that
[`tools::analyze_license()`](https://rdrr.io/r/tools/licensetools.html)
cannot standardize, and a `+ file LICENSE` pointing at a file that does
not exist. For MIT and the BSD licenses it also reads that file as
`R CMD check` does: it must be the stub of `YEAR` and `COPYRIGHT HOLDER`
fields (and `ORGANIZATION` for BSD 3-clause), so the full license text
in its place is reported, as R's "License stub is invalid DCF" NOTE.

## Usage

``` r
lab_license(path = ".", verbose = TRUE, desc = NULL)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

- desc:

  Optional pre-parsed `DESCRIPTION`, as returned by
  [`base::read.dcf()`](https://rdrr.io/r/base/dcf.html). Defaults to
  reading it from `path`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

The [CRAN Repository
Policy](https://cran.r-project.org/web/packages/policies.html) treats an
invalid or unrecognised `License` field as a rejection. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/license_bad.txt",
                                 show_content = FALSE)
lab_license(pkg, verbose = FALSE)$issues
#> [1] "License 'Free to use' is not a standardizable CRAN license"
unlink(pkg, recursive = TRUE)
```

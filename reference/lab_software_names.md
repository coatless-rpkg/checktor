# Diagnose Unquoted Software Names in DESCRIPTION

Flags a package or external-software name in `Title`/`Description` that
is not in single quotes, as Writing R Extensions requires.

## Usage

``` r
lab_software_names(path = ".", verbose = TRUE, desc = NULL)
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

## Details

Each occurrence is judged on its own, so one quoted mention does not
excuse a bare one elsewhere. A name is not bare inside a single-quoted
span such as `'shiny.semantic'`, a `<https://...>` or `<doi:...>`, or a
function call such as
[`purrr::map()`](https://purrr.tidyverse.org/reference/map.html), which
are the spans CRAN's own incoming spell check skips. Nor is it bare in a
plain web address, or in a double-quoted quotation such as the title of
a book. A name alone in double quotes, in either field, is reported by
[`lab_description_quoted_quotes()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_description_quoted_quotes.md)
instead.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
under "The DESCRIPTION file", asks you to "Refer to other packages and
external software in single quotes". See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/software_names_bad.txt",
                                 show_content = FALSE)
lab_software_names(pkg, verbose = FALSE)$issues
#> [1] "Description: ggplot2 should be in single quotes"
unlink(pkg, recursive = TRUE)
```

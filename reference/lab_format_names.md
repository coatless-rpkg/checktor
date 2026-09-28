# Diagnose Bare Format and Markup Names in DESCRIPTION

Flags a data, markup, typesetting or query format name – `JSON`, `HTML`,
`XML`, `CSS`, `YAML`, `TOML`, `Markdown`, `LaTeX`, `TeX` or `SQL` – or
one of the languages CRAN packages write either way (`C++`, `Fortran`,
`Tcl`) that appears in `Title` or `Description` without single quotes.
It runs only when you call it, for a maintainer who wants the quoting
consistent. CRAN accepts these names bare, so a finding here never
counts against a clean result.

## Usage

``` r
lab_format_names(path = ".", verbose = TRUE, desc = NULL)
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

Occurrences are judged as in
[`lab_software_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_software_names.md):
a name inside a quoted longer name such as `'R Markdown'` or
`'JSON-stat'` is quoted, and so is one in a web address or a
double-quoted span. A format name alone in double quotes, such as
`"JSON"`, is therefore reported by no check, by design: double quotes
are the wrong kind for a name, but CRAN accepts the name with no quotes
at all, so
[`lab_description_quoted_quotes()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_description_quoted_quotes.md)
leaves it alone too. A package can extend the list through
`Config/checktor/format_names` in its own DESCRIPTION.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file)
asks for single quotes around "other packages and external software",
and a format is not software. A census of CRAN in September 2026 found
that packages accepted at new-package review in the previous 18 months
wrote these names bare 62% of the time, against 28% for the languages
[`lab_language_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_language_names.md)
covers, so this is a matter of style and sits at `opinion` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_language_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_language_names.md).

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/format_names_bad.txt",
                                 show_content = FALSE)
lab_format_names(pkg, verbose = FALSE)$issues
#> [1] "Title: JSON is not in single quotes"      
#> [2] "Title: YAML is not in single quotes"      
#> [3] "Description: HTML is not in single quotes"
#> [4] "Description: JSON is not in single quotes"
#> [5] "Description: YAML is not in single quotes"
unlink(pkg, recursive = TRUE)
```

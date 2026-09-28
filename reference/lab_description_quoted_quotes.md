# Diagnose Double-Quoted Software Names

Flags a software name in double quotes in `Title` or `Description`.
Writing R Extensions reserves double quotes for quotations and requires
single quotes for software names, so scare-quoted jargon is left alone.
A lower-case span matches only a name written in lower case, such as
`shiny`, so an English `"rust"` or a parameter `"r"` is not read as
`Rust` or `R`. In the `Title`, where Title Case capitalises every word,
a capitalised `"Bugs"` is likewise the word and not `BUGS`.

## Usage

``` r
lab_description_quoted_quotes(path = ".", verbose = TRUE, desc = NULL)
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

The names are those
[`lab_software_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_software_names.md)
and
[`lab_language_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_language_names.md)
ask to see in single quotes, and a few more. Format names such as `JSON`
or `HTML`, which CRAN accepts bare, are not among them, so one in double
quotes is not reported;
[`lab_format_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_format_names.md)
reports them bare, on request.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
under "The DESCRIPTION file", reserves double quotes for book titles and
similar; software names take single quotes. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/description_quoted_quotes_bad.txt",
                                 show_content = FALSE)
lab_description_quoted_quotes(pkg, verbose = FALSE)$issues
#> [1] "Description: \"ggplot2\" is a software name in double quotes (Writing R Extensions reserves double quotes for quotations; use single quotes for software and package names)"
unlink(pkg, recursive = TRUE)
```

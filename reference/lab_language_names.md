# Diagnose Programming-Language Names in DESCRIPTION

Flags a bare programming-language or statistical-computing name –
`Python`, `Java`, `JavaScript`, `Rust`, `MATLAB`, `SAS`, `Stata` and
more – in `Title` or `Description` that CRAN asks to see single-quoted.
This is the language counterpart to
[`lab_software_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_software_names.md):
both are policy-tier quoting checks, kept separate because a language
name and a package name are different kinds of thing. `R` itself is
never flagged in either form. No authority names it, and a bare `R` and
a quoted `'R'` both clear CRAN, so checktor takes no position on which
you write. Single-letter or common-word names (`C`, `Go`, `Swift`) are
left out because they cannot be told from ordinary prose.

## Usage

``` r
lab_language_names(path = ".", verbose = TRUE, desc = NULL)
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

Data, markup and query formats (`JSON`, `HTML`, `YAML`, `SQL`,
`Markdown`, `LaTeX` and the like) and the languages CRAN packages write
either way (`C++`, `Fortran`, `Tcl`) are not flagged here. A census of
CRAN in September 2026 found that packages accepted at new-package
review in the previous 18 months wrote them bare 62% of the time,
against 28% for the languages this check covers, so a bare one is not a
policy finding.
[`lab_format_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_format_names.md)
reports them when you ask.

A package can extend the list through `Config/checktor/language_names`
in its own DESCRIPTION.

Each occurrence is judged on its own, as in
[`lab_software_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_software_names.md):
a term inside a quoted longer name such as `'MATLAB Runtime'` or
`'AWS Python SDK'` is quoted, and so is one in a web address, a
`<doi:...>` or a double-quoted book title.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
under "The DESCRIPTION file", asks for single quotes around other
software; checktor applies the same to programming-language and markup
names. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_software_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_software_names.md),
[`lab_format_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_format_names.md).

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/language_names_bad.txt",
                                 show_content = FALSE)
lab_language_names(pkg, verbose = FALSE)$issues
#> [1] "Description: Python should be in single quotes"
#> [2] "Description: Julia should be in single quotes" 
unlink(pkg, recursive = TRUE)
```

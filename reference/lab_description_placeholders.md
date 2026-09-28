# Diagnose Template Text Left in DESCRIPTION

Flags a `Title`, `Description`, `Author` or `Maintainer` that still
holds the text a package template wrote: the `usethis` template's "What
the Package Does (One Line, Title Case)" and "What the package does (one
paragraph).", and
[`package.skeleton()`](https://rdrr.io/r/utils/package.skeleton.html)'s
"What the Package Does (Short Line)", "More about what it does (maybe
more than one line).", "Who wrote it" and "Who to complain to". It
applies R's own tests, so it flags what CRAN flags. A template
`Authors@R` is
[`lab_authors()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_authors.md)'s
to report.

## Usage

``` r
lab_description_placeholders(path = ".", verbose = TRUE, desc = NULL)
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

The [CRAN incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
run by `R CMD check --as-cran` NOTEs "DESCRIPTION fields with
placeholder content". [Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file)
asks for a `Title` and `Description` that describe the package. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/description_placeholders_bad.txt",
                                 show_content = FALSE)
lab_description_placeholders(pkg, verbose = FALSE)$issues
#> [1] "Title is template text: What the Package Does (One Line, Title Case)"
#> [2] "Description is template text: What the package does (one paragraph)."
unlink(pkg, recursive = TRUE)
```

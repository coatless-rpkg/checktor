# Diagnose Old-Style or Unsafe Calls in inst/CITATION

Flags an `inst/CITATION` that calls the old-style
[`citEntry()`](https://rdrr.io/r/utils/citEntry.html) (use
[`bibentry()`](https://rdrr.io/r/utils/bibentry.html)) or
[`personList()`](https://rdrr.io/r/utils/personList.html) and
[`as.personList()`](https://rdrr.io/r/utils/personList.html) (use
[`c()`](https://rdrr.io/r/base/c.html) on `person` objects), or that
calls
[`packageDescription()`](https://rdrr.io/r/utils/packageDescription.html),
[`library()`](https://rdrr.io/r/base/library.html) or
[`require()`](https://rdrr.io/r/base/library.html). R passes the file a
`meta` object holding the package's DESCRIPTION, so it needs none of
those, and each assumes the package is already installed.

## Usage

``` r
lab_citation_file(path = ".", verbose = TRUE)
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

As in R, the fallback
`if (!exists("meta") || is.null(meta)) meta <- packageDescription("pkg")`
is exempt: a top-level `if` with exactly that condition and no `else`.
The file is parsed and never run, so a name in a comment or a string is
not a call. A CITATION that does not parse is reported, with the line R
stops at. A CITATION that `.Rbuildignore` excludes is not in the tarball
and is not read.

## Source

The [CRAN incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
(`R CMD check --as-cran`) NOTEs "Package CITATION file contains call(s)
to old-style citEntry(). Please use bibentry() instead." and "...
old-style personList() or as.personList(). Please use c() on person
objects instead.", and lists calls to `packageDescription`, `library`
and `require`. [Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#CITATION-files),
under "CITATION files", says "It is desirable (and essential for CRAN)
that the CITATION file does not contain calls to functions such as
packageDescription which assume the package is installed in a library
tree on the package search path." `devtools::check()` turns the incoming
check off by default. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg <- example_diagnose_scenario("general_examples/citation_file_bad.CITATION",
                                 show_content = FALSE)
lab_citation_file(pkg, verbose = FALSE)$issues
#> [1] "inst/CITATION:6 (packageDescription() assumes the package is installed; read the DESCRIPTION from the `meta` object R passes to the file)"
#> [2] "inst/CITATION:8 (citEntry() is old-style; use bibentry())"                                                                                
#> [3] "inst/CITATION:11 (personList() is old-style; use c() on person objects)"                                                                  
unlink(pkg, recursive = TRUE)
```

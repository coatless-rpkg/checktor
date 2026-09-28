# Diagnose a Bibliography R Cannot Read or Install

For a package that cites with R 4.6.0's `\bibcitet{}`, `\bibcitep{}` or
`\bibshow{}` macros, reports a `REFERENCES.bib` whose package, `bibtex`,
is not in `Depends`, `Imports` or `Suggests`, and a `REFERENCES` file
that is not installed because it is outside `inst/` or excluded by
`.Rbuildignore`.

## Usage

``` r
lab_rd_bibliography_files(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Details

R reads the bibliography when it builds the package, wherever it is, so
the package's own pages are fine. But a `.bib` file is read with
`bibtex::read.bib()`, so a build on a machine that installed only the
declared dependencies, as r-universe and `pak` do, has no way to read
it. And R installs only what is in `inst/`, while another package's
`\bibcitet{pkg::key}` looks for the bibliography in the installed
package.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Bibliographic-citations-and-references)
makes the bibliography available as `inst/REFERENCES.R` or
`inst/REFERENCES.bib`, the latter "needs bibtex to be installed". No
check enforces either, so this is `robustness` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_rd_bibliography()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_rd_bibliography.md).

## Examples

``` r
pkg <- example_diagnose_scenario("documentation_examples/rd_bibliography_bad.Rd",
                                 show_content = FALSE)
# Give the page a REFERENCES.bib, without 'bibtex' in Suggests to read it
dir.create(file.path(pkg, "inst"))
writeLines("@book{smith2020, author = {Ann Smith}, title = {Smoothing}, year = {2020}}",
           file.path(pkg, "inst", "REFERENCES.bib"))
lab_rd_bibliography_files(pkg, verbose = FALSE)$issues
#> [1] "inst/REFERENCES.bib: reading it needs 'bibtex', which is not in Imports or Suggests"
unlink(pkg, recursive = TRUE)
```

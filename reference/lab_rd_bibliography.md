# Diagnose Citations Missing From the Bibliography

Reads the `\bibcitet{}`, `\bibcitep{}` and `\bibshow{}` macros R 4.6.0
added to `.Rd` files and reports what `R CMD check` would: a key that no
bibliography holds, which R drops from the page, and a key cited in a
file whose `\bibshow{}` never lists it. A `REFERENCES` file at the top
level of the package is reported too, since `R CMD check --as-cran`
notes it as a non-standard file.

## Usage

``` r
lab_rd_bibliography(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`. It is skipped when R's own
bibliography, which R 4.6.0 added, is not there to look a key up in.

## Details

A key is looked up as R looks it up: in the package's first
`REFERENCES.rds`, `REFERENCES.R` or `REFERENCES.bib`, in the root and
then `inst/`, and in R's own bibliography. A `pkg::key` is looked up in
that package's bibliography when the package is in `Depends`, `Imports`
or `Suggests` and installed here. Nothing is run to read the files: a
key `REFERENCES.R` does not give as a string is not guessed at, and no
key is reported missing from a bibliography that could not be read.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Bibliographic-citations-and-references),
under "Bibliographic citations and references", describes the macros and
says the bibliography is kept in `inst/`. `R CMD check` in R 4.6 warns
"Could not find bibentries for the following keys" and notes "Bibentries
cited but not shown in Rd file", and `--as-cran` notes a "Non-standard
file/directory found at top level". See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_rd_bibliography_files()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_rd_bibliography_files.md).

## Examples

``` r
pkg <- example_diagnose_scenario("documentation_examples/rd_bibliography_bad.Rd",
                                 show_content = FALSE)
lab_rd_bibliography(pkg, verbose = FALSE)$issues
#> [1] "rd_bibliography_bad.Rd:5: no bibentry for 'smith2020'"   
#> [2] "rd_bibliography_bad.Rd: cited but not shown: 'smith2020'"
unlink(pkg, recursive = TRUE)
```

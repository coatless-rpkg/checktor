# Diagnose a Package Nothing Exercises

Flags a package that exports something but ships no `\examples` in any
help page, no tests and no vignettes, so a check runs none of its code.
CRAN's incoming check raises this as a WARNING, which is an automatic
rejection.

## Usage

``` r
lab_code_exercised(path = ".", verbose = TRUE)
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

The conditions are R's own. An example counts even when all of it sits
in `\dontrun{}`, because R still writes it out. A test counts only as a
file directly in `tests/` ending in `.R`, `.r` or `.Rin`, since that is
what `R CMD check` runs: a `tests/testthat/` folder without the
`tests/testthat.R` driver is never run, and the finding says so. Files
`.Rbuildignore` excludes do not count, since they are not in the
tarball. A package with no `R/` directory, or whose `NAMESPACE` exports
nothing, passes. So does one whose `NAMESPACE` is missing or cannot be
parsed, since its exports are then unknown.

## Source

The [CRAN incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
(`R CMD check --as-cran`) reports "checking for code which exercises the
package ... WARNING" with "No examples, no tests, no vignettes" when all
three are missing and the `NAMESPACE` exports anything.
`devtools::check()` turns the incoming check off by default, so the
WARNING is usually first seen at win-builder or on submission. The [CRAN
Repository
Policy](https://cran.r-project.org/web/packages/policies.html) asks that
"the checks that are left do exercise all the features of the package".
See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg <- example_diagnose_scenario("general_examples/code_exercised_bad.R",
                                 show_content = FALSE)
# The scenario's function is exported, as roxygen2 would record it
writeLines("export(tidy_values)", file.path(pkg, "NAMESPACE"))
lab_code_exercised(pkg, verbose = FALSE)$issues
#> [1] "The package exports code but has no examples, no tests and no vignettes, so R CMD check --as-cran WARNs 'No examples, no tests, no vignettes'"
unlink(pkg, recursive = TRUE)
```

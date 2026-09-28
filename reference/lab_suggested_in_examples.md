# Diagnose Suggested Packages Used in Examples Without a Guard

Under CRAN's `noSuggests` check a package must work without its
Suggested packages installed. This flags an example that needs a
Suggested package, through `pkg::`,
[`library()`](https://rdrr.io/r/base/library.html) or
[`require()`](https://rdrr.io/r/base/library.html), in code that runs
without a guard naming that package: an enclosing
`if (requireNamespace("pkg", quietly = TRUE))` or `if (require("pkg"))`,
including roxygen's `@examplesIf` with one of them.
`rlang::is_installed("pkg")` counts too, but it needs rlang, so it is a
use of rlang when rlang is only suggested.

## Usage

``` r
lab_suggested_in_examples(path = ".", verbose = TRUE)
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

The example is read as parsed R, so a package named in a comment or a
string is not a use, and a guard in a comment, a guard for another
package, or one that does not enclose the use excuses nothing. Usage
inside `\dontrun{}` is not flagged, since it never runs. Usage inside
`\donttest{}` is, since `R CMD check --as-cran` runs it. A condition
that is false under R CMD check keeps the use out of the check as surely
as `\dontrun{}` does, so
[`interactive()`](https://rdrr.io/r/base/interactive.html),
`identical(Sys.getenv("IN_PKGDOWN"), "true")`,
`nzchar(Sys.getenv("IN_PKGDOWN"))` and a test that `NOT_CRAN` is
`"true"` excuse it too. A bare `as.logical(Sys.getenv("NOT_CRAN"))` does
not: it is `NA` there, and `if (NA)` stops the example with an error.
R's base packages, such as parallel and tools, and its recommended
packages, such as MASS, Matrix and survival, ship with R and are never
flagged.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Suggested-packages),
under "Suggested packages", asks that a package from `Suggests` used in
an example be guarded so the example still runs without it. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg <- example_diagnose_scenario("documentation_examples/suggested_in_examples_bad.Rd",
                                 show_content = FALSE)
cat("Suggests: somesuggest\n",
    file = file.path(pkg, "DESCRIPTION"), append = TRUE)
lab_suggested_in_examples(pkg, verbose = FALSE)$issues
#> [1] "suggested_in_examples_bad.Rd: uses Suggested package 'somesuggest' in \\examples without a guard"
unlink(pkg, recursive = TRUE)
```

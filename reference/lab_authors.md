# Diagnose the Authors@R Field

Flags a missing `Authors@R`, and an unfilled `usethis` or
[`package.skeleton()`](https://rdrr.io/r/utils/package.skeleton.html)
template such as `person("First", "Last", ...)` or
`person("Givenname", "Familyname", ...)`, which is a hard CRAN rejection
that `R CMD check` says nothing about.

## Usage

``` r
lab_authors(path = ".", verbose = TRUE, desc = NULL)
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

The field is evaluated without running any code it contains: only
[`person()`](https://rdrr.io/r/utils/person.html),
[`as.person()`](https://rdrr.io/r/utils/person.html),
[`c()`](https://rdrr.io/r/base/c.html),
[`list()`](https://rdrr.io/r/base/list.html),
[`paste()`](https://rdrr.io/r/base/paste.html),
[`paste0()`](https://rdrr.io/r/base/paste.html) and `(` resolve, the
calls R's own reader allows from R 4.6.0 on. Every other call in the
field is reported, since `R CMD build` refuses it as a malformed
`Authors@R` field. That includes a namespaced
[`utils::person()`](https://rdrr.io/r/utils/person.html) and a function
in parentheses, as in `(c)(...)`, which are still read so the other
checks see their roles.

## Source

The [CRAN Repository
Policy](https://cran.r-project.org/web/packages/policies.html) treats a
placeholder or malformed `Authors@R`, including a missing maintainer, as
a rejection. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/authors_bad.txt",
                                 show_content = FALSE)
lab_authors(pkg, verbose = FALSE)$issues
#> [1] "Missing Authors@R field"
unlink(pkg, recursive = TRUE)
```

# Diagnose a Missing Copyright Holder

Flags a package that names no copyright holder: no person in `Authors@R`
has the `cph` role and there is no `Copyright` field. It runs only when
you call it: authors who are natural persons hold copyright by default,
so most packages need neither. It is worth running when an organisation
owns the copyright, since that is the case the role exists for.

## Usage

``` r
lab_cph_role(path = ".", verbose = TRUE, desc = NULL)
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

The roles are read from the parsed
[`person()`](https://rdrr.io/r/utils/person.html) object, never from the
text of the field, so an address such as `cph@example.com` is not a
role. The field is parsed without running any code it contains, as in
[`lab_authors()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_authors.md).
A package with no `Authors@R` is read from its legacy `Author` field
instead, where only a role written in square brackets, as in
`ACME Corporation [cph]`, counts, in any case, and not one inside a
parenthesised comment.

## Source

[`utils::person()`](https://rdrr.io/r/utils/person.html) documents
`"cph"` as the role for "all copyright holders", adding that "authors
which are 'natural persons' are by default copyright holders and so do
not need to be given this role". CRAN Repository Policy asks only that
copyright ownership be clear, which a `Copyright` field also satisfies.
See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/cph_role_bad.txt",
                                 show_content = FALSE)
lab_cph_role(pkg, verbose = FALSE)$issues
#> [1] "No [cph] role in Authors@R and no Copyright field"
unlink(pkg, recursive = TRUE)
```

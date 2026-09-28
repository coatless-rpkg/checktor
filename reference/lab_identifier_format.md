# Diagnose Author Identifier Formatting

Validates ORCID and ROR identifiers carried in `Authors@R` person
`comment` fields, mirroring CRAN's `bad_ORCID_iDs` and `bad_ROR_IDs`
incoming checks. ORCID iDs are checked against their checksum, ROR IDs
against their shape.

## Usage

``` r
lab_identifier_format(path = ".", verbose = TRUE, desc = NULL)
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

An `Authors@R` that cannot be read has no identifiers to judge, so the
check is reported as skipped and
[`lab_authors()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_authors.md)
reports the field.

## Source

The [CRAN incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
run by `R CMD check --as-cran` NOTEs a malformed ORCID or ROR identifier
in `Authors@R`. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/identifier_format_bad.txt",
                                 show_content = FALSE)
lab_identifier_format(pkg, verbose = FALSE)$issues
#> [1] "Invalid ORCID iD in Authors@R: 0000-0002-1825-0098"
unlink(pkg, recursive = TRUE)
```

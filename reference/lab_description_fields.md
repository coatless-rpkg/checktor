# Diagnose DESCRIPTION Fields R Does Not Know

Flags a `DESCRIPTION` field that is not one of the fields R knows, which
is how CRAN's incoming check reads it. The usual one is `Remotes`, which
`devtools` and `pak` read but CRAN does not, since CRAN installs
dependencies from CRAN and Bioconductor alone. The others are typos such
as `Bugreports`, `Import`, `Suggest` or `URLs`, which R ignores, so the
field meant is silently missing; the finding names the field that was
probably meant.

## Usage

``` r
lab_description_fields(path = ".", verbose = TRUE, desc = NULL)
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

The fields R allows beyond its own list are allowed here too: any
`Config/` field, such as `Config/testthat/edition`, and fields starting
`X-CRAN`, `X-schema.org`, `Repository/R-Forge` or `VCS/`, and a standard
field name followed by `Note`, such as `RoxygenNote`.

## Source

The [CRAN incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
run by `R CMD check --as-cran` NOTEs "Unknown, possibly misspelled,
fields in DESCRIPTION". The [CRAN Repository
Policy](https://cran.r-project.org/web/packages/policies.html) says "The
strong dependencies ... should be available from CRAN or the
Bioconductor software repository", which is why a `Remotes` field has no
place in a submission. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/description_fields_bad.txt",
                                 show_content = FALSE)
lab_description_fields(pkg, verbose = FALSE)$issues
#> [1] "Import: not a DESCRIPTION field R knows; did you mean Imports?"                                                                      
#> [2] "Bugreports: not a DESCRIPTION field R knows; did you mean BugReports?"                                                               
#> [3] "Remotes: not a DESCRIPTION field R knows; CRAN installs dependencies from CRAN and Bioconductor only, so remove it before submitting"
unlink(pkg, recursive = TRUE)
```

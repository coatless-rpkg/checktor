# Diagnose a Title That Repeats the Package Name

Flags a `Title` that is just the package name, or that opens with the
name followed by a colon, as in `toypkg: Fit Simple Models`. Package
listings already show the name beside the `Title`, so it reads twice.

## Usage

``` r
lab_title_package_name(path = ".", verbose = TRUE, desc = NULL)
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

R's incoming check also NOTEs a `Title` that opens with the name
followed by a space, but that form is left alone here: when the name is
an ordinary word, as in survival's "Survival Analysis", CRAN accepts it
routinely, and over a hundred packages on CRAN carry one. R drops the
NOTE for an update whose `Title` is unchanged since the version on CRAN,
which checktor cannot see offline, so an older package may pass CRAN
with a finding here.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
under "The DESCRIPTION file", says of the `Title`: "Do not repeat the
package name: it is often used prefixed by the name." The [incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
NOTEs "The Title field is just the package name: provide a real title."
and "The Title field starts with the package name.". See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/title_package_name_bad.txt",
                                 show_content = FALSE)
lab_title_package_name(pkg, verbose = FALSE)$issues
#> [1] "Title starts with the package name: toypkg: Fit Simple Models to Data (R drops this NOTE for an update whose Title is unchanged)"
unlink(pkg, recursive = TRUE)
```

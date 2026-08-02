# Diagnose Installs in Examples, Vignettes and Demos

Flags a call that installs a package or external software from an
example, a vignette or a demo. CRAN asks maintainers not to install
anything from these, because a check then has to do the install too, and
the user did not ask for it.

## Usage

``` r
lab_example_installs(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

The CRAN Cookbook covers this under [Installing
Software](https://contributor.r-project.org/cran-cookbook/code_issues.html#installing-software),
and it is a rejection maintainers receive verbatim: "Please do not
install packages in your functions, examples or vignette." See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_software_install()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_software_install.md)
for the same rule in `R/`.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_example_installs(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

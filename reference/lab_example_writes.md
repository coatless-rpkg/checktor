# Diagnose Writes Outside the Temporary Directory in Examples

Flags a write from an example, vignette or demo whose destination is a
literal path, so it lands in the user's filespace rather than in
[`tempdir()`](https://rdrr.io/r/base/tempfile.html). A destination the
caller supplies is permission and is not flagged.

## Usage

``` r
lab_example_writes(path = ".", verbose = TRUE)
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

The CRAN Cookbook covers this under [Writing Files and Directories to
the Home
Filespace](https://contributor.r-project.org/cran-cookbook/code_issues.html#writing-files-and-directories-to-the-home-filespace),
and the rejection reads "Please ensure that your functions do not write
by default or in your examples/vignettes/tests in the user's home
filespace". See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_file_operations()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_file_operations.md)
for the same rule in `R/`.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
lab_example_writes(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

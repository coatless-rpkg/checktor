# Diagnose `T`/`F` Usage in Examples, Vignettes and Demos

Flags a bare `T` or `F` in an example, a vignette chunk that runs, or a
demo, judged exactly as
[`lab_tf_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_tf_usage.md)
judges `R/`: a `T` in a string, a comment, an argument name, `x$T` or
language built by [`quote()`](https://rdrr.io/r/base/substitute.html) is
not reported.

## Usage

``` r
lab_example_tf_usage(path = ".", verbose = TRUE, tests = FALSE)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

- tests:

  Logical. Read `tests/` as well. Default: `FALSE`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

The CRAN Cookbook recipe [T/F Instead of
TRUE/FALSE](https://contributor.r-project.org/cran-cookbook/code_issues.html#tf-instead-of-truefalse)
says `T` and `F` "should not be used as variable names in your code,
examples, tests or vignettes", and the reviewer's letter names the `.Rd`
file: "'T' and 'F' instead of TRUE and FALSE: man/quiet.Rd: quiet(x,
be_quiet = T)". No rule makes it binding, so it sits at `robustness`
tier like
[`lab_tf_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_tf_usage.md).
Tests are left out unless `tests = TRUE`, since CRAN rarely reads them.
See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_tf_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_tf_usage.md)
for the same rule in `R/`.

## Examples

``` r
pkg <- example_diagnose_scenario("documentation_examples/example_tf_usage_bad.Rd",
                                 show_content = FALSE)
lab_example_tf_usage(pkg, verbose = FALSE)$issues
#> [1] "example example_tf_usage_bad.Rd:18"
unlink(pkg, recursive = TRUE)
```

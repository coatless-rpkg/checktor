# Diagnose Print/Cat Usage in Functions

Flags [`print()`](https://rdrr.io/r/base/print.html) /
[`cat()`](https://rdrr.io/r/base/cat.html) calls not guarded by an
enclosing `if()`, `for()`, or `while()`. The check uses the ancestor
axis, so guard detection is robust regardless of formatting. Calls
inside S3 `print.*` and `format.*` methods are exempt, since
[`cat()`](https://rdrr.io/r/base/cat.html) is the required idiom there
(base R's own
[`print.default()`](https://rdrr.io/r/base/print.default.html) /
`print.lm()` use it).

## Usage

``` r
lab_print_cat_usage(path, verbose = TRUE, parsed = NULL)
```

## Arguments

- path:

  Character. Path to package directory.

- verbose:

  Logical. Print diagnostic messages.

- parsed:

  Internal. Pre-parsed source cache; if `NULL`, files are read from
  `path` on demand.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

The CRAN Cookbook covers this under [Using
print()/cat()](https://contributor.r-project.org/cran-cookbook/code_issues.html#using-printcat).
Diagnostic output belongs in
[`message()`](https://rdrr.io/r/base/message.html) or
[`warning()`](https://rdrr.io/r/base/warning.html), which a user can
suppress, rather than in [`cat()`](https://rdrr.io/r/base/cat.html) or
[`print()`](https://rdrr.io/r/base/print.html), which they cannot.
Neither the Repository Policy nor Writing R Extensions states this, but
reviewers ask for it consistently. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/print_cat_bad.R",
                                 show_content = FALSE)
lab_print_cat_usage(pkg, verbose = FALSE)
#> ✖ Print/cat usage check: FAILED
#> Issues found:
#> • print_cat_bad.R:6
#> • print_cat_bad.R:9
#> • print_cat_bad.R:14
#> • print_cat_bad.R:21
#> • print_cat_bad.R:24
#> ... and 1 more
```

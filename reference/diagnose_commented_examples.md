# Diagnose Examples That Run Nothing

Flags an `\examples{}` block whose only content is commented out, so it
demonstrates nothing. A comment beside live code is illustration and is
not flagged.

## Usage

``` r
diagnose_commented_examples(path, verbose = TRUE)
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

No formal rule. An `\examples{}` block that is entirely commented out
demonstrates nothing, a convention which is why this sits at `opinion`
tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_commented_examples(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

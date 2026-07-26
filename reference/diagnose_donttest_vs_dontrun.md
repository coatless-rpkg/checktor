# Diagnose dontrun Where donttest Belongs

Flags `\dontrun{}` around code that is merely slow. `\donttest{}` is the
right wrapper, since it still runs under `--run-donttest`.

## Usage

``` r
diagnose_donttest_vs_dontrun(path, verbose = TRUE)
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

The CRAN Cookbook covers the distinction under [Structuring of
Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples),
where `\donttest{}` is the wrapper for an example that merely runs long.
Nothing enforces the choice, which is why this sits at `opinion` tier.
See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_donttest_vs_dontrun(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

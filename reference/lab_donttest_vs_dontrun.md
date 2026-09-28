# Diagnose dontrun Where donttest Belongs

Flags `\dontrun{}` around code that is merely slow. `\donttest{}` is the
right wrapper, since it still runs under `--run-donttest`.

## Usage

``` r
lab_donttest_vs_dontrun(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Details

A slow block that uses a Suggested package without a guard is left
alone: `R CMD check --as-cran` runs `\donttest{}` code, so after the
move
[`lab_suggested_in_examples()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_suggested_in_examples.md)
would report it. Each `\dontrun{}` block is judged on its own, so such a
block does not hold back the advice for another that is only slow.

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
pkg <- example_diagnose_scenario("documentation_examples/donttest_vs_dontrun_bad.Rd",
                                 show_content = FALSE)
lab_donttest_vs_dontrun(pkg, verbose = FALSE)$issues
#> [1] "donttest_vs_dontrun_bad.Rd: uses \\dontrun{} for slow code; prefer \\donttest{}"
unlink(pkg, recursive = TRUE)
```

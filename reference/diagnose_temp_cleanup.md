# Diagnose Missing Temp-File Cleanup

Flags a temporary file created without a matching cleanup.

## Usage

``` r
diagnose_temp_cleanup(path, verbose = TRUE, parsed = NULL)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

- parsed:

  Optional pre-parsed source, as returned internally by the
  orchestrator. Defaults to parsing `path` afresh.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

The CRAN Cookbook covers this under [Leaving Files in the Temporary
Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#leaving-files-in-the-temporary-directory).
[`tempdir()`](https://rdrr.io/r/base/tempfile.html) is removed at
session end, so an un-[`unlink()`](https://rdrr.io/r/base/unlink.html)ed
tempfile breaks no rule, and tidiness rather than policy is why this
sits at `opinion` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_temp_cleanup(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

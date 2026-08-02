# Diagnose Exported Functions Missing Examples

CRAN expects exported functions to carry a runnable `\examples{}`
section. Walks `.Rd` files via
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html) and reports
exported function topics that lack one. Data, class, methods,
package-level, and re-export topics are skipped, and only topics whose
name appears in NAMESPACE `export()` are considered (so internal helpers
and S3 methods aren't required to have examples). A function that exists
only for its side effect may be reported here even though it is fine, so
use your judgement.

## Usage

``` r
lab_missing_examples(path, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory

- verbose:

  Logical. Print diagnostic messages

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `missing`, `message`.

## Source

The CRAN Cookbook covers examples under [Structuring of
Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples).
Exported functions are expected to carry an `\examples{}` block, a
convention rather than a rule, which is why this sits at `opinion` tier.
See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg_path <- example_diagnose_scenario(
  "documentation_examples/missing_examples_bad.Rd", show_content = FALSE)
writeLines("export(undocumented_fn)", file.path(pkg_path, "NAMESPACE"))
issues(lab_missing_examples(pkg_path, verbose = FALSE))
#> Warning: /tmp/RtmplMUA2o/checktor_example_20260802_002400_2832/man/missing_examples_bad.Rd:5: unexpected section header '\examples'
#>   file line                location                message
#> 1 <NA>   NA missing_examples_bad.Rd Missing examples check
```

# Diagnose Exported Functions Missing Examples

CRAN expects exported functions to carry a runnable `\examples{}`
section. Walks `.Rd` files via
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html) and reports
exported function topics that lack one. Data, class, methods,
package-level, and re-export topics are skipped, and only topics whose
name appears in NAMESPACE `export()` are considered (so internal helpers
and S3 methods aren't required to have examples). Genuinely
side-effect-only functions may be false positives and can be ignored.

## Usage

``` r
diagnose_missing_examples(path, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory

- verbose:

  Logical. Print diagnostic messages

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `missing`, `message`.

## Examples

``` r
pkg_path <- example_diagnose_scenario(
  "documentation_examples/missing_examples_bad.Rd", show_content = FALSE)
writeLines("export(undocumented_fn)", file.path(pkg_path, "NAMESPACE"))
issues(diagnose_missing_examples(pkg_path, verbose = FALSE))
#> Warning: /tmp/RtmpRLX3FP/checktor_example_20260626_200717_5172/man/missing_examples_bad.Rd:5: unexpected section header '\examples'
#>   file line                location                message
#> 1 <NA>   NA missing_examples_bad.Rd Missing examples check
```

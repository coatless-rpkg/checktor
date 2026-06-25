# Diagnose Code Health Issues

Runs comprehensive diagnostics on R source code to identify common CRAN
submission issues and coding best-practice violations.

## Usage

``` r
diagnose_code_issues(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the R package directory. Default: `"."`.

- verbose:

  Logical. Whether to print detailed diagnostic output. Default: `TRUE`.

## Value

List of named
[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
objects (e.g., `tf_usage`, `seed_setting`) plus a `passed` named logical
vector summarizing pass/fail for each sub-check.

## Details

Each source file is parsed once with `parse(keep.source = TRUE)`; checks
run XPath queries against the parsed XML representation, so identifiers
that appear only inside string literals or comments do not
false-positive. Multi-line constructs (`set.seed(\n123\n)`), formula `~`
versus path `~`, and scope-aware patterns (an
[`options()`](https://rdrr.io/r/base/options.html) call guarded by a
sibling [`on.exit()`](https://rdrr.io/r/base/on.exit.html) in the same
function body) are all handled correctly.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
for complete package diagnostics

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
code_results <- diagnose_code_issues(pkg, verbose = FALSE)
code_results$tf_usage$passed
#> [1] FALSE
```

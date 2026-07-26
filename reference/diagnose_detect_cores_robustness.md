# Diagnose Unguarded `detectCores()`

Flags a
[`parallel::detectCores()`](https://rdrr.io/r/parallel/detectCores.html)
call whose result is used without an `NA` guard.

## Usage

``` r
diagnose_detect_cores_robustness(path, verbose = TRUE, parsed = NULL)
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

## Details

`?detectCores` says so in as many words: *"An integer, `NA` if the
answer is unknown"*, and R's own advice is to avoid it, *"First because
it may return `NA`"*. `NA` then propagates silently through the
arithmetic packages usually do next, and the failure surfaces far from
its cause:

    n <- parallel::detectCores() - 1   # NA - 1 is NA
    if (cores > n) cores <- n          # Error: missing value where TRUE/FALSE needed

This is a robustness defect rather than a policy one, and it is distinct
from the `core_usage` check, which asks how many cores you *use*. A
package can cap itself at two cores perfectly and still crash on the
machine where `detectCores()` returns `NA`.

A call is treated as guarded when its enclosing function tests for `NA`
([`is.na()`](https://rdrr.io/r/base/NA.html)), passes `na.rm = TRUE`, or
supplies a fallback with `%||%`. The durable fix is
`parallelly::availableCores()`, which never returns `NA` and also
honours the CRAN core limit.

## Source

No formal rule. `?detectCores` states it returns "`NA` if the answer is
unknown", and the arithmetic that usually follows then crashes, which is
why this sits at `robustness` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_detect_cores_robustness(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

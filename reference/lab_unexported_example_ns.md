# Diagnose Bare Calls to Unexported Functions in Examples

Flags an `\examples{}` block that calls its own topic bare when that
topic is not exported. Examples run with only the package's exports
attached, so the call fails.

## Usage

``` r
lab_unexported_example_ns(path, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory

- verbose:

  Logical. Print diagnostic messages

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Details

`R CMD check` does catch this, but only by RUNNING the examples, which
is late and slow, and it is skipped entirely when examples are wrapped
in `\dontrun{}` or when you check with `--no-examples`. This finds it
statically in a second.

## Source

No formal rule. An example that reaches for an unexported object will
error when it runs, which is why this sits at `robustness` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                      show_content = FALSE)
lab_unexported_example_ns(pkg_path, verbose = FALSE)$passed
#> [1] TRUE
```

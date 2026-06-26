# Diagnose Example Structure

Walks `\examples{}` sections via
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html) and flags
`\dontrun{}` subtrees that don't appear to have a justifying reason
(interactive, network, credentials, long-running, etc.).

## Usage

``` r
diagnose_example_structure(path, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory

- verbose:

  Logical. Print diagnostic messages

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Examples

``` r
pkg_path <- example_diagnose_scenario("network_examples/bad_network_example.Rd",
                                      show_content = FALSE)
diagnose_example_structure(pkg_path, verbose = FALSE)
#> ✔ Example structure check: PASSED
```

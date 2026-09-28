# Diagnose Example Structure

Walks `\examples{}` sections via
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html) and flags
`\dontrun{}` subtrees that don't appear to have a justifying reason
(interactive, network, credentials, long-running, etc.).

## Usage

``` r
lab_example_structure(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory

- verbose:

  Logical. Print diagnostic messages

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

The CRAN Cookbook covers this under [Structuring of
Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples).
`\dontrun{}` should wrap only code that genuinely cannot run inside a
check, a convention rather than a rule, which is why this sits at
`opinion` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg <- example_diagnose_scenario("documentation_examples/example_structure_bad.Rd",
                                 show_content = FALSE)
lab_example_structure(pkg, verbose = FALSE)$issues
#> [1] "example_structure_bad.Rd: potential unnecessary \\dontrun{}"
unlink(pkg, recursive = TRUE)
```

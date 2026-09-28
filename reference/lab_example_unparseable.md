# Diagnose Examples That Are Not Valid R

Flags an `\examples{}` section whose code does not parse as R, reporting
the `.Rd` file and the line the parser stopped on. The code inside
`\dontrun{}` is read too. `R CMD check` writes it out as comments and
never parses it, so a missing bracket or a `<your key>` placeholder
there passes every check.

## Usage

``` r
lab_example_unparseable(path = ".", verbose = TRUE)
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

A rejection CRAN reviewers send verbatim: "Warning: Unexecutable code in
man/make.trait.model.Rd". [Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Documenting-functions),
under "Documenting functions", says example code outside `\dontrun{}`
"must be executable", and that the text inside it "need not be valid R
code". Reviewers run the examples with `\dontrun{}` included all the
same, so a placeholder belongs in a string or a variable, as in
`key <- "<your key>"`. An example that is deliberately not R, such as
C++ source shown for reading, can be turned off with
`Config/checktor/disable`. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_example_structure()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_example_structure.md).

## Examples

``` r
pkg <- example_diagnose_scenario("documentation_examples/example_unparseable_bad.Rd",
                                 show_content = FALSE)
lab_example_unparseable(pkg, verbose = FALSE)$issues
#> [1] "example example_unparseable_bad.Rd:19 (unexpected '<')"
unlink(pkg, recursive = TRUE)
```

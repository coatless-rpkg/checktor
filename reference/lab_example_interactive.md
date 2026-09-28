# Diagnose Interactive Examples Hidden in `\\dontrun{}` or `\\donttest{}`

Flags an interactive call, such as a shiny app, a viewer or a prompt,
that an example hides in `\\dontrun{}` or `\\donttest{}` instead of
guarding with `if (interactive())`.

## Usage

``` r
lab_example_interactive(path = ".", verbose = TRUE)
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

In `\\dontrun{}`, CRAN asks for the guard instead, so a reader can see
that the function needs a session, not only that it does not run. In
`\\donttest{}` the call is a failure waiting to happen:
`R CMD check --as-cran` runs that code, where a prompt errors and an app
waits for input until the check times out.

The example is read as parsed R, so a function named in a comment or a
string is not a call, and only a guard that actually encloses the call
excuses it, including roxygen's `@examplesIf interactive()`. An app that
`shinyApp()` builds is reported only where it is printed, which is what
runs it; kept in a variable or handed to another function, it starts
nothing.

## Source

The CRAN Cookbook covers this under [Structuring of
Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples),
and the rejection reads "Functions which are supposed to only run
interactively (e.g. shiny) should be wrapped in if(interactive()).
Please replace \dontrun with if(interactive()) if possible".
`R CMD check --as-cran` has run `\\donttest{}` examples since R 4.0.0.
See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`lab_example_structure()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_example_structure.md).

## Examples

``` r
pkg <- example_diagnose_scenario("documentation_examples/example_interactive_bad.Rd",
                                 show_content = FALSE)
lab_example_interactive(pkg, verbose = FALSE)$issues
#> [1] "example_interactive_bad.Rd: menu() in \\donttest{} runs under R CMD check --as-cran"
unlink(pkg, recursive = TRUE)
```

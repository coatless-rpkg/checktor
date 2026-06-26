# Diagnose Suggested Packages Used in Examples Without a Guard

Under CRAN's `noSuggests` check a package must work without its
Suggested packages installed. This flags `\examples{}` that load a
Suggested package
([`library()`](https://rdrr.io/r/base/library.html)/[`require()`](https://rdrr.io/r/base/library.html)/`pkg::`)
in code that runs unconditionally and is not guarded by
[`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) /
[`rlang::is_installed()`](https://rlang.r-lib.org/reference/is_installed.html)
(the form `@examplesIf` and `if (requireNamespace(...))` produce). Usage
inside `\dontrun{}` or `\donttest{}` is not flagged.

## Usage

``` r
diagnose_suggested_in_examples(path, verbose = TRUE)
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
pkg_path <- example_diagnose_scenario(
  "documentation_examples/suggested_in_examples_bad.Rd", show_content = FALSE)
cat("Suggests: somesuggest\n",
    file = file.path(pkg_path, "DESCRIPTION"), append = TRUE)
issues(diagnose_suggested_in_examples(pkg_path, verbose = FALSE))
#>   file line
#> 1 <NA>   NA
#>                                                                                           location
#> 1 suggested_in_examples_bad.Rd: uses Suggested package 'somesuggest' in \\examples without a guard
#>                            message
#> 1 Suggested-package examples check
```

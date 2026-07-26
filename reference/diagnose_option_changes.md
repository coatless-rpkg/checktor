# Diagnose Unrestored Option Changes

Flags a call to [`options()`](https://rdrr.io/r/base/options.html),
[`par()`](https://rdrr.io/r/graphics/par.html) or
[`setwd()`](https://rdrr.io/r/base/getwd.html) that changes the user's
session state without restoring it.

## Usage

``` r
diagnose_option_changes(path, verbose = TRUE, parsed = NULL)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

- parsed:

  Optional pre-parsed source, as returned internally by the
  orchestrator. Defaults to parsing `path` afresh.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

The CRAN Cookbook covers this under [Change of Options, Graphical
Parameters and Working
Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory),
which asks that a function restore any
[`options()`](https://rdrr.io/r/base/options.html),
[`par()`](https://rdrr.io/r/graphics/par.html) graphics parameters, or
working directory it changes, using
[`on.exit()`](https://rdrr.io/r/base/on.exit.html). No clause in the
Repository Policy or Writing R Extensions states it, yet it is among the
most common reasons a package is sent back, because a function that
quietly runs `options(digits = 3)` and returns has changed how the rest
of the session behaves. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Exemptions

Two shapes leak nothing and are exempt. A setter that captures the old
value and hands it back, as in `old <- options(...); invisible(old)`,
honours the base R contract and lets the caller restore. And an option
in the package's own namespace, written
`options(<PackageName>.key = ...)`, is the package managing its own
configuration rather than the user's, so a deliberate session preference
like `options(mypkg.threshold = 5)` is fine. If you keep a user setting
for the session, give it a namespaced name rather than a bare global
one, and restore a genuinely temporary change with
`on.exit(options(old))`.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_option_changes(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

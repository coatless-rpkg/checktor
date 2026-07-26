# Diagnose Stale Generated Documentation

Flags a package whose `NAMESPACE` and `man/` no longer match the roxygen
comments they were generated from, i.e. you edited roxygen and forgot to
run `devtools::document()`.

## Usage

``` r
diagnose_roxygen_usage(path, verbose = TRUE)
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

Two signals, both deliberately clock-free:

- A name tagged `@export` in a roxygen block that does not appear in
  `NAMESPACE`. This is the real cost of a forgotten `document()` call:
  the function is not exported, so users cannot call it, and
  `R CMD check` says nothing because a package is free to export
  whatever it likes.

- An `.Rd` file whose roxygen2 backlink names a source file that no
  longer exists, which is the orphan left behind when a source file is
  renamed or deleted without re-documenting.

File modification times are deliberately not used. `git` does not
preserve them, so on a fresh clone every file carries roughly the
checkout time in arbitrary order, and an mtime comparison would pass or
fail at random in CI.

The check is skipped entirely unless `NAMESPACE` carries the roxygen2
"do not edit by hand" banner, so a hand-managed package is never
flagged.

## Source

The CRAN Cookbook covers the roxygen2 side of this under [Repeated
Rejections of Issues in
Manuals](https://contributor.r-project.org/cran-cookbook/docs_issues.html#repeated-rejections-of-issues-in-manuals-if-using-roxygen2),
where documentation is regenerated rather than hand-edited. A function
tagged `@export` that never reached `NAMESPACE` is not actually
exported, and no binding rule names it, which is why this sits at
`robustness` tier. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                      show_content = FALSE)
diagnose_roxygen_usage(pkg_path, verbose = FALSE)$passed
#> [1] TRUE
```

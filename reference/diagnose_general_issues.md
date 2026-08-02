# Diagnose General Package Issues

Runs general diagnostics on package structure and content that don't fit
into specific code, documentation, or DESCRIPTION categories.

## Usage

``` r
diagnose_general_issues(path = ".", verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

## Value

List of
[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
objects plus a `passed` summary.

## Details

This function checks:

- Package size, measured against the files that would go into the
  tarball (`.Rbuildignore` and standard scratch dirs are excluded), with
  a 5 MB warning threshold matching CRAN's recommendation.

- `http://` URLs and URL shorteners, offline. `R CMD check --as-cran`
  does fetch every URL, but only with a network and only under
  `--as-cran`; this is the fast local pass.

- Presence of a `NEWS` file documenting user-facing changes.

- Relative links in the `README` that would break on CRAN.

[`lab_cran_comments_file()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_cran_comments_file.md)
is intentionally not part of this default run, since a
`cran-comments.md` is a workflow convention rather than a CRAN
requirement; call it directly to opt in.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
for complete package diagnostics

## Examples

``` r
pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                      show_content = FALSE)
general_results <- diagnose_general_issues(pkg_path, verbose = FALSE)
general_results$package_size$size_mb
#> [1] 0.0006465912
```

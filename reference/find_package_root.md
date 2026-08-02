# Find the Root of the Package Containing a Path

Walks up from `path` until it finds the directory holding a
`DESCRIPTION` file, so checktor can be run from anywhere inside a
package tree rather than only from the directory holding `DESCRIPTION`.
That is what lets
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
work with your working directory set to `R/`, `tests/testthat/`, or any
other subdirectory.

## Usage

``` r
find_package_root(path = ".")
```

## Arguments

- path:

  Character. A directory inside a package, or a file within one.
  Default: `"."`.

## Value

Character. The package root, as an absolute path, when one is found
above `path`. When `path` itself holds a `DESCRIPTION` it is returned
unchanged, so an existing caller sees exactly what it passed in. When no
package root is found at all, the search falls back to the directory it
started from, meaning `path` for a directory and its parent for a file,
which leaves the caller reporting the problem against the place the user
pointed at.

## Details

Every checktor entry point calls this on the `path` it is given, so you
rarely need it directly. It is exported for custom checks registered
with
[`register_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/register_check.md),
which receive a path that has already been resolved.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which resolves its `path` this way.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)

# From the package root, the path is handed back untouched
identical(find_package_root(pkg), pkg)
#> [1] TRUE

# From a subdirectory, the root is found by walking up
basename(find_package_root(file.path(pkg, "R")))
#> [1] "checktor_example_20260802_002356_3046"
```

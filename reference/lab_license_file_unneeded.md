# Diagnose an Unneeded LICENSE File Pointer

Flags `+ file LICENSE` added to a standard license R knows, such as
`GPL-3 + file LICENSE`, `LGPL-3 + file LICENSE` or
`Apache License 2.0 + file LICENSE`. MIT and the BSD licenses are
templates that need a `LICENSE` file naming the year and copyright
holder, so they are left alone, as is a bare `file LICENSE`. Each
alternative of a dual license such as
`GPL-3 + file LICENSE | MIT + file LICENSE` is judged on its own.

## Usage

``` r
lab_license_file_unneeded(path = ".", verbose = TRUE, desc = NULL)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

- desc:

  Optional pre-parsed `DESCRIPTION`, as returned by
  [`base::read.dcf()`](https://rdrr.io/r/base/dcf.html). Defaults to
  reading it from `path`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Details

A `LICENSE` that adds attribution requirements or other restrictions is
the exception CRAN allows. Explain it in `cran-comments.md` and allow
the finding with `Config/checktor/allow: license_file_unneeded`.

## Source

The CRAN Cookbook's [LICENSE
files](https://contributor.r-project.org/cran-cookbook/description_issues.html#license-files)
recipe gives the reviewers' text: "We do not need \\+ file LICENSE\\ and
the file as these are part of R. This is only needed in case of
attribution requirements or other possible restrictions. Hence please
omit it." R agrees in two places. `R CMD check` NOTEs "License
components with restrictions not permitted" for a license that takes no
extension, such as `GPL (>= 2)` or Apache, and the [incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
NOTEs "License components with restrictions and base license permitting
such" for one that does, such as `GPL-3`. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`lab_license()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_license.md)
for a license R cannot read;
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/license_file_unneeded_bad.txt",
                                 show_content = FALSE)
lab_license_file_unneeded(pkg, verbose = FALSE)$issues
#> [1] "GPL-3 + file LICENSE: GPL-3 is a standard license R knows, so CRAN needs neither '+ file LICENSE' nor the file"
unlink(pkg, recursive = TRUE)
```

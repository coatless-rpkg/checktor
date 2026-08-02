# Diagnose Broken and Redirecting URLs

Fetches every URL in the package, across DESCRIPTION, `.Rd` files and
vignettes, and reports the ones that fail: 404s, other error statuses,
and redirects that ought to point at their final target. This is what
`R CMD check --as-cran` does, through the same base R machinery
([`tools::check_package_urls()`](https://rdrr.io/r/tools/urltools.html)),
so you can see those findings without a full `--as-cran` pass and
without depending on the `urlchecker` package.

## Usage

``` r
lab_url_liveness(path, verbose = TRUE)
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

It runs by default when you are working at the console, since that is
when a broken link is worth knowing about and a pause for the network is
fine. It stays off in scripts, in continuous integration and under
`R CMD check`, where a slow or unreachable network would make results
depend on the machine rather than the package. Set the option either way
to decide for yourself:

    options(checktor.url_check = TRUE)   # always check
    options(checktor.url_check = FALSE)  # never check

Without a network the fetch reports nothing and the check passes
quietly, just as CRAN's own URL check does. For the offline half, which
flags `http://` links and URL shorteners without leaving the room, see
[`lab_urls()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_urls.md).

## Source

The [CRAN incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
run by `R CMD check --as-cran` fetches URLs and NOTEs 404s and
redirects. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## Examples

``` r
# Needs a network, so this is not run automatically:
if (FALSE) { # \dontrun{
lab_url_liveness(".")
} # }
```

# Diagnose Broken and Redirecting URLs (Opt-In, Network)

Fetches every URL in the package – DESCRIPTION, `.Rd` files, and
vignettes – and reports the ones that fail: 404s, other error statuses,
and redirects that ought to point at their final target. This is exactly
what `R CMD check --as-cran` does, through the same base R machinery
([`tools::check_package_urls()`](https://rdrr.io/r/tools/urltools.html));
checktor simply surfaces it as a check so you can run it without a full
`--as-cran` pass and without depending on the `urlchecker` package.

## Usage

``` r
diagnose_url_liveness(path, verbose = TRUE)
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

Because it needs a network and is comparatively slow, it is **opt-in**
and does nothing until you enable it:

    options(checktor.url_check = TRUE)
    checktor(".")

With the option unset – or when the fetch cannot run, such as offline –
it passes quietly, exactly as CRAN's own URL check does without
connectivity. For the fast, offline half (flagging `http://` and URL
shorteners without leaving the room) see
[`diagnose_urls()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_urls.md).

## Examples

``` r
# Opt in first, then run against a package directory (needs a network):
if (FALSE) { # \dontrun{
options(checktor.url_check = TRUE)
diagnose_url_liveness(".")
} # }
```

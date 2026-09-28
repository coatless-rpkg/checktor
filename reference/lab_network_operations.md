# Diagnose Unguarded Network Access

Flags network access in code or examples that runs without a guard.

## Usage

``` r
lab_network_operations(path = ".", verbose = TRUE)
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

An example is read as parsed R, so a function named in a comment, a
string or an Rd `%` comment is not a call. A request counts as guarded
when it sits in `\dontrun{}` or `\donttest{}`, or in the branch of an
`if` whose condition confines it to a connection or a session:
[`curl::has_internet()`](https://jeroen.r-universe.dev/curl/reference/nslookup.html),
`pingr::is_online()`, `capabilities("libcurl")` or
[`interactive()`](https://rdrr.io/r/base/interactive.html), including
roxygen's `@examplesIf` with any of them. Only a guard that encloses the
call excuses it, and a guard kept in a variable counts only when it is
assigned in the same function and on every path to the test. A request
function handed to something that calls it, as in
`lapply(urls, download.file)`, `purrr::map(reqs, httr2::req_perform)`,
`do.call(httr::GET, args)` or `do.call("download.file", args)`, is a
request too, and so is one called through parentheses, as in
`(download.file)(u, f)`, or wrapped by
[`Vectorize()`](https://rdrr.io/r/base/Vectorize.html), `memoise()` or
an adverb such as
[`purrr::possibly()`](https://purrr.tidyverse.org/reference/possibly.html),
which return a function that calls it. Named anywhere else, as in
`args(download.file)` or a mock that redefines it, it is not. Neither is
a helper from a network package that only builds a request, such as
[`curl::form_file()`](https://jeroen.r-universe.dev/curl/reference/multipart.html).

## Source

The [CRAN Repository
Policy](https://cran.r-project.org/web/packages/policies.html) states
that "Packages which use Internet resources should fail gracefully with
an informative message if the resource is not available". See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("network_examples/bad_network_example.Rd",
                                 show_content = FALSE)
lab_network_operations(pkg, verbose = FALSE)$issues
#> [1] "bad_network_example.Rd (unwrapped network call in \\examples)"
unlink(pkg, recursive = TRUE)
```

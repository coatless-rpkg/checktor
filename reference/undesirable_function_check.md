# Flag Every Call to a Named Function

The "flag any call to function X" pattern, checktor's analogue of
`lintr::undesirable_function_linter()`. Member-access calls
(`obj$fn(...)`, `obj@fn(...)`) are excluded, so only a genuine call to
the bare function matches.

## Usage

``` r
undesirable_function_check(parsed, funs, label = TRUE)
```

## Arguments

- parsed:

  A parsed-sources list from
  [`read_r_xml()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/read_r_xml.md).

- funs:

  Character vector of function names to flag.

- label:

  Logical. If `TRUE` (default), each hit is suffixed with the matched
  function name in parentheses.

## Value

A character vector of `"basename:line"` strings.

## See also

[`xpath_lints()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/xpath_lints.md),
[`not_under_fn_with_call_xpath()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/not_under_fn_with_call_xpath.md).

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/browser_calls_bad.R",
                                 show_content = FALSE)
parsed <- read_r_xml(pkg)
undesirable_function_check(parsed, c("browser", "install.packages"))
#> [1] "browser_calls_bad.R:6 (browser())"  "browser_calls_bad.R:11 (browser())"
#> [3] "browser_calls_bad.R:23 (browser())"
```

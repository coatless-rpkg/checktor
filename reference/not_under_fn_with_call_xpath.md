# XPath Predicate: Not Guarded by a Sibling Call

Returns an XPath predicate that restricts matches to nodes whose
innermost enclosing function body does *not* also contain a call to any
of `funs`. This is how a check enforces a guard, for instance that an
[`options()`](https://rdrr.io/r/base/options.html) call is paired with
an [`on.exit()`](https://rdrr.io/r/base/on.exit.html) in the same
function.

## Usage

``` r
not_under_fn_with_call_xpath(funs)
```

## Arguments

- funs:

  Character vector of guard function names (e.g. `"on.exit"`).

## Value

A single character string: an XPath predicate to splice into a query
after a node test.

## Details

The predicate anchors on `ancestor::expr[FUNCTION][1]`, the nearest
function definition, and searches its whole subtree. Anchoring on the
innermost function keeps it correct where the guard belongs to an inner
function rather than an outer one, and covers a call sitting in a
default argument as well as one in the body.

## See also

[`xpath_lints()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/xpath_lints.md).

## Examples

``` r
predicate <- not_under_fn_with_call_xpath(c("on.exit", "local_options"))
paste0("//SYMBOL_FUNCTION_CALL[text() = 'options'][", predicate, "]")
#> [1] "//SYMBOL_FUNCTION_CALL[text() = 'options'][not(ancestor::expr[FUNCTION][1]//SYMBOL_FUNCTION_CALL[text() = 'on.exit' or text() = 'local_options'])]"
```

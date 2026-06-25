# Writing Your Own checktor Checks

``` r

library(checktor)
```

`checktor` ships about thirty diagnostics, but every project has its own
CRAN-style rules that aren’t worth upstreaming. This vignette walks
through the helpers in `R/ast.R` and shows how to author a new check
against the parsed AST in a few lines of XPath.

## The shape of a check

Every diagnostic function follows the same contract:

``` r
diagnose_<name> <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "<message>"))
  }
  # ... XPath logic ...
  checktor_check_result(passed, issues, "<message>")
}
```

The `parsed` argument is an optional parse-cache: when
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
runs all code-side checks together it parses each file once and passes
the cache to every check via this hidden argument, so 11 checks against
a 200-file package mean 200 parses, not 2200.

## Helpers in `R/ast.R`

### `read_r_xml(path)`

Parses every `R/*.R` file in the package and returns a named list of
`list(file, xml, error)`. A parse failure becomes an `error` slot
instead of crashing the run.

``` r

parsed <- read_r_xml(".")
str(parsed[[1]])
#> List of 3
#>  $ file : chr "R/foo.R"
#>  $ xml  : xml_document
#>  $ error: NULL
```

The `xml` slot is an `xml2` document produced by
[`xmlparsedata::xml_parse_data()`](https://rdrr.io/pkg/xmlparsedata/man/xml_parse_data.html).
Every parse-tree token is an XML element with `line1`, `col1`, `line2`,
`col2` attributes.

### `xpath_lints(parsed, xpath, label = NULL)`

Runs an XPath query against every parsed file and returns
`"basename:line"` strings, suitable for assignment to a check result’s
`$issues`. The optional `label` appears in parens after each hit.

``` r

hits <- xpath_lints(parsed,
                    "//SYMBOL_FUNCTION_CALL[text() = 'set.seed']")
#> "foo.R:42" "bar.R:17"
```

### `undesirable_function_check(parsed, funs, label = TRUE)`

The most common pattern — “flag any call to function X” — has a canned
helper:

``` r

issues <- undesirable_function_check(parsed,
                                     c("install.packages", "browser"))
```

This is `checktor`’s equivalent of
`lintr::undesirable_function_linter()`.

### `not_under_fn_with_call_xpath(funs)`

Returns an XPath predicate that restricts hits to nodes whose
*innermost* enclosing function-body doesn’t also contain a call to any
of `funs`. This is how `option_changes` enforces that
[`options()`](https://rdrr.io/r/base/options.html) is guarded by a
sibling [`on.exit()`](https://rdrr.io/r/base/on.exit.html) in the same
function — and the “innermost” part is what makes it correct on nested
functions where `on.exit` in the outer function wouldn’t cover an inner
one.

``` r

predicate <- not_under_fn_with_call_xpath(c("on.exit", "local_options"))
xpath <- paste0(
  "//SYMBOL_FUNCTION_CALL[text() = 'options']",
  "[", predicate, "]"
)
```

### `extract_rd_section(rd, tag)` and `collect_rd_text(node, skip)`

Walking `.Rd` files structurally via
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html):

``` r

rd <- tools::parse_Rd("man/my_fn.Rd")
ex <- extract_rd_section(rd, "\\examples")
collect_rd_text(ex, skip = "\\dontrun")
```

## Walked example: `Sys.setenv()` without cleanup

Suppose we want a check that flags any
[`Sys.setenv()`](https://rdrr.io/r/base/Sys.setenv.html) call whose
enclosing function doesn’t also call `on.exit(Sys.unsetenv(...))` or
[`withr::local_envvar()`](https://withr.r-lib.org/reference/with_envvar.html).
This is the same shape as `diagnose_option_changes` and ships in
checktor as `diagnose_sys_setenv_no_reset`. Here’s the implementation:

``` r

diagnose_sys_setenv_no_reset <- function(path, verbose = TRUE,
                                         parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0),
                                 "Sys.setenv reset check"))
  }
  xpath <- paste0(
    "//SYMBOL_FUNCTION_CALL[text() = 'Sys.setenv'][",
    "  ", not_under_fn_with_call_xpath(c(
        "on.exit",
        "Sys.unsetenv",
        "local_envvar", "with_envvar"
      )),
    "]"
  )
  issues <- xpath_lints(parsed, xpath)
  passed <- length(issues) == 0L
  checktor_check_result(passed, issues, "Sys.setenv reset check")
}
```

Twenty lines. The interesting part is the XPath predicate — everything
else is bookkeeping shared with every other check.

## The xmlparsedata XML, briefly

A call `fn(a, b = 1)` parses to:

``` xml
<expr>                              <!-- call expr -->
  <expr>                            <!-- function-name expr -->
    <SYMBOL_FUNCTION_CALL>fn</SYMBOL_FUNCTION_CALL>
  </expr>
  <OP-LEFT-PAREN>(
  <expr><SYMBOL>a</SYMBOL></expr>   <!-- first positional arg -->
  <OP-COMMA>,
  <SYMBOL_SUB>b</SYMBOL_SUB>        <!-- named-arg name -->
  <EQ_SUB>=</EQ_SUB>
  <expr><NUM_CONST>1</NUM_CONST></expr>  <!-- named-arg value -->
  <OP-RIGHT-PAREN>)
</expr>
```

When you anchor on a `SYMBOL_FUNCTION_CALL`:

- the call expr is `parent::expr/parent::expr`
- the first positional arg is `parent::expr/following-sibling::expr[1]`
- a named-arg name is `parent::expr/parent::expr/SYMBOL_SUB`

A common bug is treating `parent::expr` as the call expr — it’s actually
the function-name wrapper, which has only one child (the
`SYMBOL_FUNCTION_CALL` itself).

## Trying it out

``` r

# Parse a file
parsed <- read_r_xml("path/to/package")

# Find every call to install.packages()
xpath_lints(parsed,
            "//SYMBOL_FUNCTION_CALL[text() = 'install.packages']")
```

To plug a new check into
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
add a `diagnose_<name>` function to the appropriate `R/diagnostics-*.R`
file and add an entry to that file’s
`run_checks(list(...), path, verbose)` call. The orchestrator handles
parse-cache passing, error catching, and `$passed` bookkeeping for you.

## See also

- [Getting Started with
  checktor](https://r-pkg.thecoatlessprofessor.com/checktor/articles/getting-started-with-checktor.md)
  — end-to-end usage from a user’s perspective.
- [`?xmlparsedata::xml_parse_data`](https://rdrr.io/pkg/xmlparsedata/man/xml_parse_data.html)
  and [the lintr docs on writing
  linters](https://lintr.r-lib.org/articles/creating_linters.html) for
  the same patterns at a larger scale.

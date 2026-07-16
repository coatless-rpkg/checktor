# Extract One Section from a Parsed `.Rd` File

Returns the first top-level node of a
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html) result
whose `Rd_tag` matches `tag`, or `NULL` if absent. Use it to reach a
specific section, such as `\\value` or `\\examples`, when writing a
documentation check.

## Usage

``` r
extract_rd_section(rd, tag)
```

## Arguments

- rd:

  A parsed `.Rd` object from
  [`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html).

- tag:

  Character. The `Rd_tag` to find, e.g. `"\\value"` or `"\\examples"`.

## Value

The matching Rd node, or `NULL`.

## See also

[`collect_rd_text()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/collect_rd_text.md).

## Examples

``` r
rd_file <- tempfile(fileext = ".Rd")
writeLines(c("\\name{foo}", "\\title{Foo}", "\\value{A number.}"), rd_file)
rd <- tools::parse_Rd(rd_file)
collect_rd_text(extract_rd_section(rd, "\\value"))
#> [1] "A number."
```

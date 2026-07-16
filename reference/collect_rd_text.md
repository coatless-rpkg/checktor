# Flatten a Parsed `.Rd` Node to Text

Recursively concatenates the text of a
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html) node,
optionally skipping subsections by `Rd_tag` (for instance `"\\dontrun"`
when collecting example code that is meant to run).

## Usage

``` r
collect_rd_text(node, skip = character(0))
```

## Arguments

- node:

  An Rd node, such as one returned by
  [`extract_rd_section()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/extract_rd_section.md).

- skip:

  Character vector of `Rd_tag` values to omit from the text.

## Value

A single character string.

## See also

[`extract_rd_section()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/extract_rd_section.md).

## Examples

``` r
rd_file <- tempfile(fileext = ".Rd")
writeLines(c("\\name{foo}", "\\title{Foo}",
             "\\examples{ f() \\dontrun{ g() } }"), rd_file)
rd <- tools::parse_Rd(rd_file)
collect_rd_text(extract_rd_section(rd, "\\examples"), skip = "\\dontrun")
#> [1] " f()  "
```

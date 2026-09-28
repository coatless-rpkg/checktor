# Diagnose a DESCRIPTION File R Cannot Read

Flags a `DESCRIPTION` that is missing or that R cannot read: a line that
is neither a `Field: value` pair nor an indented continuation, or a
blank line that splits the file in two. `R CMD build` and
`R CMD INSTALL` both stop on such a file, so the package cannot be built
or installed. A `DESCRIPTION` R cannot open at all fails with the
reason, a directory in its place or a file without read permission,
which is found from the file system and so reads the same in any
language. Every other `DESCRIPTION` check reads the parsed fields, so
while this one fails they are reported as skipped.

## Usage

``` r
lab_description_file(path = ".", verbose = TRUE, desc = NULL)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

- desc:

  Present for signature parity with the other DESCRIPTION checks; this
  check asks whether R can read the `DESCRIPTION` file itself, so it
  reads the file and ignores `desc`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Source

[Writing R
Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
under "The DESCRIPTION file", specifies the format of a Debian Control
File: "Fields start with an ASCII name immediately followed by a colon"
and "Continuation lines ... start with a space or tab". R reads it with
[`base::read.dcf()`](https://rdrr.io/r/base/dcf.html) and refuses a file
that yields more than one record. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/unparseable_description.txt",
                                 show_content = FALSE)
lab_description_file(pkg, verbose = FALSE)$issues
#> [1] "DESCRIPTION does not parse: Line starting 'reflowed, so it read ...' is malformed!"
unlink(pkg, recursive = TRUE)
```

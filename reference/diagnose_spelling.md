# Diagnose Possibly Misspelled Words in DESCRIPTION

Spell-checks the `Title` and `Description` fields with
[`utils::aspell()`](https://rdrr.io/r/utils/aspell.html), mirroring the
aspell pass in CRAN's incoming check. It reports only words that are not
already accepted somewhere: a package `.aspell/` dictionary,
`inst/WORDLIST`, or a `Config/checktor/acronyms` or `software_names`
field.

## Usage

``` r
diagnose_spelling(path = ".", verbose = TRUE, desc = NULL)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

- desc:

  Present for signature parity with the other DESCRIPTION checks;
  spelling reads the `DESCRIPTION` file directly and ignores it.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`; the `issues` are the
possibly-misspelled words.

## Details

The check needs a spell-check backend (`aspell` or `hunspell`) on the
system. Without one it passes quietly, the same way CRAN's incoming
check skips spelling when no backend is present, so a run on one machine
may find words a run on another does not. It is therefore an
`opinion`-tier check. When it does fire,
[`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)
hands back a ready-to-paste `.aspell/` snippet with the flagged words
filled in.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
[`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md).

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
diagnose_spelling(pkg, verbose = FALSE)$passed
#> [1] TRUE
```

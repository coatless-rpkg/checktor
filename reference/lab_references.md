# Diagnose Reference Formatting in DESCRIPTION

Flags the links in the `Description` that CRAN's incoming check NOTEs,
applying its own rules to the same wrapped lines R reads:

## Usage

``` r
lab_references(path = ".", verbose = TRUE, desc = NULL)
```

## Arguments

- path:

  Character. Path to the package directory. Default: `"."`.

- verbose:

  Logical. Print diagnostic output. Default: `TRUE`.

- desc:

  Optional pre-parsed `DESCRIPTION`, as returned by
  [`base::read.dcf()`](https://rdrr.io/r/base/dcf.html). Defaults to
  reading it from `path`.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Details

- a URL not enclosed in angle brackets, which should read
  `<https://...>`;

- a DOI not written as `<doi:prefix/suffix>`, such as a
  `https://doi.org/` link, a bare `doi:`, `<doi` with no colon, or
  `<10.xxxx/...>`;

- a publisher link that embeds a DOI, such as
  `<https://onlinelibrary.wiley.com/doi/10.1002/...>`, reported only
  when no DOI is malformed, as R does;

- an arXiv id or link, such as `<arXiv:1509.03700>` or
  `<https://arxiv.org/abs/...>`, which should be the e-print's arXiv
  DOI, `<doi:10.48550/arXiv.1509.03700>`.

It also flags a reference with no closing `>`, which CRAN's page does
not render as a link. Each rule is one finding, quoting every reference
that breaks it. A space after the colon, as in `<doi: 10.1000/xyz>`, is
left alone: R does not NOTE it and CRAN's page links it all the same.

## Source

The [CRAN incoming
check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
run by `R CMD check --as-cran` NOTEs each of the four forms, with
"Please enclose URLs in angle brackets (\<...\>).", "Please write DOIs
as <doi:prefix/suffix>.", "Please use permanent DOI markup for linking
to publications as in <doi:prefix/suffix>." and "Please refer to arXiv
e-prints via their arXiv DOI <doi:10.48550/arXiv.YYMM.NNNNN>.". The
[submission
checklist](https://cran.r-project.org/web/packages/submission_checklist.html)
says "arXiv preprints should be referred to via their arXiv DOI", and
the Cookbook's
[References](https://contributor.r-project.org/cran-cookbook/description_issues.html#references)
recipe asks for "angle brackets for auto-linking". `devtools::check()`
turns the incoming check off, so these usually surface first on
win-builder or at CRAN. See
[`vignette("check-sources", package = "checktor")`](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for how every check maps to its source.

## See also

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
which runs this and every other check.

## Examples

``` r
pkg <- example_diagnose_scenario("description_examples/references_bad.txt",
                                 show_content = FALSE)
lab_references(pkg, verbose = FALSE)$issues
#> [1] "URL not enclosed in angle brackets (<...>): https://colorcet.com"                                                    
#> [2] "DOI not written as <doi:prefix/suffix>: doi:10.1000/xyz123"                                                          
#> [3] "arXiv reference, which CRAN asks to see as its arXiv DOI: <arXiv:1509.03700> (write <doi:10.48550/arXiv.1509.03700>)"
unlink(pkg, recursive = TRUE)
```

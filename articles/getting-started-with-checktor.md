# Getting Started with checktor

## The gap checktor fills

`R CMD check` answers one question well: does this package build and
run? It is silent on the question that actually decides your submission:
will a CRAN volunteer, reading by hand, send it back? Those are
different questions, and the space between them is where afternoons
disappear. A title that isn’t in title case. A missing `\value{}` tag. A
stray `T` where you meant `TRUE`.

`checktor` is the specialist your build refers you to before that
appointment. It runs the extra-CRAN checks that live in the Repository
Policy and reviewers’ long memories but nowhere in the standard
toolchain, and, true to the name, it gives you a checkup, a diagnosis,
and a prescription.

## Installation

`checktor` lives on GitHub for now; once it reaches CRAN you will be
able to `install.packages("checktor")`. Until then, install the
development version:

``` r

# install.packages("pak")
pak::pak("coatless-rpkg/checktor")
```

## A first checkup

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
examines a package directory. So we can watch it work without maiming
your own package, we will point it at a throwaway package built around
one deliberately bad file:

``` r

pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)

results <- checktor(pkg, verbose = FALSE, progress = FALSE)
results
#> ── Package Doctor - Diagnosis Summary ──────────────────────────────────────────
#> Patient: examplepackage
#> Examined: 2026-06-26 20:38:27.785136
#> Doctor version: 0.1.0
#> 
#> CODE ISSUES: 1 failing check
#> DESCRIPTION ISSUES: 3 failing checks
#> DOCUMENTATION ISSUES: HEALTHY
#> GENERAL ISSUES: HEALTHY
#> POLICY ISSUES: HEALTHY
#> 
#> ! Overall health: NEEDS ATTENTION (10 issues)
#> Run `summary()`, `issues()`, or `prescribe()` for details
```

That is the bedside summary: which of the five categories (code,
DESCRIPTION, documentation, general, and CRAN policy) need attention,
and an overall verdict. On your own package the call is just
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md).
For the full catalogue of what each category checks, see the [function
reference](https://r-pkg.thecoatlessprofessor.com/checktor/reference/index.html).

## Reading the results as data

The printed report is for humans. When you want to *compute* on the
findings, filter them, count them, fold them into a report of your own,
reach for the accessors. They return plain data frames, so you never
spelunk through nested lists.

``` r

summary(results)   # one row per category
#>        category checks passed failed issues
#> 1          code     13     12      1      7
#> 2   description     16     13      3      3
#> 3 documentation      8      8      0      0
#> 4       general      4      4      0      0
#> 5        policy      4      4      0      0
```

``` r

issues(results)    # one row per issue, with file and line
#>       category              check           file line
#> 1         code           tf_usage tf_usage_bad.R    8
#> 2         code           tf_usage tf_usage_bad.R   11
#> 3         code           tf_usage tf_usage_bad.R   15
#> 4         code           tf_usage tf_usage_bad.R   18
#> 5         code           tf_usage tf_usage_bad.R   22
#> 6         code           tf_usage tf_usage_bad.R   23
#> 7         code           tf_usage tf_usage_bad.R   26
#> 8  description            license           <NA>   NA
#> 9  description           cph_role           <NA>   NA
#> 10 description description_length           <NA>   NA
#>                                                           location
#> 1                                                 tf_usage_bad.R:8
#> 2                                                tf_usage_bad.R:11
#> 3                                                tf_usage_bad.R:15
#> 4                                                tf_usage_bad.R:18
#> 5                                                tf_usage_bad.R:22
#> 6                                                tf_usage_bad.R:23
#> 7                                                tf_usage_bad.R:26
#> 8  MIT/BSD license requires '+ file LICENSE' for copyright holders
#> 9                Authors@R lacks any [cph] (copyright holder) role
#> 10                    Description too short: 1 sentences, 18 words
#>                     message
#> 1           T/F usage check
#> 2           T/F usage check
#> 3           T/F usage check
#> 4           T/F usage check
#> 5           T/F usage check
#> 6           T/F usage check
#> 7           T/F usage check
#> 8             License check
#> 9            cph role check
#> 10 Description length check
```

`tidy(results)` gives one row per check, passed or not, and
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) is its
alias. Three predicates answer the yes/no questions directly:

``` r

is_healthy(results)
#> [1] FALSE
n_issues(results)
#> [1] 10
failed_checks(results)
#> [1] "code.tf_usage"                  "description.license"           
#> [3] "description.cph_role"           "description.description_length"
```

Each accessor also works on a single category, as in
`issues(results$code_issues)`, or on a single check.

## The one-line gate

For scripts and pre-submission checklists,
[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
collapses the whole diagnosis to a single verdict, `TRUE` when the
package is clean:

``` r

checkup(pkg)
#> [1] FALSE
```

It is built to be the last word in a shell one-liner; the [checktor in
Continuous
Integration](https://r-pkg.thecoatlessprofessor.com/checktor/articles/checktor-in-ci.md)
vignette puts it in charge of a GitHub Actions build.

## From diagnosis to treatment

A diagnosis you cannot act on is just bad news.
[`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)
turns each finding into a concrete remedy:

``` r

prescribe(results)
```

[`health_report()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/health_report.md)
writes the whole consultation to a file, as Markdown, HTML, or plain
text, to keep alongside your `cran-comments.md`:

``` r

health_report(results, file = "package-health.md")
health_report(results, file = "package-health.html", format = "html")
```

## Examining one system at a time

Each category runs on its own, which helps when you are fixing one thing
and would rather not hear about the others:

``` r

diagnose_code_issues()           # just the R sources
diagnose_description_issues()    # just DESCRIPTION
diagnose_documentation_issues()  # just the .Rd files
diagnose_general_issues()        # size, URLs
diagnose_policy_violations()     # CRAN policy
```

## Turning down the volume

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
is chatty by design. In a script, quiet it once and every later call
inherits the setting:

``` r

configure_doctor(verbose_default = FALSE, progress_default = FALSE)

# or per call
results <- checktor(verbose = FALSE, progress = FALSE)
```

## Where it fits

Run `checktor` in the gap between writing code and `R CMD check`:

``` r

devtools::document()
devtools::test()

results <- checktor()  # the extra-CRAN checkup
prescribe(results)     # apply the remedies

devtools::check()      # the standard checks
```

## Conclusion

`checktor` is a checkup, not a cure-all. It complements `R CMD check`
and [`lintr`](https://lintr.r-lib.org) rather than replacing either, and
it cannot replace your judgment about whether a package is worth
submitting. What it does do is the one thing those tools do not: it
remembers the hand-enforced CRAN rules so you do not have to. Run the
three together, treat the printed report as the conversation and the
accessors as the data, and a reviewer should find nothing left to say.
That is the entire point.

## See also

- [checktor in Continuous
  Integration](https://r-pkg.thecoatlessprofessor.com/checktor/articles/checktor-in-ci.md):
  put
  [`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
  in charge of a GitHub Actions build as a quality gate.
- [Writing Your Own
  Checks](https://r-pkg.thecoatlessprofessor.com/checktor/articles/writing-checks.md):
  add project-specific checks against the parsed syntax tree.
- [Function
  reference](https://r-pkg.thecoatlessprofessor.com/checktor/reference/index.html):
  the full catalogue of diagnostics.

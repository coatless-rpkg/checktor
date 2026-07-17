# Getting Started with checktor

## The gap checktor fills

`R CMD check` answers one question well, whether this package builds and
runs. The question that actually decides your submission goes unasked.
Will a CRAN volunteer, reading by hand, send it back? Those are
different questions, and the space between them is where afternoons
disappear. A missing `\value{}` tag. A
[`set.seed()`](https://rdrr.io/r/base/Random.html) left inside a
function. A Description that never grew past one line. Nothing in the
standard toolchain says a word about any of them.

![Seven failure modes against the three tools that might catch them. R
CMD check alone catches undocumented arguments. lintr alone catches a
line over 80 characters, which checktor does not check. Both catch a
bare T, and R CMD check also flags a Title that is not in title case.
The last three rows, a set.seed() left in a function, a one-line
Description, and a missing \value{} tag, are caught only by
checktor.](figures/coverage-light.svg)![](figures/coverage-dark.svg)

`checktor` is the specialist your build refers you to before that
appointment. It runs the extra-CRAN checks that live in the Repository
Policy and reviewers’ long memories but nowhere in the standard
toolchain, and, true to the name, it gives you a checkup, a diagnosis,
and a prescription.

## Installation

For now, `checktor` lives on GitHub. Once it reaches CRAN you will be
able to `install.packages("checktor")`, but until then you install the
development version.

``` r

# install.packages("pak")
pak::pak("coatless-rpkg/checktor")
```

## A first checkup

[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
examines a package directory. So we can watch it work without maiming
your own package, we will point it at a throwaway package built around
one deliberately bad file.

``` r

pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
```

Here is the file it was built around, bad habits and all.

``` r

# Example file showing T/F usage issues

#' Process Data Function
#' @param data A data frame
#' @return Logical indicating success
process_data <- function(data) {
  if (is.null(data)) {
    return(F) # Issue: should be FALSE
  }

  has_complete_cases <- T # Issue: should be TRUE

  if (has_complete_cases) {
    cleaned_data <- data[complete.cases(data), ]
    return(T) # Issue: should be TRUE
  }

  return(F) # Issue: should be FALSE
}

# Another function with T/F issues
validate_input <- function(x, strict = T) {
  # Issue: should be TRUE
  if (length(x) == 0) {
    return(F)
  } # Issue: should be FALSE

  valid <- all(is.numeric(x))
  return(valid && strict == T) # Issue: should be TRUE
}
```

> Left to itself,
> [`example_diagnose_scenario()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/example_diagnose_scenario.md)
> prints that file for you, because `show_content` defaults to `TRUE`.
> We pass `FALSE` and render it above instead, so it arrives as
> highlighted R rather than console output.

Now the checkup itself.

``` r

# verbose and progress are off here, which keeps the printout compact
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
results
#> ── Package Doctor - Diagnosis Summary ──────────────────────────────────────────
#> Patient: examplepackage
#> Examined: 2026-07-17 23:02:07.527278
#> Doctor version: 0.2.0
#> 
#> CODE ISSUES: 1 failing check
#> DESCRIPTION ISSUES: 1 failing check
#> DOCUMENTATION ISSUES: HEALTHY
#> GENERAL ISSUES: HEALTHY
#> POLICY ISSUES: HEALTHY
#> 
#> ! Overall health: NEEDS ATTENTION (7 issues)
#> Run `summary()`, `issues()`, or `prescribe()` for details
```

That bedside summary names which of the five categories (code,
DESCRIPTION, documentation, general, and CRAN policy) need attention,
and gives an overall verdict. For the full catalogue of what each
category checks, see the [function
reference](https://r-pkg.thecoatlessprofessor.com/checktor/reference/index.html).

> **On your own package**, the call is simply
> [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md).
> Run from the package root, it examines everything in place.

## Reading the results as data

The printed report is for humans. When you want to *compute* on the
findings, filter them, count them, fold them into a report of your own,
reach for the accessors. They return plain data frames, so you never
spelunk through nested lists.

![The one checktor_results object fans out into three plain data frames.
summary() gives 5 rows, one per category. issues() gives 10 rows, one
per issue, carrying the file and line. tidy() gives 46 rows, one per
check, whether it passed or
not.](figures/result-shapes-light.svg)![](figures/result-shapes-dark.svg)

``` r

summary(results)   # one row per category
#>        category checks passed failed issues
#> 1          code     15     14      1      7
#> 2   description     18     17      1      1
#> 3 documentation      8      8      0      0
#> 4       general      4      4      0      0
#> 5        policy      4      4      0      0
```

``` r

issues(results)    # one row per issue, with file and line
#>      category    check   severity           file line
#> 1        code tf_usage robustness tf_usage_bad.R    8
#> 2        code tf_usage robustness tf_usage_bad.R   11
#> 3        code tf_usage robustness tf_usage_bad.R   15
#> 4        code tf_usage robustness tf_usage_bad.R   18
#> 5        code tf_usage robustness tf_usage_bad.R   22
#> 6        code tf_usage robustness tf_usage_bad.R   25
#> 7        code tf_usage robustness tf_usage_bad.R   29
#> 8 description cph_role    opinion           <NA>   NA
#>                                            location         message
#> 1                                  tf_usage_bad.R:8 T/F usage check
#> 2                                 tf_usage_bad.R:11 T/F usage check
#> 3                                 tf_usage_bad.R:15 T/F usage check
#> 4                                 tf_usage_bad.R:18 T/F usage check
#> 5                                 tf_usage_bad.R:22 T/F usage check
#> 6                                 tf_usage_bad.R:25 T/F usage check
#> 7                                 tf_usage_bad.R:29 T/F usage check
#> 8 Authors@R lacks any [cph] (copyright holder) role  cph role check
```

`tidy(results)` gives one row per check, passed or not, and
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) is its
alias. Three predicates answer the yes/no questions directly:

``` r

is_healthy(results)
#> [1] FALSE
n_issues(results)
#> [1] 7
failed_checks(results)
#> [1] "code.tf_usage"        "description.cph_role"
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

Built to be the last word in a shell one-liner, it takes charge of a
GitHub Actions build in the [checktor in Continuous
Integration](https://r-pkg.thecoatlessprofessor.com/checktor/articles/checktor-in-ci.md)
vignette.

## From diagnosis to treatment

A diagnosis you cannot act on is just bad news.
[`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)
turns each finding into a concrete remedy, with the before and after
spelled out.

``` r

prescribe(results)
#> ── Treatment Recommendations ───────────────────────────────────────────────────
#> 
#> ── T/F Usage Issues
#> Treatment: Replace `T` with `TRUE` and `F` with `FALSE`
#> # Before
#> result <- T
#> # After
#> result <- TRUE
#> 
#> ── cph role check
#> Issues found:
#> • Authors@R lacks any [cph] (copyright holder) role
#> Treatment: Review the detailed diagnosis above; re-run `checktor(verbose =
#> TRUE)` for specifics.
#> 
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
submitting. What it does do is the one thing those tools do not,
remembering the hand-enforced CRAN rules so you do not have to. Run the
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

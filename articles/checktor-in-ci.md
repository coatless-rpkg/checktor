# checktor in Continuous Integration

## Why bother

`R CMD check` answers one question very well: *does this package build
and run?* It does not answer the question that actually decides your
submission: *will a CRAN volunteer, reading by hand, send it back?*
Those are different questions, and the gap between them is where
afternoons disappear: a title that isn’t in title case, a `\value{}` tag
you forgot, a stray `T` standing in for `TRUE`.

The fix is not vigilance. Vigilance does not survive contact with a
deadline. The fix is to let a machine remember the rules so you don’t
have to, and the natural home for a machine that never forgets is your
continuous integration (CI) pipeline. Run `checktor` there and every
push gets a second opinion for free.

## The one function CI needs

Everything in this article rests on a single function.
[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
runs the full diagnosis and collapses it to one verdict: `TRUE` if the
package is clean, `FALSE` if anything wants attention.

``` r

# A throwaway package that (deliberately) uses T/F instead of TRUE/FALSE
bad_pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R")
#> === Example file: tf_usage_bad.R ===
#> # Example file showing T/F usage issues
#> 
#> #' Process Data Function
#> #' @param data A data frame
#> #' @return Logical indicating success
#> process_data <- function(data) {
#>   if (is.null(data)) {
#>     return(F)  # Issue: should be FALSE
#>   }
#>   
#>   has_complete_cases <- T  # Issue: should be TRUE
#>   
#>   if (has_complete_cases) {
#>     cleaned_data <- data[complete.cases(data), ]
#>     return(T)  # Issue: should be TRUE
#>   }
#>   
#>   return(F)  # Issue: should be FALSE
#> }
#> 
#> # Another function with T/F issues
#> validate_input <- function(x, strict = T) {  # Issue: should be TRUE
#>   if (length(x) == 0) return(F)  # Issue: should be FALSE
#>   
#>   valid <- all(is.numeric(x))
#>   return(valid && strict == T)  # Issue: should be TRUE
#> }
#> 
#> === End of example ===
#> 
#> Temporary package created at: /tmp/Rtmp9ZrB9U/checktor_example_20260626_015344_2254 
#> Example file copied to: /tmp/Rtmp9ZrB9U/checktor_example_20260626_015344_2254/R/tf_usage_bad.R

checkup(bad_pkg)
#> [1] FALSE
```

A healthy package returns `TRUE`. That is the entire contract, and it is
all a build needs to decide whether to go green or red.

## A GitHub Actions job

[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
is designed to be the last word in a shell one-liner. Drop this file in
at `.github/workflows/checktor.yaml` and you have an extra-CRAN gate on
every push and pull request:

``` yaml
name: checktor

on:
  push:
    branches: [main, master]
  pull_request:

jobs:
  checktor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-r@v2
        with:
          use-public-rspm: true

      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: coatless-rpkg/checktor

      - name: Run extra-CRAN checks
        run: if (!checktor::checkup()) quit(status = 1)
        shell: Rscript {0}
```

The job checks out your package, installs `checktor`, and exits non-zero
the moment
[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
disagrees with you. (Once `checktor` is on CRAN, swap the
`extra-packages:` line for `any::checktor`.)

## Failing loudly, not silently

A red X that says only “exit code 1” is a riddle, not a report. When a
build fails, you want the diagnosis in the log, not a scavenger hunt.
Run the full
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
once and print the report before you quit:

``` r

results <- checktor::checktor()

if (results$metadata$total_issues > 0) {
  cat(checktor::health_report(results), sep = "\n")
  quit(status = 1)
}
```

[`health_report()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/health_report.md)
returns the findings as Markdown, so the failing log reads like a chart
at the foot of a hospital bed: what is wrong, and where. Point its
`file =` argument at a path and you can just as easily upload the report
as a build artifact for the squeamish who prefer not to read CI logs.

## Tuning the examination

CI is chatty by nature, so quiet the doctor down.
[`configure_doctor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/configure_doctor.md)
sets the verbosity and progress defaults once, at the top of a script,
and every later call inherits them:

``` r

checktor::configure_doctor(verbose_default = FALSE, progress_default = FALSE)
```

You can also run a single category when that is all you care about,
since each `diagnose_*_issues()` function stands on its own:

``` r

# Gate only on DESCRIPTION-field problems
desc <- checktor::diagnose_description_issues(".")
```

## Closer to the keyboard

CI is the backstop, not the first line. If you would rather hear about a
problem before it reaches a pull request, the same one-liner works as a
local Git pre-commit hook:

``` bash
# .git/hooks/pre-commit  (make it executable: chmod +x)
#!/usr/bin/env bash
Rscript -e 'if (!checktor::checkup()) quit(status = 1)'
```

Now a commit that would have embarrassed you on CRAN never leaves your
laptop.

## The takeaway

`R CMD check` is your build’s physician; `checktor` is the specialist it
refers you to before the operation. Wire
[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
into CI once and the rules stop living in your head, where they were
never safe anyway. The best submission is the one where the reviewer
finds nothing to say — and the surest way there is to have already said
it to yourself.

## See also

- [Getting Started with
  checktor](https://r-pkg.thecoatlessprofessor.com/checktor/articles/getting-started-with-checktor.md)
  — the guided tour of the diagnostics.
- [Writing Your Own
  Checks](https://r-pkg.thecoatlessprofessor.com/checktor/articles/writing-checks.md)
  — add project-specific checks against the parsed AST.

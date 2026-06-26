# checktor in Continuous Integration

## Why bother

You already run `checktor` on your package. The trouble with running it
by hand is that you do it when you remember to, which is not the same as
every time it matters. A pipeline has no such lapses: it runs the check
on every push, for every contributor, whether or not anyone remembered
to.

Moving the check into continuous integration (CI) turns a good habit
into an unconditional one, in about as many lines of YAML as it takes to
describe.

## The one function CI needs

Everything in this article rests on a single function.
[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
runs the full diagnosis and collapses it to one verdict: `TRUE` if the
package is clean, `FALSE` if anything wants attention.

``` r

# A throwaway package that (deliberately) uses T/F instead of TRUE/FALSE
bad_pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                     show_content = FALSE)

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

if (!checktor::is_healthy(results)) {
  writeLines(checktor::health_report(results))
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

Wire
[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
into CI once and the rules stop living in your head, where they were
never safe anyway. The best submission is the one where the reviewer
finds nothing to say, and the surest way there is to have already said
it to yourself, automatically, on every push.

## See also

- [Getting Started with
  checktor](https://r-pkg.thecoatlessprofessor.com/checktor/articles/getting-started-with-checktor.md):
  the guided tour of the diagnostics.
- [Writing Your Own
  Checks](https://r-pkg.thecoatlessprofessor.com/checktor/articles/writing-checks.md):
  add project-specific checks against the parsed syntax tree.

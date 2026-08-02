# Report Findings in the Format Your CI Understands

Renders a
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
result as machine-readable findings, so a build puts each one next to
the line that caused it instead of leaving it in a log for someone to
read. The format defaults to whichever forge the build is running on.

## Usage

``` r
ci_report(
  results = NULL,
  format = c("auto", "github", "gitlab", "checkstyle", "sarif", "azure", "text"),
  file = NULL,
  severity = SEVERITY_LEVELS,
  skipped = TRUE,
  path = "."
)
```

## Arguments

- results:

  A `checktor_results` object. Defaults to running
  [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
  on `path` quietly, so a build can call this on its own.

- format:

  Character. One of `"auto"`, `"github"`, `"gitlab"`, `"checkstyle"`,
  `"sarif"`, `"azure"` or `"text"`. `"auto"` reads the environment
  variables each forge sets.

- file:

  Character. Where to write. Defaults to standard output for the
  comment-style formats and to a conventional file name for the report
  styles.

- severity:

  Character. Which tiers to report. Defaults to every tier, since an
  annotation is information rather than a verdict.

- skipped:

  Logical. Report the checks that did not run. Defaults to `TRUE`, so a
  green pipeline never implies a check that never happened. Named once
  in aggregate rather than one annotation per check.

- path:

  Character. The package to examine when `results` is not supplied.

## Value

Invisibly, the character vector written.

## Details

Each forge reads a different shape, and `format` picks it:

- `"github"` writes workflow commands to standard output, which GitHub
  Actions turns into annotations on the pull request diff. Gitea and
  Forgejo Actions read the same commands.

- `"gitlab"` writes a Code Quality report, which GitLab shows on the
  merge request diff. Name the file in `artifacts:reports:codequality:`.

- `"checkstyle"` writes Checkstyle XML, which Jenkins, reviewdog and
  most review bots read. This is the one to reach for on a forge with no
  format of its own.

- `"sarif"` writes SARIF 2.1.0, which GitHub code scanning and Azure
  ingest.

- `"azure"` writes Azure Pipelines logging commands.

- `"text"` writes one plain line per finding, for a build with no forge
  at all.

Findings carry a file name rather than a path, so the path is recovered
by looking for the file under `R/`, `man/`, `vignettes/` and the other
places a package keeps code. A finding with no location at all, such as
a `DESCRIPTION` field problem, is reported against `DESCRIPTION` so it
still appears.

## See also

[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
for the pass or fail gate,
[`health_report()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/health_report.md)
for a report a person reads.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)

# What a GitHub Actions job would emit
writeLines(head(ci_report(results, format = "github", file = NULL), 3))
#> ::error file=R/tf_usage_bad.R,line=8,title=checktor%3A tf_usage::T/F usage check: tf_usage_bad.R:8
#> ::error file=R/tf_usage_bad.R,line=11,title=checktor%3A tf_usage::T/F usage check: tf_usage_bad.R:11
#> ::error file=R/tf_usage_bad.R,line=15,title=checktor%3A tf_usage::T/F usage check: tf_usage_bad.R:15
#> ::error file=R/tf_usage_bad.R,line=18,title=checktor%3A tf_usage::T/F usage check: tf_usage_bad.R:18
#> ::error file=R/tf_usage_bad.R,line=22,title=checktor%3A tf_usage::T/F usage check: tf_usage_bad.R:22
#> ::error file=R/tf_usage_bad.R,line=25,title=checktor%3A tf_usage::T/F usage check: tf_usage_bad.R:25
#> ::error file=R/tf_usage_bad.R,line=29,title=checktor%3A tf_usage::T/F usage check: tf_usage_bad.R:29
#> ::notice file=DESCRIPTION,line=1,title=checktor%3A cph_role::cph role check: Authors@R lacks any [cph] (copyright holder) role
#> ::notice title=checktor%3A skipped::2 checks did not run: spelling, url_liveness
#> ::error file=R/tf_usage_bad.R,line=8,title=checktor%3A tf_usage::T/F usage check: tf_usage_bad.R:8
#> ::error file=R/tf_usage_bad.R,line=11,title=checktor%3A tf_usage::T/F usage check: tf_usage_bad.R:11
#> ::error file=R/tf_usage_bad.R,line=15,title=checktor%3A tf_usage::T/F usage check: tf_usage_bad.R:15
```

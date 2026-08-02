# What R CMD check Checks

`R CMD check` is a pipeline. It builds your package, installs it, and
then runs roughly fifty separate checks, each of which prints a line
beginning `* checking ...` and ends with a verdict. R itself parses
those lines back out of the log with a single [regular
expression](https://github.com/wch/r-source/blob/trunk/src/library/tools/R/checktools.R),
and this page walks through what each one is actually looking at. The
checks themselves are defined in R’s own `tools` package
([`check.R`](https://github.com/wch/r-source/blob/trunk/src/library/tools/R/check.R)),
and the manual describes the process in [Writing R Extensions, “Checking
packages”](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages).

checktor is deliberately the other half of this story: it runs the
extra-CRAN checks that a human reviewer applies but that `R CMD check`
never will. Knowing exactly where `R CMD check` stops is the fastest way
to see where checktor begins, so this page is a map of the territory
`R CMD check` already covers. For the map of checktor’s own checks, see
[Where the Checks Come
From](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md).

## The four verdicts

Every step ends in one of four states, and only the last three matter.

- `OK` means nothing to report.
- `NOTE` means something a reviewer will likely ask about. A submission
  with NOTEs can still be accepted, but each one needs a reason.
- `WARNING` means a real problem. CRAN will not accept a package with a
  WARNING.
- `ERROR` means the check could not complete, usually because code or a
  test failed outright.

A clean `R CMD check` is the floor for a CRAN submission, not the
ceiling. Many of its steps are structural (“is this a well-formed
package?”) rather than editorial (“is this package good?”), which is
exactly the gap a reviewer fills in, and the gap checktor is built for.

## Packaging and installation

These run first and decide whether the package is even well-formed
enough to install. A failure here stops everything else.

| Step | What it checks |
|----|----|
| `checking for file 'DESCRIPTION'` | The package has a readable `DESCRIPTION` at its root. |
| `checking package namespace information` | `NAMESPACE` exists and parses. |
| `checking package dependencies` | Every package in `Depends`, `Imports`, `LinkingTo`, and `Suggests` is installed and available. |
| `checking if this is a source package` | The tree looks like a source package, not an already-built binary. |
| `checking if there is a namespace` | A `NAMESPACE` file is present. |
| `checking for executable files` | No stray executables are present in the sources. |
| `checking for hidden files and directories` | Flags hidden files (`.foo`) that are usually build detritus. |
| `checking for portable file names` | File names are ASCII, case-insensitively unique, and free of characters that break on other platforms. |
| `checking for sufficient/correct file permissions` | Every file is readable, and nothing is unexpectedly executable. |
| `checking whether package can be installed` | The package installs cleanly with `R CMD INSTALL`; the install log is scanned for warnings. |
| `checking installed package size` | Flags an installed package that is large (a NOTE above ~5 MB). |
| `checking package directory` | The installed layout has the directories R expects. |
| `checking 'build' directory` | The `build/` metadata (from `R CMD build`) is consistent. |
| `checking index information` | `INDEX` and demo/vignette indices are present and consistent. |
| `checking package subdirectories` | Subdirectories are named and cased as R requires, with no empty ones. |
| `checking top-level files` | Only recognised files sit at the package root. |
| `checking for left-over files` | No editor backups or merge-conflict leftovers are present. |

## DESCRIPTION and metadata

| Step | What it checks |
|----|----|
| `checking DESCRIPTION meta-information` | `DESCRIPTION` parses, the `License` is recognised, `Authors@R` is valid, the encoding is declared, and the dependency fields are well-formed. |

## R code

The heart of the static analysis.
`checking R code for possible problems` is R’s own linter (`codetools`),
and it catches a great deal on its own.

| Step | What it checks |
|----|----|
| `checking code files for non-ASCII characters` | R sources are ASCII, or their non-ASCII content is declared. |
| `checking R files for syntax errors` | Every `.R` file parses. |
| `checking whether the package can be loaded` | The package loads without error. |
| `checking whether the package can be loaded with stated dependencies` | It loads using only the declared dependencies, catching an undeclared `Depends`. |
| `checking whether the package can be unloaded cleanly` | Unloading raises no error. |
| `checking whether the namespace can be loaded with stated dependencies` | The namespace imports resolve against the declared dependencies. |
| `checking whether the namespace can be unloaded cleanly` | The namespace unloads without error. |
| `checking use of S3 registration` | S3 methods are registered through `NAMESPACE`, not attached by hand. |
| `checking dependencies in R code` | Every `pkg::fn` and imported symbol traces to a declared dependency. |
| `checking S3 generic/method consistency` | An S3 method’s arguments are compatible with its generic. |
| `checking replacement functions` | A `foo<-` function takes `value` as its final argument. |
| `checking foreign function calls` | `.C`, `.Call`, and friends name registered, correctly-shaped native routines. |
| `checking R code for possible problems` | `codetools` flags undefined globals, unused arguments, questionable `.Internal` use, and similar issues across all R code. |

## Documentation

Everything here works on the `.Rd` files, whether written by hand or
generated by roxygen2.

| Step | What it checks |
|----|----|
| `checking Rd files` | Every `.Rd` file parses and has the required tags. |
| `checking Rd metadata` | `\name` and `\alias` entries are present and unique. |
| `checking Rd line widths` | (`--as-cran`) Flags `\usage` and `\examples` lines wider than 100 characters. |
| `checking Rd cross-references` | Every `\link{}` points at a topic that exists. |
| `checking for missing documentation entries` | Every exported object has a documented `\alias`. |
| `checking for code/documentation mismatches` | Argument names in `\usage`, `\arguments`, and function signatures agree. |
| `checking Rd \usage sections` | Each `\usage` block matches the object it documents. |
| `checking Rd contents` | Flags placeholder or empty sections left in a documentation template. |

## Examples, tests, and vignettes

The dynamic checks: R actually runs your code and fails on any error.

| Step | What it checks |
|----|----|
| `checking for unstated dependencies in examples` | Examples use only declared packages. |
| `checking examples` | Every `\examples{}` block runs without error (`\dontrun{}` is skipped). |
| `checking installed files from 'inst/doc'` | Files under `inst/doc` are consistent with the vignettes. |
| `checking files in 'vignettes'` | The `vignettes/` sources are well-formed. |
| `checking for unstated dependencies in 'tests'` | Tests use only declared packages. |
| `checking tests` | The test suite runs; any failure is an ERROR. |
| `checking for unstated dependencies in vignettes` | Vignettes use only declared packages. |
| `checking package vignettes` | Vignette metadata and index entries are present and consistent. |
| `checking re-building of vignette outputs` | Every vignette rebuilds from source without error. |

## The CRAN incoming checks (`--as-cran`)

With `--as-cran`, the checks people actually mean by “the CRAN checks”
are added. Most of a maintainer’s NOTEs come from the first line here.

| Step | What it checks |
|----|----|
| `checking CRAN incoming feasibility` | The submission-readiness pass: the `Title` case, `Version`, `Date`, `Description`, `Authors@R`, `License`, URLs, and DOIs, plus a spell-check and a look for prior versions and problematic dependencies. |
| `checking for future file timestamps` | No file is dated in the future. |
| `checking serialization versions` | No saved object uses a serialization format newer than the package’s stated R dependency. |

## Cleanup

The last two steps confirm the check itself left nothing behind.

| Step | What it checks |
|----|----|
| `checking for non-standard things in the check directory` | No unexpected files were produced during the check. |
| `checking for detritus in the temp directory` | The package cleaned up after itself in [`tempdir()`](https://rdrr.io/r/base/tempfile.html). |

## Steps you will only see sometimes

Several checks run only when the package has the matching content.

| Step | Runs when |
|----|----|
| `checking contents of 'data' directory` | The package includes a `data/` directory. |
| `checking data for non-ASCII characters` | The package includes data. |
| `checking data for ASCII and uncompressed saves` | The package includes data, and efficient compression is preferred. |
| `checking line endings in ... sources and headers` | The package includes C, C++, or Fortran code. |
| `checking compilation flags in Makevars` | The package includes a `src/Makevars`. |
| `checking compiled code` | The package includes compiled code, and calls to disallowed entry points are reported. |
| `checking PDF version of manual` | The manual is built (skipped by `--no-manual`). |

## Where checktor fits

Read the tables above and a pattern emerges. `R CMD check` asks,
thoroughly, *is this a well-formed package that builds, installs, and
runs?* What it almost never asks is *is this the way a CRAN reviewer
wants it written?* It will not object to a bare `T` in place of `TRUE`,
a [`set.seed()`](https://rdrr.io/r/base/Random.html) buried in a
function, an unquoted package name in the `Title`, an exported function
with no `\value{}` tag, or a one-line `Description`. Those are judgement
calls a human makes, and they are where a passing check and a passing
review part ways.

That gap is checktor’s whole job. It runs the extra-CRAN checks that
live in the Repository Policy and reviewers’ habits but nowhere in
`R CMD check`. Run the two together: `R CMD check` for the structure,
checktor for the review. See [Where the Checks Come
From](https://r-pkg.thecoatlessprofessor.com/checktor/articles/check-sources.md)
for the source and severity behind each one checktor adds.

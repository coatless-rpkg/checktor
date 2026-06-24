# checktor

<!-- badges: start -->
[![CRAN status](https://www.r-pkg.org/badges/version/checktor)](https://CRAN.R-project.org/package=checktor)
[![R-CMD-check](https://github.com/coatless-rpkg/checktor/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/coatless-rpkg/checktor/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

`checktor` runs extra-CRAN diagnostic checks on R packages — catching common
submission issues that `R CMD check` does not flag. It covers code patterns
(`T`/`F` literals, hardcoded `set.seed()`, `options()` without cleanup,
`browser()` calls, raw `system()`/`shell()`, `<<-` to the global environment,
`tempfile()` without cleanup), DESCRIPTION-field issues (title case,
'for R'/'A Toolkit for' anti-patterns, bare `R` in Description, missing
`[cph]` role, software-name quoting, acronym expansion), documentation issues
(missing `\value` tags, unjustified `\dontrun{}`, commented-out examples,
unexported topics that need `pkg:::name()`), and general policy concerns
(package size, `http://` URLs, file writes outside `tempdir()`).

Checks operate on the parsed AST via `xmlparsedata` + `xml2` and on
structured `.Rd` files via `tools::parse_Rd()`, so matches inside string
literals, comments, or Rd macros do not false-positive.

## Installation

```r
# From CRAN (once published)
install.packages("checktor")

# Development version
# install.packages("pak")
pak::pak("coatless-rpkg/checktor")
```

## Usage

```r
library(checktor)

# Run all diagnostics on the current package
results <- checktor()

# Quiet boolean for CI
if (!checkup()) stop("checktor found issues")

# Treatment recommendations for the issues found
prescribe(results)

# Generate a Markdown / HTML / text report
cat(health_report(results, format = "markdown"), sep = "\n")
```

For end-to-end usage, see the
[Getting Started vignette](https://r-pkg.thecoatlessprofessor.com/checktor/articles/getting-started-with-checktor.html).
To author new checks against the parsed AST, see the
[Writing Your Own Checks vignette](https://r-pkg.thecoatlessprofessor.com/checktor/articles/writing-checks.html).

## What it does NOT do

`checktor` complements but does not replace `R CMD check` or
[`lintr`](https://lintr.r-lib.org). Run those alongside `checktor` before
submitting to CRAN.

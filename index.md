# checktor [![checktor website](reference/figures/logo-checktor-light-animated.svg)](https://r-pkg.thecoatlessprofessor.com/checktor/)

`checktor` runs extra-CRAN diagnostic checks on R packages, catching
common submission issues that `R CMD check` does not flag. It looks at
code patterns, DESCRIPTION fields, documentation, and policy concerns:
the kinds of things a reviewer would otherwise catch by hand. It reads
your code, `.Rd` files, and DESCRIPTION the way R does instead of
searching text, so it won’t trip over a pattern that only appears in a
string or a comment.

For the full list of checks, see the [function
reference](https://r-pkg.thecoatlessprofessor.com/checktor/reference/index.html).

## Installation

``` r

# From CRAN (once published)
install.packages("checktor")

# Development version
# install.packages("pak")
pak::pak("coatless-rpkg/checktor")
```

## Usage

``` r

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

For end-to-end usage, see the [Getting Started
vignette](https://r-pkg.thecoatlessprofessor.com/checktor/articles/getting-started-with-checktor.html).
To author new checks against the parsed AST, see the [Writing Your Own
Checks
vignette](https://r-pkg.thecoatlessprofessor.com/checktor/articles/writing-checks.html).

## What it does NOT do

`checktor` complements but does not replace `R CMD check` or
[`lintr`](https://lintr.r-lib.org). Run those alongside `checktor`
before submitting to CRAN.

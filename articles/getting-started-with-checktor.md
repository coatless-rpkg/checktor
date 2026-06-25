# Getting Started with checktor - Your Package Doctor

``` r

library(checktor)
```

## Introduction

`checktor` is the package doctor for R packages heading to CRAN. Like a
medical professional, it examines your package for common ailments and
provides specific treatment recommendations to ensure a healthy CRAN
submission.

The package provides automated diagnostics for CRAN submission issues
that are not caught by standard `R CMD check`, helping you identify and
fix problems before submission.

## Installation

``` r

# Install from GitHub
devtools::install_github("your-username/checktor")
```

## Basic Usage

The main function
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
runs a comprehensive diagnostic on your package:

``` r

library(checktor)

# Examine the current package
results <- checktor()

# Examine a specific package
results <- checktor("path/to/your/package")
```

## Understanding the Doctor’s Report

The package doctor examines four main areas of your package health:

### Code Health Check

Examines your R code for common issues that CRAN reviewers flag:

1.  **T/F Usage**: Using `T` and `F` instead of `TRUE` and `FALSE`
2.  **Seed Setting**: Hardcoded
    [`set.seed()`](https://rdrr.io/r/base/Random.html) calls without
    user control
3.  **Print/Cat Usage**: Unsuppressable console output
4.  **Option Changes**: Changing
    [`options()`](https://rdrr.io/r/base/options.html),
    [`par()`](https://rdrr.io/r/graphics/par.html), or
    [`setwd()`](https://rdrr.io/r/base/getwd.html) without reset
5.  **Home Directory Writing**: Writing files to user’s home directory
6.  **Temp Cleanup**: Not cleaning up temporary files
7.  **GlobalEnv Modification**: Modifying the global environment
8.  **installed.packages()**: Using slow
    [`installed.packages()`](https://rdrr.io/r/utils/installed.packages.html)
    function
9.  **Warn Option**: Setting `options(warn = -1)`
10. **Software Installation**: Installing packages/software in functions
11. **Core Usage**: Using more than 2 CPU cores

### DESCRIPTION File Health Check

Examines your DESCRIPTION file for formatting and content issues:

1.  **Software Names**: Package and software names should be in single
    quotes
2.  **Acronyms**: Unexplained acronyms should be expanded
3.  **License**: Unnecessary LICENSE files for standard licenses
4.  **Title Case**: Title field should be in proper Title Case
5.  **Authors@R**: Modern Authors@R field should be used
6.  **References**: Proper formatting of DOI and URL references
7.  **Description Length**: Description should be adequate length

### Documentation Health Check

Examines your package documentation:

1.  **Value Tags**: Missing `\value` tags in .Rd files
2.  **Roxygen2**: Detection of roxygen2 usage and reminders
3.  **Example Structure**: Appropriate use of `\dontrun`, `\donttest`,
    etc.

### General Health Check

Examines general package structure and content:

1.  **Package Size**: Warning if package exceeds 5MB
2.  **URLs**: Checking for http vs https and redirect issues

## Quick Health Checks

For CI/CD pipelines or quick verification, use the
[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
function:

``` r

# Returns TRUE if healthy, FALSE if issues found
healthy <- checkup()

if (!healthy) {
  stop("Package needs treatment before submission")
}
```

## Getting Treatment Recommendations

When issues are found, get specific treatment advice:

``` r

# Run full diagnosis
results <- checktor()

# Get specific treatment recommendations
prescribe(results)
```

The
[`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)
function provides code examples showing exactly how to fix common
issues.

## Generating Health Reports

Create comprehensive reports for documentation or sharing:

``` r

# Generate markdown report
health_report(results, file = "package-health.md")

# Generate HTML report  
health_report(results, file = "package-health.html", format = "html")

# Generate plain text report
health_report(results, file = "package-health.txt", format = "text")
```

## Specialized Diagnostics

Run specific diagnostic categories independently:

``` r

# Only code health
code_health <- diagnose_code_issues()

# Only DESCRIPTION health
desc_health <- diagnose_description_issues()

# Only documentation health
docs_health <- diagnose_documentation_issues()

# Only general health
general_health <- diagnose_general_issues()

# Additional policy violation checks
policy_health <- diagnose_policy_violations()
```

## Configuration

Customize the package doctor’s behavior:

``` r

# Set global preferences
configure_doctor(
  verbose_default = TRUE,
  progress_default = TRUE, 
  color = TRUE
)

# Use quiet mode for scripts
results <- checktor(verbose = FALSE, progress = FALSE)
```

## Common Treatment Examples

### Fixing T/F Usage

The package doctor commonly finds T/F usage issues:

``` r

# Before treatment - problematic code
result <- T
flag <- F

# After treatment - healthy code
result <- TRUE
flag <- FALSE
```

### Fixing Hardcoded Seeds

Another common issue is hardcoded seeds:

``` r

# Before treatment - problematic code
my_function <- function(data) {
  set.seed(123)  # Hard-coded seed
  sample(data, 10)
}

# After treatment - healthy code
my_function <- function(data, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  sample(data, 10)
}
```

### Fixing Unsuppressable Output

Console output should be suppressable by users:

``` r

# Before treatment - problematic code
my_function <- function(data) {
  print("Processing data...")  # Cannot be suppressed
  process(data)
}

# After treatment - Option 1: Use message()
my_function <- function(data) {
  message("Processing data...")  # Can be suppressed with suppressMessages()
  process(data)
}

# After treatment - Option 2: Add verbose parameter
my_function <- function(data, verbose = TRUE) {
  if (verbose) cat("Processing data...\n")
  process(data)
}
```

### Adding Missing Value Documentation

Documentation should include return value descriptions:

``` r

# Before treatment - missing @return
#' Process Data
#' @param data Input data frame
#' @export
process_data <- function(data) {
  return(processed_data)
}

# After treatment - includes @return
#' Process Data
#' @param data Input data frame
#' @return A processed data frame with cleaned variables
#' @export
process_data <- function(data) {
  return(processed_data)
}
```

## Integration with Development Workflow

Integrate `checktor` into your standard package development process:

``` r

# Standard development workflow
devtools::load_all()
devtools::test()
devtools::document()

# Add health check before R CMD check
checktor()

# Apply any recommended treatments
prescribe(results)

# Run standard checks
devtools::check()

# Final health verification
healthy <- checkup()
if (healthy) {
  message("Package is ready for CRAN submission!")
}

# Build and submit
devtools::build()
```

## CI/CD Integration

Add package health checks to your continuous integration:

``` yaml
# Example GitHub Actions workflow
name: Package Health Check
on: [push, pull_request]
jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: r-lib/actions/setup-r@v2
      - name: Install checktor
        run: remotes::install_github('your-username/checktor')
        shell: Rscript {0}
      - name: Run health check
        run: |
          library(checktor)
          if (!checkup()) {
            stop('Package health check failed')
          }
        shell: Rscript {0}
```

## Understanding the Output

The package doctor uses clear, medical-themed language and formatting:

- **Clean bill of health**: No issues found
- **Requires treatment**: Issues that need fixing
- **Treatment recommendations**: Specific guidance on fixes
- **Diagnosis summary**: Overview of package health

All output avoids medical emojis and uses professional, accessible
language suitable for both beginners and experienced developers.

## When to Use checktor

Use `checktor` as part of your pre-submission checklist:

1.  **Before initial CRAN submission**: Catch common issues early
2.  **After major code changes**: Ensure no new issues introduced  
3.  **In CI/CD pipelines**: Automated quality gates
4.  **For package reviews**: Generate health reports for collaborators
5.  **Learning tool**: Understand CRAN requirements better

## Limitations

`checktor` focuses on common, automatable checks. It does not replace:

- Manual code review
- Domain-specific validation
- Performance testing
- Standard `R CMD check`
- Human judgment about package design

Always run both `checktor` and `R CMD check` before CRAN submission.

## Contributing

Found a new CRAN diagnostic that should be included? The package is
designed to be easily extensible. Please open an issue or submit a pull
request!

## Resources

For more comprehensive information about CRAN submissions:

- [Writing R
  Extensions](https://cran.r-project.org/doc/manuals/R-exts.html)
- [CRAN Repository
  Policy](https://cran.r-project.org/web/packages/policies.html)
- [CRAN Cookbook](https://contributor.r-project.org/cran-cookbook/)
- [R Packages book](https://r-pkgs.org/)

The package doctor is here to help keep your package healthy and ready
for CRAN!

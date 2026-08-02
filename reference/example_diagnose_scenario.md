# Create Example Diagnostic Scenario

Creates a temporary package structure with a specified example file for
testing diagnostic functions. This is primarily used in documentation
examples to demonstrate diagnostic capabilities with known problematic
code.

## Usage

``` r
example_diagnose_scenario(
  example_path,
  show_content = TRUE,
  description_type = "minimal",
  cleanup = FALSE
)
```

## Arguments

- example_path:

  Character. Relative path to example file within inst/diagnose/. Should
  include subdirectory and filename (e.g.,
  "code_examples/tf_usage_bad.R").

- show_content:

  Logical. Whether to display the example file content in the console.
  Default: `TRUE`.

- description_type:

  Character. Type of DESCRIPTION file to create. Options: "minimal"
  (basic fields only), "bad" (with known issues), "good" (properly
  formatted). Default: "minimal".

- cleanup:

  Logical. Whether to register cleanup of temporary directory on exit.
  Default: `FALSE` (user manages cleanup).

## Value

Character. Path to the temporary package directory containing the
example file. Returns `NULL` if the example file cannot be found.

## Details

This function:

1.  Locates the specified example file in the package's `inst/diagnose/`
    directory

2.  Creates a temporary package directory structure

3.  Copies the example file to the appropriate location

4.  Optionally displays the example file content

5.  Returns the path to the temporary package for diagnostic testing

The temporary package includes minimal structure (`R/`, `man/`, etc.)
needed for running diagnostics, plus a basic `DESCRIPTION` file.

## Example File Structure

The temporary package created has this structure:

    /tmp/checktor_example_XXXX/
    |-- DESCRIPTION          # Basic or custom DESCRIPTION file
    |-- R/                   # Contains copied example R files
    |   `-- example.R        # The example file with issues
    |-- man/                 # Empty directory for .Rd files
    `-- tests/               # Empty directory for test files

## See also

Used in examples for diagnostic functions like
[`lab_tf_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_tf_usage.md),
[`lab_seed_setting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_seed_setting.md),
etc.

## Examples

``` r
# Create scenario with T/F usage issues
pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R")
#> === Example file: tf_usage_bad.R ===
#> # Example file showing T/F usage issues
#> 
#> #' Process Data Function
#> #' @param data A data frame
#> #' @return Logical indicating success
#> process_data <- function(data) {
#>   if (is.null(data)) {
#>     return(F) # Issue: should be FALSE
#>   }
#> 
#>   has_complete_cases <- T # Issue: should be TRUE
#> 
#>   if (has_complete_cases) {
#>     cleaned_data <- data[complete.cases(data), ]
#>     return(T) # Issue: should be TRUE
#>   }
#> 
#>   return(F) # Issue: should be FALSE
#> }
#> 
#> # Another function with T/F issues
#> validate_input <- function(x, strict = T) {
#>   # Issue: should be TRUE
#>   if (length(x) == 0) {
#>     return(F)
#>   } # Issue: should be FALSE
#> 
#>   valid <- all(is.numeric(x))
#>   return(valid && strict == T) # Issue: should be TRUE
#> }
#> 
#> === End of example ===
#> 
result <- lab_tf_usage(pkg_path, verbose = TRUE)
#> ✖ Found `T`/`F` usage (should use `TRUE`/`FALSE`)
#> • tf_usage_bad.R:8
#> • tf_usage_bad.R:11
#> • tf_usage_bad.R:15
#> • tf_usage_bad.R:18
#> • tf_usage_bad.R:22
#> ... and 2 more
issues(checktor(pkg_path, verbose = FALSE, progress = FALSE))
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

# Create scenario without showing file content
pkg_path <- example_diagnose_scenario("code_examples/seed_setting_bad.R",
                                      show_content = FALSE)

# Create scenario with problematic DESCRIPTION file
pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt",
                                      description_type = "bad")
#> === Example file: bad_description.txt ===
#> Package: badexample
#> Title: example package for data analysis
#> Version: 0.1.0
#> Author: John Doe <john@example.com>
#> Maintainer: John Doe <john@example.com>
#> Description: This package works with ggplot2 and provides API access.
#>     It uses ML algorithms for data processing.
#> License: MIT + file LICENSE
#> Encoding: UTF-8
#> URL: http://example.com
#> BugReports: https://github.com/user/pkg/issues
#> 
#> === End of example ===
#> 
desc_result <- diagnose_description_issues(pkg_path)
#> 
#> ── DESCRIPTION File Health Check ──
#> 
#> ! Potential software name formatting issues
#> • Description: ggplot2 should be in single quotes
#> ✔ Programming-language names appear properly formatted
#> ! Potential unexplained acronyms: "ML"
#> Treatment: Consider explaining these acronyms
#> ✖ License field problems
#> • License points at a LICENSE file that does not exist
#> Treatment: Use a standardizable license, and add '+ file LICENSE' for MIT/BSD
#> ! Title is not in title case
#> • Title is not in title case. R would write it as: Example Package for Data
#> Analysis
#> Treatment: Use the capitalisation tools::toTitleCase() proposes
#> ✔ Title fits the 65 characters a listing may truncate to
#> ✔ Title is free of redundant phrases
#> ✖ Problems in the author fields
#> • Missing Authors@R field
#> Treatment: Add Authors@R, replace any usethis template placeholder with the
#> real name and email, and give every person a name and role with one maintainer
#> (cre)
#> ✔ Author identifiers are well formed
#> ℹ No references found in Description
#> ✔ Date field is absent or current
#> ✔ Encoding is portable or unset
#> ✔ Version is well formed
#> ✔ Description length appears adequate
#> ! Description opening needs work
#> • Description should not start with "This package"; describe what it does
#> instead
#> Treatment: Start with a capital letter and say what the package does

# Manual cleanup when done
unlink(pkg_path, recursive = TRUE)

# Or use with automatic cleanup
pkg_path <- example_diagnose_scenario("code_examples/browser_calls_bad.R",
                                      cleanup = TRUE)
#> === Example file: browser_calls_bad.R ===
#> # Example file showing browser() calls (debugging code)
#> 
#> #' Debug Function
#> #' @param data Input data
#> debug_function <- function(data) {
#>   browser() # Issue: debugging call left in code
#> 
#>   processed <- process_data(data)
#> 
#>   if (is.null(processed)) {
#>     browser() # Issue: another debugging call
#>     stop("Processing failed")
#>   }
#> 
#>   return(processed)
#> }
#> 
#> #' Analysis with Debug
#> analyze_with_debug <- function(x) {
#>   result <- mean(x, na.rm = TRUE)
#> 
#>   if (is.na(result)) {
#>     browser() # Issue: debugging call for troubleshooting
#>   }
#> 
#>   return(result)
#> }
#> 
#> === End of example ===
#> 
# Cleanup happens automatically when R session ends
```

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
[`diagnose_tf_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_tf_usage.md),
[`diagnose_seed_setting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_seed_setting.md),
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
#> Temporary package created at: /tmp/RtmpayGnSR/checktor_example_20260626_041508_9943 
#> Example file copied to: /tmp/RtmpayGnSR/checktor_example_20260626_041508_9943/R/tf_usage_bad.R 
#> 
result <- diagnose_tf_usage(pkg_path, verbose = TRUE)
#> ✖ Found `T`/`F` usage (should use `TRUE`/`FALSE`)
#> • tf_usage_bad.R:8
#> • tf_usage_bad.R:11
#> • tf_usage_bad.R:15
#> • tf_usage_bad.R:18
#> • tf_usage_bad.R:22
#> ... and 2 more
issues(checktor(pkg_path, verbose = FALSE, progress = FALSE))
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
#> Temporary package created at: /tmp/RtmpayGnSR/checktor_example_20260626_041508_2022 
#> Example file copied to: /tmp/RtmpayGnSR/checktor_example_20260626_041508_2022/DESCRIPTION 
#> 
desc_result <- diagnose_description_issues(pkg_path)
#> 
#> ── DESCRIPTION File Health Check ──
#> 
#> ! Potential software name formatting issues
#> • Description: ggplot2 should be in single quotes
#> ! Potential unexplained acronyms: "ML"
#> Treatment: Consider explaining these acronyms
#> ! License formatting issues
#> • License declares '+ file LICENSE' but no LICENSE file found
#> ! Potential Title Case issues
#> • First word should be capitalized: example
#> • Word should be capitalized: package
#> • Word should be capitalized: data
#> • Word should be capitalized: analysis
#> ✔ Title does not start with an article
#> ✔ Title is free of redundant phrases
#> ! No `Authors@R` field found
#> Legacy Author/Maintainer fields detected
#> Treatment: Consider adding Authors@R field
#> ℹ No references found in Description
#> ! Description may be too short: 2 sentences, 16 words
#> Treatment: Consider expanding to 2+ sentences, 20+ words
#> ! Description starts with a CRAN-forbidden phrase
#> • Description starts with forbidden phrase: 'This package'
#> Treatment: Rephrase so Description leads with what the package does
#> ✔ Description quotes 'R' properly

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
#>   browser()  # Issue: debugging call left in code
#>   
#>   processed <- process_data(data)
#>   
#>   if (is.null(processed)) {
#>     browser()  # Issue: another debugging call
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
#>     browser()  # Issue: debugging call for troubleshooting
#>   }
#>   
#>   return(result)
#> }
#> 
#> === End of example ===
#> 
#> Temporary package created at: /tmp/RtmpayGnSR/checktor_example_20260626_041509_2289 
#> Example file copied to: /tmp/RtmpayGnSR/checktor_example_20260626_041509_2289/R/browser_calls_bad.R 
#> 
# Cleanup happens automatically when R session ends
```

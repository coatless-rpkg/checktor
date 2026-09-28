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
  formatted). Default: "minimal". Ignored when `example_path` is a
  `.txt` scenario, which becomes the `DESCRIPTION` itself.

- cleanup:

  Logical. Whether to delete the temporary package when the function
  that called `example_diagnose_scenario()` returns. Called at top level
  there is no such function, so the package stays until R removes the
  session's temporary directory. Default: `FALSE` (you manage cleanup).

## Value

Character. Path to the temporary package directory containing the
example file. Returns `NULL`, with a warning, if the example file cannot
be found. An `example_path` that is not an `.R`, `.Rd`, `.Rmd`, `.qmd`,
`.Rnw`, `.txt`, `.CITATION` or `.LICENSE` file is an error, since a
package has no place for it.

## Details

This function:

1.  Locates the specified example file in the package's `inst/diagnose/`
    directory

2.  Creates a temporary package directory structure

3.  Copies the example file to where a package keeps its kind: an `.R`
    file in `R/`, an `.Rd` file in `man/`, a vignette (`.Rmd`, `.qmd`,
    `.Rnw`) in `vignettes/`, a DESCRIPTION scenario (`.txt`) as the
    `DESCRIPTION`, a citation scenario (`.CITATION`) as `inst/CITATION`,
    and a licence scenario (`.LICENSE`) as `LICENSE`

4.  Optionally displays the example file content

5.  Returns the path to the temporary package for diagnostic testing

The temporary package includes minimal structure (`R/`, `man/`, etc.)
needed for running diagnostics, plus a basic `DESCRIPTION` file.

## Example File Structure

The temporary package created has this structure. The example file goes
in the one place its extension names, and the other directories stay
empty:

    <tempdir>/checktor_example_XXXX/
    |-- DESCRIPTION          # The template, or a .txt scenario itself
    |-- LICENSE              # A .LICENSE scenario; made only for one
    |-- NEWS.md              # So the NEWS check has nothing to report
    |-- cran-comments.md     # So the cran-comments check has nothing to report
    |-- R/                   # An .R scenario, such as tf_usage_bad.R
    |-- man/                 # An .Rd scenario, such as missing_value_tag.Rd
    |-- inst/CITATION        # A .CITATION scenario; made only for one
    |-- tests/               # Always empty
    `-- vignettes/           # An .Rmd, .qmd or .Rnw scenario; made only for one

## See also

Used in examples for diagnostic functions like
[`lab_tf_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_tf_usage.md),
[`lab_seed_setting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_seed_setting.md),
etc.

## Examples

``` r
# A scenario with T/F usage issues. show_content defaults to TRUE, so the
# offending file prints first
pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R")
#> ── Example file: tf_usage_bad.R ────────────────────────────────────────────────
#> # Example file showing T/F usage issues
#> #' Process Data Function
#> #' @param data A data frame
#> #' @return Logical indicating success
#> process_data <- function(data) {
#>   if (is.null(data)) {
#>     return(F) # Issue: should be FALSE
#>   }
#>   has_complete_cases <- T # Issue: should be TRUE
#>   if (has_complete_cases) {
#>     cleaned_data <- data[complete.cases(data), ]
#>     return(T) # Issue: should be TRUE
#>   }
#>   return(F) # Issue: should be FALSE
#> }
#> # Another function with T/F issues
#> validate_input <- function(x, strict = T) {
#>   # Issue: should be TRUE
#>   if (length(x) == 0) {
#>     return(F)
#>   } # Issue: should be FALSE
#>   valid <- all(is.numeric(x))
#>   return(valid && strict == T) # Issue: should be TRUE
#> }
#> ── End of example ──────────────────────────────────────────────────────────────
lab_tf_usage(pkg_path, verbose = FALSE)$issues
#> [1] "tf_usage_bad.R:8"  "tf_usage_bad.R:11" "tf_usage_bad.R:15"
#> [4] "tf_usage_bad.R:18" "tf_usage_bad.R:22" "tf_usage_bad.R:25"
#> [7] "tf_usage_bad.R:29"
issues(checktor(pkg_path, verbose = FALSE, progress = FALSE))
#>   category    check   severity           file line          location
#> 1     code tf_usage robustness tf_usage_bad.R    8  tf_usage_bad.R:8
#> 2     code tf_usage robustness tf_usage_bad.R   11 tf_usage_bad.R:11
#> 3     code tf_usage robustness tf_usage_bad.R   15 tf_usage_bad.R:15
#> 4     code tf_usage robustness tf_usage_bad.R   18 tf_usage_bad.R:18
#> 5     code tf_usage robustness tf_usage_bad.R   22 tf_usage_bad.R:22
#> 6     code tf_usage robustness tf_usage_bad.R   25 tf_usage_bad.R:25
#> 7     code tf_usage robustness tf_usage_bad.R   29 tf_usage_bad.R:29
#>           message
#> 1 T/F usage check
#> 2 T/F usage check
#> 3 T/F usage check
#> 4 T/F usage check
#> 5 T/F usage check
#> 6 T/F usage check
#> 7 T/F usage check
unlink(pkg_path, recursive = TRUE)

# A .txt scenario is the DESCRIPTION, so it needs no description_type
pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt",
                                      show_content = FALSE)
issues(diagnose_description_issues(pkg_path, verbose = FALSE))
#>                     check severity file line
#> 1          software_names   policy <NA>   NA
#> 2                acronyms  opinion <NA>   NA
#> 3                 license   policy <NA>   NA
#> 4              title_case   policy <NA>   NA
#> 5                 authors   policy <NA>   NA
#> 6 description_starts_with   policy <NA>   NA
#>                                                                             location
#> 1                                    Description: ggplot2 should be in single quotes
#> 2                                                                                 ML
#> 3                               License points at a LICENSE file that does not exist
#> 4 Title is not in title case. R would write it as: Example Package for Data Analysis
#> 5                                                            Missing Authors@R field
#> 6    Description should not start with "This package"; describe what it does instead
#>                     message
#> 1      Software names check
#> 2            Acronyms check
#> 3             License check
#> 4          Title case check
#> 5     Authors@R field check
#> 6 Description opening check
unlink(pkg_path, recursive = TRUE)

# With cleanup = TRUE the package is deleted when the calling function returns
count_tf <- function() {
  pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                        show_content = FALSE, cleanup = TRUE)
  length(lab_tf_usage(pkg_path, verbose = FALSE)$issues)
}
count_tf()
#> [1] 7
```

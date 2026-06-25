# Show Available Example Files

Lists all available example files in the `inst/diagnose/` directory that
can be used with
[`example_diagnose_scenario()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/example_diagnose_scenario.md).

## Usage

``` r
show_example_files(category = "all", pattern = NULL)
```

## Arguments

- category:

  Character. Optional category filter. One of "code", "description",
  "documentation", "network", "temp", or "all". Default: "all".

- pattern:

  Character. Optional regex pattern to filter filenames. Default: `NULL`
  (no filtering).

## Value

Character vector of relative paths to example files that can be used
with
[`example_diagnose_scenario()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/example_diagnose_scenario.md).

## See also

[`example_diagnose_scenario()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/example_diagnose_scenario.md)
to create test scenarios with these files

## Examples

``` r
# List all available examples
show_example_files()
#>  [1] "code_examples/browser_calls_bad.R"           
#>  [2] "code_examples/core_usage_bad.R"              
#>  [3] "code_examples/globalenv_bad.R"               
#>  [4] "code_examples/option_changes_bad.R"          
#>  [5] "code_examples/print_cat_bad.R"               
#>  [6] "code_examples/seed_setting_bad.R"            
#>  [7] "code_examples/tf_usage_bad.R"                
#>  [8] "description_examples/bad_description.txt"    
#>  [9] "description_examples/good_description.txt"   
#> [10] "documentation_examples/good_documentation.Rd"
#> [11] "documentation_examples/missing_value_tag.Rd" 
#> [12] "network_examples/bad_network_example.Rd"     
#> [13] "temp_examples/bad_temp_usage.R"              

# List only code examples
show_example_files("code")
#> [1] "code_examples/browser_calls_bad.R"  "code_examples/core_usage_bad.R"    
#> [3] "code_examples/globalenv_bad.R"      "code_examples/option_changes_bad.R"
#> [5] "code_examples/print_cat_bad.R"      "code_examples/seed_setting_bad.R"  
#> [7] "code_examples/tf_usage_bad.R"      

# List files matching a pattern
show_example_files(pattern = "bad")
#>  [1] "code_examples/browser_calls_bad.R"       
#>  [2] "code_examples/core_usage_bad.R"          
#>  [3] "code_examples/globalenv_bad.R"           
#>  [4] "code_examples/option_changes_bad.R"      
#>  [5] "code_examples/print_cat_bad.R"           
#>  [6] "code_examples/seed_setting_bad.R"        
#>  [7] "code_examples/tf_usage_bad.R"            
#>  [8] "description_examples/bad_description.txt"
#>  [9] "network_examples/bad_network_example.Rd" 
#> [10] "temp_examples/bad_temp_usage.R"          

# Use with example_diagnose_scenario
examples <- show_example_files("code")
pkg_path <- example_diagnose_scenario(examples[1])
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
#> Temporary package created at: /tmp/RtmpQT1Ijn/checktor_example_20260625_230638_3069 
#> Example file copied to: /tmp/RtmpQT1Ijn/checktor_example_20260625_230638_3069/R/browser_calls_bad.R 
#> 
```

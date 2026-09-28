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
  "documentation", "general", "network", "temp", or "all". Default:
  "all".

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
#>  [3] "code_examples/credentials_bad.R"                         
#>  [4] "code_examples/detect_cores_bad.R"                        
#>  [5] "code_examples/file_operations_bad.R"                     
#>  [6] "code_examples/globalenv_bad.R"                           
#>  [7] "code_examples/home_writing_bad.R"                        
#>  [8] "code_examples/installed_packages_bad.R"                  
#>  [9] "code_examples/internal_ns_bad.R"                         
#> [10] "code_examples/library_in_pkg_bad.R"                      
#> [11] "code_examples/option_changes_bad.R"                      
#> [12] "code_examples/print_cat_bad.R"                           
#> [13] "code_examples/roxygen_usage_bad.R"                       
#> [14] "code_examples/seed_setting_bad.R"                        
#> [15] "code_examples/software_install_bad.R"                    
#> [16] "code_examples/sys_setenv_bad.R"                          
#> [17] "code_examples/system_calls_bad.R"                        
#> [18] "code_examples/tf_usage_bad.R"                            
#> [19] "description_examples/acronyms_bad.txt"                   
#> [20] "description_examples/authors_bad.txt"                    
#> [21] "description_examples/bad_description.txt"                
#> [22] "description_examples/cph_role_bad.txt"                   
#> [23] "description_examples/date_format_bad.txt"                
#> [24] "description_examples/description_fields_bad.txt"         
#> [25] "description_examples/description_function_quotes_bad.txt"
#> [26] "description_examples/description_length_bad.txt"         
#> [27] "description_examples/description_placeholders_bad.txt"   
#> [28] "description_examples/description_quoted_quotes_bad.txt"  
#> [29] "description_examples/description_starts_with_bad.txt"    
#> [30] "description_examples/encoding_utf8_bad.txt"              
#> [31] "description_examples/format_names_bad.txt"               
#> [32] "description_examples/good_description.txt"               
#> [33] "description_examples/identifier_format_bad.txt"          
#> [34] "description_examples/language_names_bad.txt"             
#> [35] "description_examples/license_bad.txt"                    
#> [36] "description_examples/license_file_unneeded_bad.txt"      
#> [37] "description_examples/license_year_bad.LICENSE"           
#> [38] "description_examples/references_bad.txt"                 
#> [39] "description_examples/software_names_bad.txt"             
#> [40] "description_examples/spelling_bad.txt"                   
#> [41] "description_examples/title_case_bad.txt"                 
#> [42] "description_examples/title_length_bad.txt"               
#> [43] "description_examples/title_package_name_bad.txt"         
#> [44] "description_examples/title_redundant_phrases_bad.txt"    
#> [45] "description_examples/title_starts_with_article_bad.txt"  
#> [46] "description_examples/unparseable_description.txt"        
#> [47] "description_examples/version_format_bad.txt"             
#> [48] "documentation_examples/commented_examples_bad.Rd"        
#> [49] "documentation_examples/donttest_vs_dontrun_bad.Rd"       
#> [50] "documentation_examples/example_installs_bad.Rd"          
#> [51] "documentation_examples/example_interactive_bad.Rd"       
#> [52] "documentation_examples/example_internal_ns_bad.Rd"       
#> [53] "documentation_examples/example_state_bad.Rmd"            
#> [54] "documentation_examples/example_structure_bad.Rd"         
#> [55] "documentation_examples/example_tf_usage_bad.Rd"          
#> [56] "documentation_examples/example_unparseable_bad.Rd"       
#> [57] "documentation_examples/example_writes_bad.Rd"            
#> [58] "documentation_examples/good_documentation.Rd"            
#> [59] "documentation_examples/missing_examples_bad.Rd"          
#> [60] "documentation_examples/missing_value_tag.Rd"             
#> [61] "documentation_examples/rd_bibliography_bad.Rd"           
#> [62] "documentation_examples/suggested_in_examples_bad.Rd"     
#> [63] "documentation_examples/unexported_example_ns_bad.Rd"     
#> [64] "general_examples/citation_file_bad.CITATION"             
#> [65] "general_examples/code_exercised_bad.R"                   
#> [66] "general_examples/url_liveness_bad.txt"                   
#> [67] "network_examples/bad_network_example.Rd"                 
#> [68] "temp_examples/bad_temp_usage.R"                          

# List only code examples
show_example_files("code")
#>  [1] "code_examples/browser_calls_bad.R"     
#>  [2] "code_examples/core_usage_bad.R"        
#>  [3] "code_examples/credentials_bad.R"       
#>  [4] "code_examples/detect_cores_bad.R"      
#>  [5] "code_examples/file_operations_bad.R"   
#>  [6] "code_examples/globalenv_bad.R"         
#>  [7] "code_examples/home_writing_bad.R"      
#>  [8] "code_examples/installed_packages_bad.R"
#>  [9] "code_examples/internal_ns_bad.R"       
#> [10] "code_examples/library_in_pkg_bad.R"    
#> [11] "code_examples/option_changes_bad.R"    
#> [12] "code_examples/print_cat_bad.R"         
#> [13] "code_examples/roxygen_usage_bad.R"     
#> [14] "code_examples/seed_setting_bad.R"      
#> [15] "code_examples/software_install_bad.R"  
#> [16] "code_examples/sys_setenv_bad.R"        
#> [17] "code_examples/system_calls_bad.R"      
#> [18] "code_examples/tf_usage_bad.R"          

# List files matching a pattern
show_example_files(pattern = "bad")
#>  [1] "code_examples/browser_calls_bad.R"                       
#>  [2] "code_examples/core_usage_bad.R"                          
#>  [3] "code_examples/credentials_bad.R"                         
#>  [4] "code_examples/detect_cores_bad.R"                        
#>  [5] "code_examples/file_operations_bad.R"                     
#>  [6] "code_examples/globalenv_bad.R"                           
#>  [7] "code_examples/home_writing_bad.R"                        
#>  [8] "code_examples/installed_packages_bad.R"                  
#>  [9] "code_examples/internal_ns_bad.R"                         
#> [10] "code_examples/library_in_pkg_bad.R"                      
#> [11] "code_examples/option_changes_bad.R"                      
#> [12] "code_examples/print_cat_bad.R"                           
#> [13] "code_examples/roxygen_usage_bad.R"                       
#> [14] "code_examples/seed_setting_bad.R"                        
#> [15] "code_examples/software_install_bad.R"                    
#> [16] "code_examples/sys_setenv_bad.R"                          
#> [17] "code_examples/system_calls_bad.R"                        
#> [18] "code_examples/tf_usage_bad.R"                            
#> [19] "description_examples/acronyms_bad.txt"                   
#> [20] "description_examples/authors_bad.txt"                    
#> [21] "description_examples/bad_description.txt"                
#> [22] "description_examples/cph_role_bad.txt"                   
#> [23] "description_examples/date_format_bad.txt"                
#> [24] "description_examples/description_fields_bad.txt"         
#> [25] "description_examples/description_function_quotes_bad.txt"
#> [26] "description_examples/description_length_bad.txt"         
#> [27] "description_examples/description_placeholders_bad.txt"   
#> [28] "description_examples/description_quoted_quotes_bad.txt"  
#> [29] "description_examples/description_starts_with_bad.txt"    
#> [30] "description_examples/encoding_utf8_bad.txt"              
#> [31] "description_examples/format_names_bad.txt"               
#> [32] "description_examples/identifier_format_bad.txt"          
#> [33] "description_examples/language_names_bad.txt"             
#> [34] "description_examples/license_bad.txt"                    
#> [35] "description_examples/license_file_unneeded_bad.txt"      
#> [36] "description_examples/license_year_bad.LICENSE"           
#> [37] "description_examples/references_bad.txt"                 
#> [38] "description_examples/software_names_bad.txt"             
#> [39] "description_examples/spelling_bad.txt"                   
#> [40] "description_examples/title_case_bad.txt"                 
#> [41] "description_examples/title_length_bad.txt"               
#> [42] "description_examples/title_package_name_bad.txt"         
#> [43] "description_examples/title_redundant_phrases_bad.txt"    
#> [44] "description_examples/title_starts_with_article_bad.txt"  
#> [45] "description_examples/version_format_bad.txt"             
#> [46] "documentation_examples/commented_examples_bad.Rd"        
#> [47] "documentation_examples/donttest_vs_dontrun_bad.Rd"       
#> [48] "documentation_examples/example_installs_bad.Rd"          
#> [49] "documentation_examples/example_interactive_bad.Rd"       
#> [50] "documentation_examples/example_internal_ns_bad.Rd"       
#> [51] "documentation_examples/example_state_bad.Rmd"            
#> [52] "documentation_examples/example_structure_bad.Rd"         
#> [53] "documentation_examples/example_tf_usage_bad.Rd"          
#> [54] "documentation_examples/example_unparseable_bad.Rd"       
#> [55] "documentation_examples/example_writes_bad.Rd"            
#> [56] "documentation_examples/missing_examples_bad.Rd"          
#> [57] "documentation_examples/rd_bibliography_bad.Rd"           
#> [58] "documentation_examples/suggested_in_examples_bad.Rd"     
#> [59] "documentation_examples/unexported_example_ns_bad.Rd"     
#> [60] "general_examples/citation_file_bad.CITATION"             
#> [61] "general_examples/code_exercised_bad.R"                   
#> [62] "general_examples/url_liveness_bad.txt"                   
#> [63] "network_examples/bad_network_example.Rd"                 
#> [64] "temp_examples/bad_temp_usage.R"                          

# Use with example_diagnose_scenario
examples <- show_example_files("code")
pkg_path <- example_diagnose_scenario(examples[1], show_content = FALSE)
unlink(pkg_path, recursive = TRUE)
```

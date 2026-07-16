# Tidy a checktor result into a per-check data frame

Tidy a checktor result into a per-check data frame

## Usage

``` r
# S3 method for class 'checktor_results'
tidy(x, ...)

# S3 method for class 'checktor_category_result'
tidy(x, ...)

# S3 method for class 'checktor_results'
as.data.frame(x, ...)

# S3 method for class 'checktor_category_result'
as.data.frame(x, ...)
```

## Arguments

- x:

  A `checktor_results` or `checktor_category_result` object.

- ...:

  Unused.

## Value

A `data.frame` with one row per check: `category` (results level only),
`check`, `passed`, `n_issues`, `message`.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
tidy(results)
#>         category                     check   severity passed n_issues
#> 1           code                  tf_usage robustness  FALSE        7
#> 2           code              seed_setting     policy   TRUE        0
#> 3           code           print_cat_usage     policy   TRUE        0
#> 4           code            option_changes     policy   TRUE        0
#> 5           code              home_writing     policy   TRUE        0
#> 6           code              temp_cleanup    opinion   TRUE        0
#> 7           code             globalenv_mod     policy   TRUE        0
#> 8           code        installed_packages     policy   TRUE        0
#> 9           code               warn_option     policy   TRUE        0
#> 10          code          software_install     policy   TRUE        0
#> 11          code                core_usage     policy   TRUE        0
#> 12          code            library_in_pkg robustness   TRUE        0
#> 13          code   detect_cores_robustness robustness   TRUE        0
#> 14          code                sys_setenv     policy   TRUE        0
#> 15          code     hardcoded_credentials robustness   TRUE        0
#> 16   description            software_names     policy   TRUE        0
#> 17   description                  acronyms    opinion   TRUE        0
#> 18   description                   license     policy   TRUE        0
#> 19   description                title_case     policy   TRUE        0
#> 20   description              title_length    opinion   TRUE        0
#> 21   description   title_redundant_phrases    opinion   TRUE        0
#> 22   description                   authors     policy   TRUE        0
#> 23   description         identifier_format     policy   TRUE        0
#> 24   description                  cph_role    opinion  FALSE        1
#> 25   description                references     policy   TRUE        0
#> 26   description               date_format     policy   TRUE        0
#> 27   description             encoding_utf8     policy   TRUE        0
#> 28   description            version_format     policy   TRUE        0
#> 29   description        description_length    opinion   TRUE        0
#> 30   description   description_starts_with     policy   TRUE        0
#> 31   description description_quoted_quotes     policy   TRUE        0
#> 32   description              license_year robustness   TRUE        0
#> 33 documentation                value_tags    opinion   TRUE        0
#> 34 documentation          missing_examples    opinion   TRUE        0
#> 35 documentation             roxygen_usage robustness   TRUE        0
#> 36 documentation         example_structure    opinion   TRUE        0
#> 37 documentation        commented_examples    opinion   TRUE        0
#> 38 documentation       donttest_vs_dontrun    opinion   TRUE        0
#> 39 documentation     unexported_example_ns robustness   TRUE        0
#> 40 documentation     suggested_in_examples     policy   TRUE        0
#> 41       general              package_size     policy   TRUE        0
#> 42       general                      urls    opinion   TRUE        0
#> 43       general                 news_file    opinion   TRUE        0
#> 44       general              readme_links robustness   TRUE        0
#> 45        policy             browser_calls     policy   TRUE        0
#> 46        policy              system_calls robustness   TRUE        0
#> 47        policy           file_operations     policy   TRUE        0
#> 48        policy        network_operations     policy   TRUE        0
#>                               message
#> 1                     T/F usage check
#> 2                  Seed setting check
#> 3               Print/cat usage check
#> 4                Option changes check
#> 5                  Home writing check
#> 6                  Temp cleanup check
#> 7        GlobalEnv modification check
#> 8    installed.packages() usage check
#> 9                   Warn option check
#> 10        Software installation check
#> 11                   Core usage check
#> 12        library() in pkg code check
#> 13             detectCores() NA check
#> 14             Sys.setenv reset check
#> 15         Hardcoded credential check
#> 16               Software names check
#> 17                     Acronyms check
#> 18                      License check
#> 19                   Title case check
#> 20                 Title length check
#> 21      Title redundant-phrases check
#> 22              Authors@R field check
#> 23            Author identifier check
#> 24                     cph role check
#> 25                   References check
#> 26                   Date field check
#> 27               Encoding field check
#> 28                Version field check
#> 29           Description length check
#> 30          Description opening check
#> 31    Description double-quotes check
#> 32                 License file check
#> 33                   Value tags check
#> 34             Missing examples check
#> 35            Roxygen freshness check
#> 36            Example structure check
#> 37       Commented-out examples check
#> 38          donttest vs dontrun check
#> 39 Unexported example-namespace check
#> 40   Suggested-package examples check
#> 41                 Package size check
#> 42                         URLs check
#> 43                    NEWS file check
#> 44        README relative-links check
#> 45                Browser calls check
#> 46                 System calls check
#> 47              File operations check
#> 48           Network operations check
```

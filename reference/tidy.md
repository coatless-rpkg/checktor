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
#> 17   description            language_names     policy   TRUE        0
#> 18   description                  acronyms    opinion   TRUE        0
#> 19   description                   license     policy   TRUE        0
#> 20   description                title_case     policy   TRUE        0
#> 21   description              title_length    opinion   TRUE        0
#> 22   description   title_redundant_phrases    opinion   TRUE        0
#> 23   description                   authors     policy   TRUE        0
#> 24   description         identifier_format     policy   TRUE        0
#> 25   description                  cph_role    opinion  FALSE        1
#> 26   description                references     policy   TRUE        0
#> 27   description               date_format     policy   TRUE        0
#> 28   description             encoding_utf8     policy   TRUE        0
#> 29   description            version_format     policy   TRUE        0
#> 30   description                  spelling    opinion   TRUE        0
#> 31   description        description_length    opinion   TRUE        0
#> 32   description   description_starts_with     policy   TRUE        0
#> 33   description description_quoted_quotes     policy   TRUE        0
#> 34   description              license_year robustness   TRUE        0
#> 35 documentation                value_tags    opinion   TRUE        0
#> 36 documentation          missing_examples    opinion   TRUE        0
#> 37 documentation             roxygen_usage robustness   TRUE        0
#> 38 documentation         example_structure    opinion   TRUE        0
#> 39 documentation        commented_examples    opinion   TRUE        0
#> 40 documentation       donttest_vs_dontrun    opinion   TRUE        0
#> 41 documentation     unexported_example_ns robustness   TRUE        0
#> 42 documentation     suggested_in_examples     policy   TRUE        0
#> 43       general              package_size     policy   TRUE        0
#> 44       general                      urls    opinion   TRUE        0
#> 45       general              url_liveness robustness   TRUE        0
#> 46       general                 news_file    opinion   TRUE        0
#> 47       general              readme_links robustness   TRUE        0
#> 48        policy             browser_calls     policy   TRUE        0
#> 49        policy              system_calls robustness   TRUE        0
#> 50        policy           file_operations     policy   TRUE        0
#> 51        policy        network_operations     policy   TRUE        0
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
#> 17               Language names check
#> 18                     Acronyms check
#> 19                      License check
#> 20                   Title case check
#> 21                 Title length check
#> 22      Title redundant-phrases check
#> 23              Authors@R field check
#> 24            Author identifier check
#> 25                     cph role check
#> 26                   References check
#> 27                   Date field check
#> 28               Encoding field check
#> 29                Version field check
#> 30                     Spelling check
#> 31           Description length check
#> 32          Description opening check
#> 33    Description double-quotes check
#> 34                 License file check
#> 35                   Value tags check
#> 36             Missing examples check
#> 37            Roxygen freshness check
#> 38            Example structure check
#> 39       Commented-out examples check
#> 40          donttest vs dontrun check
#> 41 Unexported example-namespace check
#> 42   Suggested-package examples check
#> 43                 Package size check
#> 44                         URLs check
#> 45                 URL liveness check
#> 46                    NEWS file check
#> 47        README relative-links check
#> 48                Browser calls check
#> 49                 System calls check
#> 50              File operations check
#> 51           Network operations check
```

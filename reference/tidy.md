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
`check`, `severity`, `passed`, `skipped`, `n_issues`, `message`.
`skipped` marks a check that did not run, such as the URL fetch away
from the console, so it never reads as one that passed.

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                 show_content = FALSE)
results <- checktor(pkg, verbose = FALSE, progress = FALSE)
tidy(results)
#>         category                     check   severity passed skipped n_issues
#> 1           code                  tf_usage robustness  FALSE   FALSE        7
#> 2           code              seed_setting     policy   TRUE   FALSE        0
#> 3           code           print_cat_usage     policy   TRUE   FALSE        0
#> 4           code            option_changes     policy   TRUE   FALSE        0
#> 5           code              home_writing     policy   TRUE   FALSE        0
#> 6           code              temp_cleanup    opinion   TRUE   FALSE        0
#> 7           code             globalenv_mod     policy   TRUE   FALSE        0
#> 8           code        installed_packages     policy   TRUE   FALSE        0
#> 9           code               warn_option     policy   TRUE   FALSE        0
#> 10          code          software_install     policy   TRUE   FALSE        0
#> 11          code                core_usage     policy   TRUE   FALSE        0
#> 12          code            library_in_pkg robustness   TRUE   FALSE        0
#> 13          code   detect_cores_robustness robustness   TRUE   FALSE        0
#> 14          code                sys_setenv     policy   TRUE   FALSE        0
#> 15          code               internal_ns robustness   TRUE   FALSE        0
#> 16          code     hardcoded_credentials robustness   TRUE   FALSE        0
#> 17   description            software_names     policy   TRUE   FALSE        0
#> 18   description            language_names     policy   TRUE   FALSE        0
#> 19   description                  acronyms    opinion   TRUE   FALSE        0
#> 20   description                   license     policy   TRUE   FALSE        0
#> 21   description                title_case     policy   TRUE   FALSE        0
#> 22   description              title_length    opinion   TRUE   FALSE        0
#> 23   description   title_redundant_phrases    opinion   TRUE   FALSE        0
#> 24   description                   authors     policy   TRUE   FALSE        0
#> 25   description         identifier_format     policy   TRUE   FALSE        0
#> 26   description                  cph_role    opinion  FALSE   FALSE        1
#> 27   description                references     policy   TRUE   FALSE        0
#> 28   description               date_format     policy   TRUE   FALSE        0
#> 29   description             encoding_utf8     policy   TRUE   FALSE        0
#> 30   description            version_format     policy   TRUE   FALSE        0
#> 31   description                  spelling    opinion   TRUE    TRUE        0
#> 32   description        description_length    opinion   TRUE   FALSE        0
#> 33   description   description_starts_with     policy   TRUE   FALSE        0
#> 34   description description_quoted_quotes     policy   TRUE   FALSE        0
#> 35   description              license_year robustness   TRUE   FALSE        0
#> 36 documentation                value_tags    opinion   TRUE   FALSE        0
#> 37 documentation          missing_examples    opinion   TRUE   FALSE        0
#> 38 documentation             roxygen_usage robustness   TRUE   FALSE        0
#> 39 documentation         example_structure    opinion   TRUE   FALSE        0
#> 40 documentation        commented_examples    opinion   TRUE   FALSE        0
#> 41 documentation       donttest_vs_dontrun    opinion   TRUE   FALSE        0
#> 42 documentation     unexported_example_ns robustness   TRUE   FALSE        0
#> 43 documentation     suggested_in_examples     policy   TRUE   FALSE        0
#> 44 documentation       example_interactive     policy   TRUE   FALSE        0
#> 45 documentation          example_installs     policy   TRUE   FALSE        0
#> 46 documentation            example_writes     policy   TRUE   FALSE        0
#> 47 documentation             example_state     policy   TRUE   FALSE        0
#> 48 documentation       example_internal_ns     policy   TRUE   FALSE        0
#> 49       general              package_size     policy   TRUE   FALSE        0
#> 50       general                      urls    opinion   TRUE   FALSE        0
#> 51       general              url_liveness robustness   TRUE    TRUE        0
#> 52       general                 news_file    opinion   TRUE   FALSE        0
#> 53       general              readme_links robustness   TRUE   FALSE        0
#> 54        policy             browser_calls     policy   TRUE   FALSE        0
#> 55        policy              system_calls robustness   TRUE   FALSE        0
#> 56        policy           file_operations     policy   TRUE   FALSE        0
#> 57        policy        network_operations     policy   TRUE   FALSE        0
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
#> 15           Internal namespace check
#> 16         Hardcoded credential check
#> 17               Software names check
#> 18               Language names check
#> 19                     Acronyms check
#> 20                      License check
#> 21                   Title case check
#> 22                 Title length check
#> 23      Title redundant-phrases check
#> 24              Authors@R field check
#> 25            Author identifier check
#> 26                     cph role check
#> 27                   References check
#> 28                   Date field check
#> 29               Encoding field check
#> 30                Version field check
#> 31                     Spelling check
#> 32           Description length check
#> 33          Description opening check
#> 34    Description double-quotes check
#> 35                 License file check
#> 36                   Value tags check
#> 37             Missing examples check
#> 38            Roxygen freshness check
#> 39            Example structure check
#> 40       Commented-out examples check
#> 41          donttest vs dontrun check
#> 42 Unexported example-namespace check
#> 43   Suggested-package examples check
#> 44          Interactive example check
#> 45             Example installs check
#> 46               Example writes check
#> 47                Example state check
#> 48                  Example ::: check
#> 49                 Package size check
#> 50                         URLs check
#> 51                 URL liveness check
#> 52                    NEWS file check
#> 53        README relative-links check
#> 54                Browser calls check
#> 55                 System calls check
#> 56              File operations check
#> 57           Network operations check
```

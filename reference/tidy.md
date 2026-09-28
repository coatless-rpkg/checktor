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
`passed` is `TRUE` for a check that ran and found nothing. `skipped`
marks a check that did not run, such as the URL fetch away from the
console, and such a check is never `passed`. A check that failed is
neither, so `!passed & !skipped` picks out the failures, and the three
counts match
[summary()](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor-summary.md).
[`passed()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/predicates.md)
asks only whether a check failed, so it is `TRUE` for a skipped check
that is `FALSE` here.

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
#> 17   description          description_file     policy   TRUE   FALSE        0
#> 18   description        description_fields     policy   TRUE   FALSE        0
#> 19   description  description_placeholders     policy   TRUE   FALSE        0
#> 20   description            software_names     policy   TRUE   FALSE        0
#> 21   description            language_names     policy   TRUE   FALSE        0
#> 22   description                  acronyms    opinion   TRUE   FALSE        0
#> 23   description                   license     policy   TRUE   FALSE        0
#> 24   description     license_file_unneeded     policy   TRUE   FALSE        0
#> 25   description                title_case     policy   TRUE   FALSE        0
#> 26   description              title_length    opinion   TRUE   FALSE        0
#> 27   description        title_package_name     policy   TRUE   FALSE        0
#> 28   description   title_redundant_phrases    opinion   TRUE   FALSE        0
#> 29   description                   authors     policy   TRUE   FALSE        0
#> 30   description         identifier_format     policy   TRUE   FALSE        0
#> 31   description                references     policy   TRUE   FALSE        0
#> 32   description               date_format     policy   TRUE   FALSE        0
#> 33   description             encoding_utf8     policy   TRUE   FALSE        0
#> 34   description            version_format     policy   TRUE   FALSE        0
#> 35   description                  spelling    opinion  FALSE    TRUE        0
#> 36   description        description_length    opinion   TRUE   FALSE        0
#> 37   description   description_starts_with     policy   TRUE   FALSE        0
#> 38   description description_quoted_quotes     policy   TRUE   FALSE        0
#> 39   description              license_year robustness   TRUE   FALSE        0
#> 40 documentation                value_tags    opinion   TRUE   FALSE        0
#> 41 documentation          missing_examples    opinion   TRUE   FALSE        0
#> 42 documentation             roxygen_usage robustness   TRUE   FALSE        0
#> 43 documentation         example_structure    opinion   TRUE   FALSE        0
#> 44 documentation        commented_examples    opinion   TRUE   FALSE        0
#> 45 documentation       donttest_vs_dontrun    opinion   TRUE   FALSE        0
#> 46 documentation     unexported_example_ns robustness   TRUE   FALSE        0
#> 47 documentation     suggested_in_examples     policy   TRUE   FALSE        0
#> 48 documentation           rd_bibliography     policy   TRUE   FALSE        0
#> 49 documentation     rd_bibliography_files robustness   TRUE   FALSE        0
#> 50 documentation       example_interactive     policy   TRUE   FALSE        0
#> 51 documentation          example_installs     policy   TRUE   FALSE        0
#> 52 documentation            example_writes     policy   TRUE   FALSE        0
#> 53 documentation             example_state     policy   TRUE   FALSE        0
#> 54 documentation          example_tf_usage robustness   TRUE   FALSE        0
#> 55 documentation       example_unparseable robustness   TRUE   FALSE        0
#> 56 documentation       example_internal_ns     policy   TRUE   FALSE        0
#> 57       general              package_size     policy   TRUE   FALSE        0
#> 58       general                      urls    opinion   TRUE   FALSE        0
#> 59       general              url_liveness robustness  FALSE    TRUE        0
#> 60       general                 news_file    opinion   TRUE   FALSE        0
#> 61       general              readme_links robustness   TRUE   FALSE        0
#> 62       general            code_exercised     policy   TRUE   FALSE        0
#> 63       general             citation_file     policy   TRUE   FALSE        0
#> 64        policy             browser_calls     policy   TRUE   FALSE        0
#> 65        policy              system_calls robustness   TRUE   FALSE        0
#> 66        policy           file_operations     policy   TRUE   FALSE        0
#> 67        policy        network_operations     policy   TRUE   FALSE        0
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
#> 17             DESCRIPTION file check
#> 18           DESCRIPTION fields check
#> 19     DESCRIPTION placeholders check
#> 20               Software names check
#> 21               Language names check
#> 22                     Acronyms check
#> 23                      License check
#> 24         License file pointer check
#> 25                   Title case check
#> 26                 Title length check
#> 27           Title package-name check
#> 28      Title redundant-phrases check
#> 29              Authors@R field check
#> 30            Author identifier check
#> 31                   References check
#> 32                   Date field check
#> 33               Encoding field check
#> 34                Version field check
#> 35                     Spelling check
#> 36           Description length check
#> 37          Description opening check
#> 38    Description double-quotes check
#> 39                 License file check
#> 40                   Value tags check
#> 41             Missing examples check
#> 42            Roxygen freshness check
#> 43            Example structure check
#> 44       Commented-out examples check
#> 45          donttest vs dontrun check
#> 46 Unexported example-namespace check
#> 47   Suggested-package examples check
#> 48              Rd bibliography check
#> 49        Rd bibliography files check
#> 50          Interactive example check
#> 51             Example installs check
#> 52               Example writes check
#> 53                Example state check
#> 54            Example T/F usage check
#> 55                Example parse check
#> 56                  Example ::: check
#> 57                 Package size check
#> 58                         URLs check
#> 59                 URL liveness check
#> 60                    NEWS file check
#> 61        README relative-links check
#> 62               Code exercised check
#> 63                CITATION file check
#> 64                Browser calls check
#> 65                 System calls check
#> 66              File operations check
#> 67           Network operations check
```

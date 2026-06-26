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
#>         category                     check passed n_issues
#> 1           code                  tf_usage  FALSE        7
#> 2           code              seed_setting   TRUE        0
#> 3           code           print_cat_usage   TRUE        0
#> 4           code            option_changes   TRUE        0
#> 5           code              home_writing   TRUE        0
#> 6           code              temp_cleanup   TRUE        0
#> 7           code             globalenv_mod   TRUE        0
#> 8           code        installed_packages   TRUE        0
#> 9           code               warn_option   TRUE        0
#> 10          code          software_install   TRUE        0
#> 11          code                core_usage   TRUE        0
#> 12          code            library_in_pkg   TRUE        0
#> 13          code                sys_setenv   TRUE        0
#> 14   description            software_names   TRUE        0
#> 15   description                  acronyms   TRUE        0
#> 16   description                   license  FALSE        1
#> 17   description                title_case   TRUE        0
#> 18   description title_starts_with_article   TRUE        0
#> 19   description   title_redundant_phrases   TRUE        0
#> 20   description                   authors   TRUE        0
#> 21   description                  cph_role  FALSE        1
#> 22   description                references   TRUE        0
#> 23   description        description_length  FALSE        1
#> 24   description   description_starts_with   TRUE        0
#> 25   description        description_bare_r   TRUE        0
#> 26   description description_quoted_quotes   TRUE        0
#> 27   description              license_year   TRUE        0
#> 28 documentation                value_tags   TRUE        0
#> 29 documentation             roxygen_usage   TRUE        0
#> 30 documentation         example_structure   TRUE        0
#> 31 documentation        commented_examples   TRUE        0
#> 32 documentation     unexported_example_ns   TRUE        0
#> 33 documentation       donttest_vs_dontrun   TRUE        0
#> 34       general              package_size   TRUE        0
#> 35       general                      urls   TRUE        0
#> 36        policy             browser_calls   TRUE        0
#> 37        policy              system_calls   TRUE        0
#> 38        policy           file_operations   TRUE        0
#> 39        policy        network_operations   TRUE        0
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
#> 13             Sys.setenv reset check
#> 14               Software names check
#> 15                     Acronyms check
#> 16                      License check
#> 17                   Title case check
#> 18    Title starts-with-article check
#> 19      Title redundant-phrases check
#> 20              Authors@R field check
#> 21                     cph role check
#> 22                   References check
#> 23           Description length check
#> 24      Description starts-with check
#> 25           Description bare-R check
#> 26    Description double-quotes check
#> 27                 License year check
#> 28                   Value tags check
#> 29                Roxygen usage check
#> 30            Example structure check
#> 31       Commented-out examples check
#> 32 Unexported example-namespace check
#> 33          donttest vs dontrun check
#> 34                 Package size check
#> 35                         URLs check
#> 36                Browser calls check
#> 37                 System calls check
#> 38              File operations check
#> 39           Network operations check
```

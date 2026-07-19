# Package index

## Overview

Start here. The package-level help topic summarises what checktor checks
and how the pieces fit together.

- [`checktor-package`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor-package.md)
  : checktor: Extra CRAN Submission Checks

## Top-level orchestrator

Functions you call directly to diagnose a package.

- [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
  : Diagnose Package for CRAN Submission Issues
- [`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
  : Quick Health Check
- [`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)
  : Treatment Recommendations
- [`health_report()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/health_report.md)
  : Comprehensive Health Report
- [`configure_doctor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/configure_doctor.md)
  : Configure Package Doctor Defaults

## Code-pattern diagnostics

Per-check entry points for R source patterns. Each operates on the
parsed AST and can be called independently of
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md).

- [`diagnose_code_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_code_issues.md)
  : Diagnose Code Health Issues

- [`diagnose_tf_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_tf_usage.md)
  :

  Diagnose `T`/`F` Usage in R Code

- [`diagnose_seed_setting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_seed_setting.md)
  : Diagnose Hardcoded Seed Setting

- [`diagnose_print_cat_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_print_cat_usage.md)
  : Diagnose Print/Cat Usage in Functions

- [`diagnose_detect_cores_robustness()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_detect_cores_robustness.md)
  :

  Diagnose Unguarded `detectCores()`

- [`diagnose_option_changes()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_option_changes.md)
  : Diagnose Unrestored Option Changes

- [`diagnose_home_writing()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_home_writing.md)
  : Diagnose Writes to the User's Home Directory

- [`diagnose_temp_cleanup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_temp_cleanup.md)
  : Diagnose Missing Temp-File Cleanup

- [`diagnose_globalenv_modification()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_globalenv_modification.md)
  : Diagnose Writes to the Global Environment

- [`diagnose_installed_packages_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_installed_packages_usage.md)
  : Diagnose installed.packages() Usage

- [`diagnose_warn_option()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_warn_option.md)
  : Diagnose Changes to options(warn=)

- [`diagnose_software_installation()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_software_installation.md)
  : Diagnose Package Installation From Package Code

- [`diagnose_core_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_core_usage.md)
  : Diagnose Parallel Core Usage

- [`diagnose_library_in_pkg_code()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_library_in_pkg_code.md)
  : Diagnose library() in Package Code

- [`diagnose_sys_setenv_no_reset()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_sys_setenv_no_reset.md)
  : Diagnose Unrestored Environment Variables

- [`diagnose_hardcoded_credentials()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_hardcoded_credentials.md)
  : Diagnose Hardcoded Credentials in Package Code

## DESCRIPTION-field diagnostics

Checks against the DESCRIPTION file, parsed via
[`base::read.dcf()`](https://rdrr.io/r/base/dcf.html).

- [`diagnose_description_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_description_issues.md)
  : Diagnose DESCRIPTION File Issues
- [`diagnose_software_names_formatting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_software_names_formatting.md)
  : Diagnose Unquoted Software Names in DESCRIPTION
- [`diagnose_language_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_language_names.md)
  : Diagnose Programming-Language Names in DESCRIPTION
- [`diagnose_acronym_explanation()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_acronym_explanation.md)
  : Diagnose Unexplained Acronyms in DESCRIPTION
- [`diagnose_license_formatting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_license_formatting.md)
  : Diagnose the License Field
- [`diagnose_license_year()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_license_year.md)
  : Diagnose an Unfilled LICENSE Template
- [`diagnose_title_case()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_title_case.md)
  : Diagnose Title Case in DESCRIPTION
- [`diagnose_title_length()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_title_length.md)
  : Diagnose Title Length
- [`diagnose_title_starts_with_article()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_title_starts_with_article.md)
  : Diagnose Title Starting With an Article
- [`diagnose_title_redundant_phrases()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_title_redundant_phrases.md)
  : Diagnose Redundant Phrases in Title
- [`diagnose_description_function_quotes()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_description_function_quotes.md)
  : Diagnose Single-Quoted Function Names
- [`diagnose_authors_field()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_authors_field.md)
  : Diagnose the Authors@R Field
- [`diagnose_identifier_format()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_identifier_format.md)
  : Diagnose Author Identifier Formatting
- [`diagnose_cph_role()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_cph_role.md)
  : Diagnose a Missing Copyright-Holder Role
- [`diagnose_references_formatting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_references_formatting.md)
  : Diagnose Reference Formatting in DESCRIPTION
- [`diagnose_date_format()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_date_format.md)
  : Diagnose the DESCRIPTION Date Field
- [`diagnose_encoding_utf8()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_encoding_utf8.md)
  : Diagnose a Non-Portable DESCRIPTION Encoding
- [`diagnose_version_format()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_version_format.md)
  : Diagnose the DESCRIPTION Version Field
- [`diagnose_spelling()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_spelling.md)
  : Diagnose Possibly Misspelled Words in DESCRIPTION
- [`diagnose_description_length()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_description_length.md)
  : Diagnose Description Length
- [`diagnose_description_starts_with()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_description_starts_with.md)
  : Diagnose the Description Opening
- [`diagnose_description_quoted_quotes()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_description_quoted_quotes.md)
  : Diagnose Double-Quoted Software Names

## Documentation diagnostics

Checks against `.Rd` files, walked via
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html).

- [`diagnose_documentation_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_documentation_issues.md)
  : Diagnose Documentation Issues
- [`diagnose_value_tags()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_value_tags.md)
  : Diagnose Missing Value Tags in Documentation
- [`diagnose_missing_examples()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_missing_examples.md)
  : Diagnose Exported Functions Missing Examples
- [`diagnose_roxygen_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_roxygen_usage.md)
  : Diagnose Stale Generated Documentation
- [`diagnose_example_structure()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_example_structure.md)
  : Diagnose Example Structure
- [`diagnose_unexported_example_namespace()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_unexported_example_namespace.md)
  : Diagnose Bare Calls to Unexported Functions in Examples
- [`diagnose_commented_examples()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_commented_examples.md)
  : Diagnose Examples That Run Nothing
- [`diagnose_donttest_vs_dontrun()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_donttest_vs_dontrun.md)
  : Diagnose dontrun Where donttest Belongs
- [`diagnose_suggested_in_examples()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_suggested_in_examples.md)
  : Diagnose Suggested Packages Used in Examples Without a Guard

## General-purpose diagnostics

Package-level checks (size, URLs, NEWS, README links) that don’t fit
other categories.

- [`diagnose_general_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_general_issues.md)
  : Diagnose General Package Issues
- [`diagnose_package_size()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_package_size.md)
  : Diagnose Package Size
- [`diagnose_urls()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_urls.md)
  : Diagnose URL Issues in Package Files
- [`diagnose_url_liveness()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_url_liveness.md)
  : Diagnose Broken and Redirecting URLs (Opt-In, Network)
- [`diagnose_news_file()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_news_file.md)
  : Diagnose a Missing NEWS File
- [`diagnose_readme_relative_links()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_readme_relative_links.md)
  : Diagnose Relative Links in the README
- [`diagnose_cran_comments_file()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_cran_comments_file.md)
  : Diagnose a Missing cran-comments.md File

## CRAN policy diagnostics

Checks targeting common CRAN policy violations (debugging leftovers, raw
shell calls, file/network access).

- [`diagnose_policy_violations()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_policy_violations.md)
  : Check for Common CRAN Policy Violations
- [`diagnose_browser_calls()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_browser_calls.md)
  : Diagnose Leftover browser() Calls
- [`diagnose_system_calls()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_system_calls.md)
  : Diagnose System Calls
- [`diagnose_file_operations()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_file_operations.md)
  : Diagnose Writes to the User's Filespace
- [`diagnose_network_operations()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_network_operations.md)
  : Diagnose Unguarded Network Access

## Result classes

S3 constructors and print methods for diagnostic result objects. You
typically don’t construct these by hand - use the diagnostic functions
instead.

- [`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
  : Create a Standard Diagnostic Check Result Object
- [`checktor_category_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_category_result.md)
  : Create a Multi-Category Diagnostic Result Object
- [`print(`*`<checktor_check_result>`*`)`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/print.checktor_check_result.md)
  : Print Method for checktor_check_result Objects
- [`print(`*`<checktor_category_result>`*`)`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/print.checktor_category_result.md)
  : Print Method for checktor_category_result Objects
- [`print(`*`<checktor_results>`*`)`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/print.checktor_results.md)
  : Print Method for checktor_results Objects

## Result accessors

Plain accessors over diagnostic results so you never navigate nested
sublists. Work on a full
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
result, a single category, or a single check.

- [`issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/issues.md)
  : Extract issues, checks, or a per-category summary from checktor
  results
- [`tidy(`*`<checktor_results>`*`)`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/tidy.md)
  [`tidy(`*`<checktor_category_result>`*`)`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/tidy.md)
  [`as.data.frame(`*`<checktor_results>`*`)`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/tidy.md)
  [`as.data.frame(`*`<checktor_category_result>`*`)`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/tidy.md)
  : Tidy a checktor result into a per-check data frame
- [`summary(`*`<checktor_category_result>`*`)`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor-summary.md)
  [`summary(`*`<checktor_results>`*`)`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor-summary.md)
  : Per-category summary of checktor results
- [`passed()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/predicates.md)
  [`is_healthy()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/predicates.md)
  [`n_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/predicates.md)
  [`n_failed_checks()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/predicates.md)
  [`failed_checks()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/predicates.md)
  : Status predicates for checktor results
- [`reexports`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/reexports.md)
  [`tidy`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/reexports.md)
  : Objects exported from other packages

## Example scenarios

Helpers for building temporary packages with canned bad-pattern code,
used in the `@examples` of individual diagnostics.

- [`example_diagnose_scenario()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/example_diagnose_scenario.md)
  : Create Example Diagnostic Scenario
- [`show_example_files()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/show_example_files.md)
  : Show Available Example Files

## Extending checktor

Register a custom check with
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md),
plus the AST toolkit the built-in checks use to inspect parsed sources
and `.Rd` files.

- [`register_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/register_check.md)
  :

  Register a Custom Check with
  [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)

- [`unregister_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/unregister_check.md)
  : Remove Registered Checks

- [`registered_checks()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/registered_checks.md)
  : List Registered Checks

- [`read_r_xml()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/read_r_xml.md)
  : Parse a Package's R Sources into Queryable XML

- [`xpath_lints()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/xpath_lints.md)
  :

  Collect XPath Matches as `file:line` Strings

- [`xpath_per_file()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/xpath_per_file.md)
  : Summarise XPath Matches per File

- [`undesirable_function_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/undesirable_function_check.md)
  : Flag Every Call to a Named Function

- [`not_under_fn_with_call_xpath()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/not_under_fn_with_call_xpath.md)
  : XPath Predicate: Not Guarded by a Sibling Call

- [`extract_rd_section()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/extract_rd_section.md)
  :

  Extract One Section from a Parsed `.Rd` File

- [`collect_rd_text()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/collect_rd_text.md)
  :

  Flatten a Parsed `.Rd` Node to Text

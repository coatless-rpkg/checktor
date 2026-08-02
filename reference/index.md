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
- [`ci_report()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/ci_report.md)
  : Report Findings in the Format Your CI Understands
- [`configure_doctor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/configure_doctor.md)
  : Configure Package Doctor Defaults

## Category diagnostics

One per category. Each runs the panel of `lab_*()` checks below it and
returns them together, which is what
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
calls.

- [`diagnose_code_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_code_issues.md)
  : Diagnose Code Health Issues
- [`diagnose_description_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_description_issues.md)
  : Diagnose DESCRIPTION File Issues
- [`diagnose_documentation_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_documentation_issues.md)
  : Diagnose Documentation Issues
- [`diagnose_general_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_general_issues.md)
  : Diagnose General Package Issues
- [`diagnose_policy_violations()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_policy_violations.md)
  : Check for Common CRAN Policy Violations

## Code checks

Individual checks on R source, run against the parsed syntax tree. The
name after `lab_` is the check name that
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) reports.

- [`lab_tf_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_tf_usage.md)
  :

  Diagnose `T`/`F` Usage in R Code

- [`lab_seed_setting()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_seed_setting.md)
  : Diagnose Hardcoded Seed Setting

- [`lab_print_cat_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_print_cat_usage.md)
  : Diagnose Print/Cat Usage in Functions

- [`lab_detect_cores_robustness()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_detect_cores_robustness.md)
  :

  Diagnose Unguarded `detectCores()`

- [`lab_option_changes()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_option_changes.md)
  : Diagnose Unrestored Option Changes

- [`lab_home_writing()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_home_writing.md)
  : Diagnose Writes to the User's Home Directory

- [`lab_temp_cleanup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_temp_cleanup.md)
  : Diagnose Missing Temp-File Cleanup

- [`lab_globalenv_mod()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_globalenv_mod.md)
  : Diagnose Writes to the Global Environment

- [`lab_installed_packages()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_installed_packages.md)
  : Diagnose installed.packages() Usage

- [`lab_warn_option()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_warn_option.md)
  : Diagnose Changes to options(warn=)

- [`lab_software_install()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_software_install.md)
  : Diagnose Package Installation From Package Code

- [`lab_core_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_core_usage.md)
  : Diagnose Parallel Core Usage

- [`lab_library_in_pkg()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_library_in_pkg.md)
  : Diagnose library() in Package Code

- [`lab_sys_setenv()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_sys_setenv.md)
  : Diagnose Unrestored Environment Variables

- [`lab_hardcoded_credentials()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_hardcoded_credentials.md)
  : Diagnose Hardcoded Credentials in Package Code

- [`lab_internal_ns()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_internal_ns.md)
  :

  Diagnose `:::` in Package Code

## DESCRIPTION checks

Individual checks on the DESCRIPTION file, parsed via
[`base::read.dcf()`](https://rdrr.io/r/base/dcf.html).

- [`lab_software_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_software_names.md)
  : Diagnose Unquoted Software Names in DESCRIPTION
- [`lab_language_names()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_language_names.md)
  : Diagnose Programming-Language Names in DESCRIPTION
- [`lab_acronyms()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_acronyms.md)
  : Diagnose Unexplained Acronyms in DESCRIPTION
- [`lab_license()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_license.md)
  : Diagnose the License Field
- [`lab_license_year()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_license_year.md)
  : Diagnose an Unfilled LICENSE Template
- [`lab_title_case()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_title_case.md)
  : Diagnose Title Case in DESCRIPTION
- [`lab_title_length()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_title_length.md)
  : Diagnose Title Length
- [`lab_title_starts_with_article()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_title_starts_with_article.md)
  : Diagnose Title Starting With an Article
- [`lab_title_redundant_phrases()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_title_redundant_phrases.md)
  : Diagnose Redundant Phrases in Title
- [`lab_description_function_quotes()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_description_function_quotes.md)
  : Diagnose Single-Quoted Function Names
- [`lab_authors()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_authors.md)
  : Diagnose the Authors@R Field
- [`lab_identifier_format()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_identifier_format.md)
  : Diagnose Author Identifier Formatting
- [`lab_cph_role()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_cph_role.md)
  : Diagnose a Missing Copyright-Holder Role
- [`lab_references()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_references.md)
  : Diagnose Reference Formatting in DESCRIPTION
- [`lab_date_format()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_date_format.md)
  : Diagnose the DESCRIPTION Date Field
- [`lab_encoding_utf8()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_encoding_utf8.md)
  : Diagnose a Non-Portable DESCRIPTION Encoding
- [`lab_version_format()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_version_format.md)
  : Diagnose the DESCRIPTION Version Field
- [`lab_spelling()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_spelling.md)
  : Diagnose Possibly Misspelled Words in DESCRIPTION
- [`lab_description_length()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_description_length.md)
  : Diagnose Description Length
- [`lab_description_starts_with()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_description_starts_with.md)
  : Diagnose the Description Opening
- [`lab_description_quoted_quotes()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_description_quoted_quotes.md)
  : Diagnose Double-Quoted Software Names

## Documentation checks

Individual checks on `.Rd` files, walked via
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html).

- [`lab_value_tags()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_value_tags.md)
  : Diagnose Missing Value Tags in Documentation
- [`lab_missing_examples()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_missing_examples.md)
  : Diagnose Exported Functions Missing Examples
- [`lab_roxygen_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_roxygen_usage.md)
  : Diagnose Stale Generated Documentation
- [`lab_example_structure()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_example_structure.md)
  : Diagnose Example Structure
- [`lab_unexported_example_ns()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_unexported_example_ns.md)
  : Diagnose Bare Calls to Unexported Functions in Examples
- [`lab_commented_examples()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_commented_examples.md)
  : Diagnose Examples That Run Nothing
- [`lab_donttest_vs_dontrun()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_donttest_vs_dontrun.md)
  : Diagnose dontrun Where donttest Belongs
- [`lab_suggested_in_examples()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_suggested_in_examples.md)
  : Diagnose Suggested Packages Used in Examples Without a Guard

## Example, vignette and demo checks

Individual checks on the code CRAN reads outside `R/`: the examples in
`.Rd` files, vignette chunks, and demos.

- [`lab_example_interactive()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_example_interactive.md)
  :

  Diagnose Interactive Examples Wrapped in `\\dontrun{}`

- [`lab_example_installs()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_example_installs.md)
  : Diagnose Installs in Examples, Vignettes and Demos

- [`lab_example_writes()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_example_writes.md)
  : Diagnose Writes Outside the Temporary Directory in Examples

- [`lab_example_state()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_example_state.md)
  : Diagnose Session State Left Changed by Examples

- [`lab_example_internal_ns()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_example_internal_ns.md)
  :

  Diagnose `:::` in Examples

## General checks

Package-level checks covering size, URLs, NEWS and README links.

- [`lab_package_size()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_package_size.md)
  : Diagnose Package Size
- [`lab_urls()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_urls.md)
  : Diagnose URL Issues in Package Files
- [`lab_url_liveness()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_url_liveness.md)
  : Diagnose Broken and Redirecting URLs
- [`lab_news_file()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_news_file.md)
  : Diagnose a Missing NEWS File
- [`lab_readme_links()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_readme_links.md)
  : Diagnose Relative Links in the README
- [`lab_cran_comments_file()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_cran_comments_file.md)
  : Diagnose a Missing cran-comments.md File

## CRAN policy checks

Individual checks for common CRAN policy violations, covering debugging
leftovers, raw shell calls, and file and network access.

- [`lab_browser_calls()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_browser_calls.md)
  : Diagnose Leftover browser() Calls
- [`lab_system_calls()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_system_calls.md)
  : Diagnose System Calls
- [`lab_file_operations()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_file_operations.md)
  : Diagnose Writes to the User's Filespace
- [`lab_network_operations()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_network_operations.md)
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

- [`find_package_root()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/find_package_root.md)
  : Find the Root of the Package Containing a Path

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

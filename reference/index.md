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

## DESCRIPTION-field diagnostics

Checks against the DESCRIPTION file, parsed via
[`base::read.dcf()`](https://rdrr.io/r/base/dcf.html).

- [`diagnose_description_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_description_issues.md)
  : Diagnose DESCRIPTION File Issues

## Documentation diagnostics

Checks against `.Rd` files, walked via
[`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html).

- [`diagnose_documentation_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_documentation_issues.md)
  : Diagnose Documentation Issues
- [`diagnose_value_tags()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_value_tags.md)
  : Diagnose Missing Value Tags in Documentation
- [`diagnose_roxygen_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_roxygen_usage.md)
  : Diagnose Roxygen2 Usage
- [`diagnose_example_structure()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_example_structure.md)
  : Diagnose Example Structure

## General-purpose diagnostics

Package-size and URL checks that don’t fit other categories.

- [`diagnose_general_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_general_issues.md)
  : Diagnose General Package Issues
- [`diagnose_package_size()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_package_size.md)
  : Diagnose Package Size
- [`diagnose_urls()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_urls.md)
  : Diagnose URL Issues in Package Files

## CRAN policy diagnostics

Checks targeting common CRAN policy violations (debugging leftovers, raw
shell calls, file/network access).

- [`diagnose_policy_violations()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_policy_violations.md)
  : Check for Common CRAN Policy Violations

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

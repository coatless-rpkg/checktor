# Register a Custom Check with `checktor()`

Adds a check of your own to every subsequent
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
run without editing checktor's source. It joins the panel its category
already runs, appears in
[`issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/issues.md),
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) and the
printed report, and counts toward the verdict at the severity tier you
declare.

## Usage

``` r
register_check(
  name,
  fn,
  category = CHECK_CATEGORIES,
  severity = c("robustness", "policy", "opinion")
)
```

## Arguments

- name:

  Character. The check's key, used in results and reports. Must not
  clash with a built-in check name. Naming the function `lab_<name>()`
  keeps it consistent with the built-in checks, where the two always
  match.

- fn:

  A function returning a
  [`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md),
  the same shape as any `lab_*` check. It is called as
  `fn(path, verbose)`. If it also declares a `parsed` argument (for
  `code` and `policy` checks) or a `desc` argument (for `description`
  checks), checktor forwards its shared parse cache so the check does
  not re-read the sources.

- category:

  Character. Which category the check joins: one of `"code"`,
  `"description"`, `"documentation"`, `"general"`, `"policy"`.

- severity:

  Character. The tier the check reports at: one of `"robustness"`
  (default), `"policy"`, or `"opinion"`. This decides whether a finding
  counts against a clean bill of health under
  [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)'s
  `severity` argument.

## Value

Invisibly, `name`.

## Details

A registered check joins one of the five built-in categories. There is
no way to add a category of your own, so pick the panel your check
belongs to.

## See also

[`unregister_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/unregister_check.md),
[`registered_checks()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/registered_checks.md),
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)

## Examples

``` r
# A house rule: flag any call to a banned helper.
lab_no_banned <- function(path, verbose = TRUE, parsed = NULL) {
  if (is.null(parsed)) parsed <- read_r_xml(path)
  issues <- undesirable_function_check(parsed, "banned_helper")
  checktor_check_result(length(issues) == 0L, issues, "no banned_helper()")
}
register_check("no_banned", lab_no_banned,
               category = "code", severity = "policy")

registered_checks()
#>       check category severity
#> 1 no_banned     code   policy
unregister_check("no_banned")
```

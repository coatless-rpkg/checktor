# Design: Result accessors + example/print cleanup

**Date:** 2026-06-25
**Status:** Approved (pending spec review)
**Scope:** Add a discoverable accessor layer over `checktor` result objects so users never
navigate nested sublists, rewrite `@examples` to show results instead of internals, and tidy
two rough edges in the printed output.

## Motivation

Today, to learn anything programmatically a user must walk three levels of list:

```r
results$metadata$total_issues          # how many issues
results$code_issues$tf_usage$passed    # did one check pass
results$code_issues$tf_usage$issues    # where are the problems
```

The `@examples` teach exactly this pattern. We want plain, discoverable accessors and examples
that demonstrate them. checktor is **not yet on CRAN** (only win-builder test runs), so we are
free to change the object structure and API before the first release.

## In scope

1. An accessor layer (new generics + base-method overrides) over the three result classes.
2. Tag category objects with a class so the generics can dispatch on them.
3. Rewrite `@examples` across all exported functions to use the accessors / printed objects.
4. Two print tweaks to `print.checktor_results`.
5. Tests, docs, pkgdown reference section, NEWS entry.

## Out of scope (YAGNI)

- Enriching check `$message` into per-issue remediation text — `prescribe()` owns remediation.
- `broom::glance()` / `augment()`, tibble/dplyr dependencies.
- Any cli styling of the returned data frames (they are plain frames so users can compute on them;
  the styled overview remains `print(results)`).

## Object structure change

Each category (`results$code_issues`, `$description_issues`, `$documentation_issues`,
`$general_issues`, `$policy_issues`) currently is a bare `list` (named `checktor_check_result`s
plus a `passed` named-logical). We will tag it with class **`checktor_category_result`** (the
constructor and `print.checktor_category_result` already exist but are unused) so accessors
dispatch on it. Internal structure is unchanged — `results$code_issues$tf_usage$passed` and the
`$passed` vector keep working. The orchestrator (`checktor()`) and the `diagnose_*_issues()`
category functions return classed categories.

## New API (new file `R/accessors.R`)

New **generics owned by checktor** (export generic + register methods); dispatch on
`checktor_results`, `checktor_category_result`, and `checktor_check_result` where meaningful:

| Generic | check | category | results |
|---|---|---|---|
| `issues(x)` | df: file,line,location,message | + `check` col | + `category` col |
| `passed(x)` | scalar logical | named lgl by check | named lgl by category |
| `is_healthy(x)` | `x$passed` | `all(passed(x))` | `total_issues == 0` |
| `n_issues(x)` | `length(x$issues)` | sum over checks | `total_issues` |
| `n_failed_checks(x)` | — | `sum(!passed)` | `failed_checks` (count) |
| `failed_checks(x)` | — | failing check names (chr) | qualified `"code.tf_usage"` (chr) |

**`tidy()`** — imported from the lightweight **`generics`** package (`@importFrom generics tidy`,
re-exported), per-**check** table:

- `tidy(results)` → `category, check, passed, n_issues, message` (one row per check run).
- `tidy(category)` → `check, passed, n_issues, message`.

**Base-method overrides:**

- `summary(results)` → per-**category** df: `category, checks, passed, failed, issues` (5 rows).
- `summary(category)` → one-row overview: `checks, passed, failed, issues`.
- `as.data.frame(x)` ≡ `tidy(x)` at each level.

All returned frames are base `data.frame` (`stringsAsFactors = FALSE`). A healthy object returns a
**0-row** frame with the correct columns/types (not `NULL`). `file`/`line` are parsed from the raw
`"file:line"` issue string; `line` is integer, both `NA` when an issue is not location-shaped
(e.g. a DESCRIPTION-level finding → `file = NA`, `location = "DESCRIPTION"`).

### Granularity summary (the three tables answer three questions)

- `summary()` — *how is each category?* (coarse, 5 rows)
- `tidy()` — *what did every check find?* (per check, all checks)
- `issues()` — *where exactly are the problems?* (per issue, failures only)

## Print tweaks (`print.checktor_results`)

1. **Footer:** replace the stale `Run `checktor()` for detailed diagnosis` (the user just ran it)
   with, when issues exist: `Run `summary()`, `issues()`, or `prescribe()` for details`. When
   healthy, no remediation footer (keep the clean-bill verdict line).
2. **`Patient:` line:** stop dumping the wrapped temp path. Show the package name from the
   `DESCRIPTION` `Package:` field when available, else `basename(path)`; keep it on one line.

## Examples rewrite

Every `@examples` that reaches into internals switches to accessors / printed objects:

- `checktor.R` — `results` (auto-print) → `summary(results)` → `issues(results)` → `is_healthy(results)`.
- `diagnostics-*.R` (`diagnose_*_issues` and individual `diagnose_*`) — replace `...$passed` /
  `...$issues` with printing the returned object and/or `issues(...)` / `tidy(...)`.
- `prescribe` / `health_report` examples unchanged.

## Tests (`tests/testthat/test-accessors.R`, testthat 3e, TDD)

Using `example_diagnose_scenario("code_examples/tf_usage_bad.R")` (known: code 1 failed/7 issues,
description 3 failed/3 issues, 10 issues total) plus a clean fixture via `write_pkg()`:

- `issues()`/`tidy()`/`summary()` row counts, column names, and column types at each level.
- Healthy package → 0-row `issues()`, `is_healthy()` TRUE, `n_issues()` 0.
- `passed()` shape at all three levels; `is_healthy()`, `n_issues()`, `n_failed_checks()`,
  `failed_checks()` values.
- `as.data.frame(x)` identical to `tidy(x)`.
- `class(results$code_issues) == "checktor_category_result"`.
- Print tweaks via `expect_snapshot(print(results))` (footer + Patient line).

## Docs / packaging

- roxygen for every new function; `devtools::document()`.
- `_pkgdown.yml`: new **Result accessors** reference section listing the generics.
- `NEWS.md`: entry under 0.1.0 describing the accessors and the print/example cleanup.
- DESCRIPTION: add `generics` to **Imports**. No other new dependencies.

## Backward compatibility

Pre-CRAN, pre-1.0 — free to change. Nested access (`results$code_issues$tf_usage$passed`) still
works since the structure is preserved and only a class attribute is added.

## Open questions

None outstanding — `as.data.frame ≡ tidy`, plain data frames, `generics` for `tidy()`, and both
print tweaks are confirmed.

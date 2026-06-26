# Result Accessors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a plain, discoverable accessor layer (`issues()`, `tidy()`, `summary()`, `passed()`, predicates) over checktor result objects, rewrite examples to use it, and tidy two print rough edges.

**Architecture:** Tag category objects with the existing `checktor_category_result` class at the single assembly point (`run_checks()`), then add S3 generics + base-method overrides in a new `R/accessors.R`. Results-level methods iterate the category lists *structurally* (by name / `$issues`), so they work even if a category is an unclassed early-return list. All accessors return base `data.frame`.

**Tech Stack:** R (S3), `generics` (for `tidy()`), `cli` (existing UI), testthat 3e.

## Global Constraints

- R (>= 3.5.0) — do NOT use base `%||%` (R 4.4+) or other newer base features. Define helpers explicitly.
- New dependency allowed: `generics` (Imports) — for `tidy()` only. No other new deps.
- All returned tables are base `data.frame(..., stringsAsFactors = FALSE)`; healthy objects return **0-row** frames with correct columns/types, never `NULL`.
- Accessor names are plain (no metaphor, no aliases): `issues`, `passed`, `is_healthy`, `n_issues`, `n_failed_checks`, `failed_checks`, `tidy`, `summary`, `as.data.frame`.
- All user-facing console output uses `cli` (never `cat`/`message`/`print`).
- Roxygen markdown is on; run `devtools::document()` after editing roxygen — never hand-edit `man/*.Rd` or `NAMESPACE`.
- testthat 3e; use `helper-package.R` fixtures (`write_pkg()`, `make_temp_dir()`) and `example_diagnose_scenario()`.
- Pre-CRAN: nested access (`results$code_issues$tf_usage$passed`) MUST keep working.

**Known scenario facts** (from `example_diagnose_scenario("code_examples/tf_usage_bad.R")`): code 13 checks / 1 failed / 7 issues; description 14 / 3 / 3; documentation 6 / 0 / 0; general 2 / 0 / 0; policy 4 / 0 / 0; `total_issues = 10`, `failed_checks = 4`; 39 checks total.

**Category short-name map** (reused in several methods — copy verbatim):
```r
.checktor_cat_map <- c(
  code          = "code_issues",
  description    = "description_issues",
  documentation = "documentation_issues",
  general       = "general_issues",
  policy        = "policy_issues"
)
```

---

### Task 1: Class category objects

**Files:**
- Modify: `R/utils.R` (`run_checks()`, ~line 128–148)
- Modify: `R/diagnostics-code.R:38`, `R/diagnostics-description.R:33,42` (early-return lists)
- Test: `tests/testthat/test-accessors.R` (create)

**Interfaces:**
- Produces: every category in a `checktor_results` object, and every value returned by a `diagnose_*_issues()` function, has class `"checktor_category_result"`.

- [ ] **Step 1: Write the failing test**

```r
# tests/testthat/test-accessors.R
test_that("category objects are classed checktor_category_result", {
  pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_s3_class(r$code_issues, "checktor_category_result")
  expect_s3_class(diagnose_code_issues(pkg, verbose = FALSE), "checktor_category_result")
  # nested access still works
  expect_false(r$code_issues$tf_usage$passed)
  expect_type(r$code_issues$passed, "logical")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-accessors.R")'`
Expected: FAIL — `r$code_issues` inherits `"list"`, not `"checktor_category_result"`.

- [ ] **Step 3: Implement — class in `run_checks()` and early returns**

In `R/utils.R`, `run_checks()`, change the final two lines from:
```r
  results$passed <- summarise_passed(results[names(checks)])
  results
}
```
to:
```r
  results$passed <- summarise_passed(results[names(checks)])
  class(results) <- "checktor_category_result"
  results
}
```

In `R/diagnostics-code.R:38`, change:
```r
    return(list(passed = TRUE, message = "No R directory found"))
```
to:
```r
    out <- list(passed = TRUE, message = "No R directory found")
    class(out) <- "checktor_category_result"
    return(out)
```

In `R/diagnostics-description.R`, apply the same wrap to both early returns (lines 33 and 42), preserving their existing `passed`/`message` values:
```r
    out <- list(passed = FALSE, message = "DESCRIPTION file not found")
    class(out) <- "checktor_category_result"
    return(out)
```
```r
    out <- list(passed = FALSE, message = "Could not parse DESCRIPTION file")
    class(out) <- "checktor_category_result"
    return(out)
```

- [ ] **Step 4: Run new test + full suite to verify pass and no regression**

Run: `Rscript -e 'devtools::load_all(); testthat::test_dir("tests/testthat")'`
Expected: PASS, including all pre-existing tests (the class attribute does not change `names()` or `$` access, on which `count_results()` and the print methods rely).

- [ ] **Step 5: Commit**

```bash
git add R/utils.R R/diagnostics-code.R R/diagnostics-description.R tests/testthat/test-accessors.R
git commit -m "feat: class category results as checktor_category_result"
```

---

### Task 2: issues() generic + methods

**Files:**
- Create: `R/accessors.R`
- Test: `tests/testthat/test-accessors.R` (append)

**Interfaces:**
- Consumes: `checktor_category_result` class (Task 1); check objects with `$issues` (chr `"file:line"`) and `$message`.
- Produces:
  - `issues(check)` → df cols `file, line, location, message`
  - `issues(category)` → df cols `check, file, line, location, message`
  - `issues(results)` → df cols `category, check, file, line, location, message`
  - internal `.split_issue(chr)` → df `file, line, location`
  - internal `.category_issue_df(cat, category = NA_character_)`
  - `.checktor_cat_map` constant (see Global Constraints)

- [ ] **Step 1: Write the failing test**

```r
test_that("issues() returns a tidy per-issue frame at each level", {
  pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  di <- issues(r)
  expect_s3_class(di, "data.frame")
  expect_identical(names(di), c("category","check","file","line","location","message"))
  expect_equal(nrow(di), 10L)                       # total_issues
  expect_equal(sum(di$check == "tf_usage"), 7L)
  expect_type(di$line, "integer")

  ci <- issues(r$code_issues)
  expect_identical(names(ci), c("check","file","line","location","message"))
  expect_equal(nrow(ci), 7L)

  one <- issues(r$code_issues$tf_usage)
  expect_identical(names(one), c("file","line","location","message"))
  expect_equal(nrow(one), 7L)
  expect_equal(one$file[1], "tf_usage_bad.R")
  expect_equal(one$line[1], 8L)
})

test_that("issues() on a healthy package is a 0-row typed frame", {
  pkg <- write_pkg()                                 # clean fixture
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  di <- issues(r)
  expect_equal(nrow(di), 0L)
  expect_identical(names(di), c("category","check","file","line","location","message"))
  expect_type(di$line, "integer")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-accessors.R")'`
Expected: FAIL — `could not find function "issues"`.

- [ ] **Step 3: Implement `R/accessors.R`**

```r
# Short-name -> results field map, reused across accessors.
.checktor_cat_map <- c(
  code          = "code_issues",
  description    = "description_issues",
  documentation = "documentation_issues",
  general       = "general_issues",
  policy        = "policy_issues"
)

# Split "file.R:12" into file + integer line; non-locational issues keep the
# raw string as `location` with file/line = NA.
.split_issue <- function(issues) {
  issues <- as.character(issues)
  m <- regmatches(issues, regexec("^(.*):([0-9]+)$", issues))
  file <- vapply(m, function(g) if (length(g) == 3L) g[[2]] else NA_character_, character(1))
  line <- vapply(m, function(g) if (length(g) == 3L) as.integer(g[[3]]) else NA_integer_, integer(1))
  data.frame(file = file, line = line, location = issues, stringsAsFactors = FALSE)
}

# Per-issue frame for one category list. `category` adds a leading column when
# not NA (used by the results-level method).
.category_issue_df <- function(cat, category = NA_character_) {
  check_names <- setdiff(names(cat), "passed")
  parts <- lapply(check_names, function(nm) {
    ch <- cat[[nm]]
    if (!is.list(ch)) return(NULL)
    iss <- ch$issues
    if (is.null(iss) || length(iss) == 0L) return(NULL)
    df <- .split_issue(iss)
    df$check <- nm
    df$message <- if (is.null(ch$message)) NA_character_ else ch$message
    df[, c("check", "file", "line", "location", "message")]
  })
  parts <- Filter(Negate(is.null), parts)
  if (length(parts) == 0L) {
    out <- data.frame(check = character(0), file = character(0), line = integer(0),
                      location = character(0), message = character(0),
                      stringsAsFactors = FALSE)
  } else {
    out <- do.call(rbind, parts)
    rownames(out) <- NULL
  }
  if (!is.na(category)) out <- cbind(category = category, out, stringsAsFactors = FALSE)
  out
}

#' Extract issues, checks, or a per-category summary from checktor results
#'
#' Plain accessors over the objects returned by [checktor()] and the
#' `diagnose_*_issues()` functions, so you never navigate nested sublists.
#'
#' @param x A `checktor_results`, `checktor_category_result`, or
#'   `checktor_check_result` object.
#' @param ... Unused.
#'
#' @return `issues()` returns a `data.frame` with one row per issue. At the
#'   results level the columns are `category`, `check`, `file`, `line`,
#'   `location`, `message`; a single category drops `category`; a single check
#'   drops `category` and `check`. A healthy object yields a 0-row frame.
#'
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' issues(results)
#' @export
issues <- function(x, ...) UseMethod("issues")

#' @rdname issues
#' @export
issues.checktor_check_result <- function(x, ...) {
  if (length(x$issues) == 0L) {
    return(data.frame(file = character(0), line = integer(0),
                      location = character(0), message = character(0),
                      stringsAsFactors = FALSE))
  }
  df <- .split_issue(x$issues)
  df$message <- if (is.null(x$message)) NA_character_ else x$message
  df
}

#' @rdname issues
#' @export
issues.checktor_category_result <- function(x, ...) .category_issue_df(x, NA_character_)

#' @rdname issues
#' @export
issues.checktor_results <- function(x, ...) {
  parts <- lapply(names(.checktor_cat_map), function(short) {
    cn <- .checktor_cat_map[[short]]
    if (!cn %in% names(x)) return(NULL)
    df <- .category_issue_df(x[[cn]], category = short)
    if (nrow(df) == 0L) return(NULL)
    df[, c("category","check","file","line","location","message")]
  })
  parts <- Filter(Negate(is.null), parts)
  if (length(parts) == 0L) {
    return(data.frame(category = character(0), check = character(0),
                      file = character(0), line = integer(0),
                      location = character(0), message = character(0),
                      stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}
```

- [ ] **Step 4: Document and run the tests**

Run: `Rscript -e 'devtools::document(); devtools::load_all(); testthat::test_file("tests/testthat/test-accessors.R")'`
Expected: PASS (4 generics/methods registered in NAMESPACE; both `issues()` tests green).

- [ ] **Step 5: Commit**

```bash
git add R/accessors.R NAMESPACE man tests/testthat/test-accessors.R
git commit -m "feat: add issues() accessor over results/category/check"
```

---

### Task 3: passed(), is_healthy(), and count predicates

**Files:**
- Modify: `R/accessors.R` (append)
- Test: `tests/testthat/test-accessors.R` (append)

**Interfaces:**
- Consumes: `.checktor_cat_map`; `$passed` vectors; `metadata$total_issues`, `metadata$failed_checks`.
- Produces: `passed(x)`, `is_healthy(x)`, `n_issues(x)`, `n_failed_checks(x)`, `failed_checks(x)` generics + methods.

- [ ] **Step 1: Write the failing test**

```r
test_that("predicates report status without sublist navigation", {
  pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  expect_false(is_healthy(r))
  expect_equal(n_issues(r), 10L)
  expect_equal(n_failed_checks(r), 4L)

  expect_true("code.tf_usage" %in% failed_checks(r))
  expect_type(failed_checks(r), "character")

  pc <- passed(r$code_issues)
  expect_type(pc, "logical"); expect_false(pc[["tf_usage"]]); expect_true(pc[["seed_setting"]])
  expect_false(passed(r$code_issues$tf_usage))
  expect_equal(n_issues(r$code_issues$tf_usage), 7L)

  clean <- checktor(write_pkg(), verbose = FALSE, progress = FALSE)
  expect_true(is_healthy(clean)); expect_equal(n_issues(clean), 0L)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-accessors.R")'`
Expected: FAIL — `could not find function "is_healthy"`.

- [ ] **Step 3: Implement (append to `R/accessors.R`)**

```r
#' Status predicates for checktor results
#'
#' @param x A `checktor_results`, `checktor_category_result`, or
#'   `checktor_check_result` object.
#' @param ... Unused.
#' @return `passed()`: logical — a single value for a check, a named logical by
#'   check for a category, and a named logical by category for results.
#'   `is_healthy()`: a single logical. `n_issues()` / `n_failed_checks()`:
#'   integer counts. `failed_checks()`: character vector of failing check names
#'   (qualified `"category.check"` at the results level).
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' is_healthy(results)
#' failed_checks(results)
#' @name predicates
NULL

#' @rdname predicates
#' @export
passed <- function(x, ...) UseMethod("passed")
#' @rdname predicates
#' @export
passed.checktor_check_result <- function(x, ...) isTRUE(x$passed)
#' @rdname predicates
#' @export
passed.checktor_category_result <- function(x, ...) x$passed
#' @rdname predicates
#' @export
passed.checktor_results <- function(x, ...) {
  vapply(names(.checktor_cat_map), function(short) {
    cn <- .checktor_cat_map[[short]]
    if (!cn %in% names(x)) return(NA)
    all(x[[cn]]$passed, na.rm = TRUE)
  }, logical(1))
}

#' @rdname predicates
#' @export
is_healthy <- function(x, ...) UseMethod("is_healthy")
#' @rdname predicates
#' @export
is_healthy.checktor_check_result <- function(x, ...) isTRUE(x$passed)
#' @rdname predicates
#' @export
is_healthy.checktor_category_result <- function(x, ...) all(x$passed, na.rm = TRUE)
#' @rdname predicates
#' @export
is_healthy.checktor_results <- function(x, ...) x$metadata$total_issues == 0L

#' @rdname predicates
#' @export
n_issues <- function(x, ...) UseMethod("n_issues")
#' @rdname predicates
#' @export
n_issues.checktor_check_result <- function(x, ...) length(x$issues)
#' @rdname predicates
#' @export
n_issues.checktor_category_result <- function(x, ...) {
  sum(vapply(setdiff(names(x), "passed"),
             function(nm) length(x[[nm]]$issues), integer(1)))
}
#' @rdname predicates
#' @export
n_issues.checktor_results <- function(x, ...) x$metadata$total_issues

#' @rdname predicates
#' @export
n_failed_checks <- function(x, ...) UseMethod("n_failed_checks")
#' @rdname predicates
#' @export
n_failed_checks.checktor_category_result <- function(x, ...) sum(!x$passed, na.rm = TRUE)
#' @rdname predicates
#' @export
n_failed_checks.checktor_results <- function(x, ...) x$metadata$failed_checks

#' @rdname predicates
#' @export
failed_checks <- function(x, ...) UseMethod("failed_checks")
#' @rdname predicates
#' @export
failed_checks.checktor_category_result <- function(x, ...) {
  p <- x$passed
  names(p)[!p]
}
#' @rdname predicates
#' @export
failed_checks.checktor_results <- function(x, ...) {
  out <- character(0)
  for (short in names(.checktor_cat_map)) {
    cn <- .checktor_cat_map[[short]]
    if (!cn %in% names(x)) next
    p <- x[[cn]]$passed
    failed <- names(p)[!p]
    if (length(failed)) out <- c(out, paste0(short, ".", failed))
  }
  out
}
```

- [ ] **Step 4: Document and run the tests**

Run: `Rscript -e 'devtools::document(); devtools::load_all(); testthat::test_file("tests/testthat/test-accessors.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/accessors.R NAMESPACE man tests/testthat/test-accessors.R
git commit -m "feat: add passed()/is_healthy()/n_issues()/failed_checks() predicates"
```

---

### Task 4: tidy(), summary(), as.data.frame()

**Files:**
- Modify: `DESCRIPTION` (add `generics` to Imports)
- Modify: `R/accessors.R` (append) and `R/checktor-package.R` (add `@importFrom generics tidy`)
- Test: `tests/testthat/test-accessors.R` (append)

**Interfaces:**
- Consumes: `.checktor_cat_map`; category `$passed` and per-check `$issues`/`$message`.
- Produces:
  - `tidy(results)` → df `category, check, passed, n_issues, message`; `tidy(category)` → df `check, passed, n_issues, message`
  - `summary(results)` → df `category, checks, passed, failed, issues` (5 rows); `summary(category)` → 1-row `checks, passed, failed, issues`
  - `as.data.frame(x)` ≡ `tidy(x)`
  - internal `.category_tidy_df(cat, category = NA_character_)`

- [ ] **Step 1: Write the failing test**

```r
test_that("tidy() is per-check and summary() is per-category", {
  pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)

  td <- tidy(r)
  expect_identical(names(td), c("category","check","passed","n_issues","message"))
  expect_equal(nrow(td), 39L)                        # all checks
  expect_equal(td$n_issues[td$check == "tf_usage"], 7L)
  expect_identical(as.data.frame(r), td)             # as.data.frame == tidy

  s <- summary(r)
  expect_identical(names(s), c("category","checks","passed","failed","issues"))
  expect_equal(nrow(s), 5L)
  expect_equal(s$issues[s$category == "code"], 7L)
  expect_equal(s$failed[s$category == "description"], 3L)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-accessors.R")'`
Expected: FAIL — `could not find function "tidy"`.

- [ ] **Step 3a: Add the dependency + import**

In `DESCRIPTION`, add `generics` to `Imports:` (alphabetical-ish, after `cli`):
```
Imports:
    utils,
    tools,
    cli (>= 3.0.0),
    generics,
    xml2,
    xmlparsedata
```

In `R/checktor-package.R`, add an importFrom so the generic is available and re-exported. Add these roxygen lines in the package doc block:
```r
#' @importFrom generics tidy
#' @export
generics::tidy
```

- [ ] **Step 3b: Implement (append to `R/accessors.R`)**

```r
# Per-check frame for one category list.
.category_tidy_df <- function(cat, category = NA_character_) {
  check_names <- setdiff(names(cat), "passed")
  if (length(check_names) == 0L) {
    out <- data.frame(check = character(0), passed = logical(0),
                      n_issues = integer(0), message = character(0),
                      stringsAsFactors = FALSE)
  } else {
    out <- data.frame(
      check    = check_names,
      passed   = vapply(check_names, function(nm) isTRUE(cat[[nm]]$passed), logical(1)),
      n_issues = vapply(check_names, function(nm) length(cat[[nm]]$issues), integer(1)),
      message  = vapply(check_names, function(nm) {
        m <- cat[[nm]]$message; if (is.null(m)) NA_character_ else m
      }, character(1)),
      stringsAsFactors = FALSE, row.names = NULL
    )
  }
  if (!is.na(category)) out <- cbind(category = category, out, stringsAsFactors = FALSE)
  out
}

#' Tidy a checktor result into a per-check data frame
#'
#' @param x A `checktor_results` or `checktor_category_result` object.
#' @param ... Unused.
#' @return A `data.frame` with one row per check: `category` (results level
#'   only), `check`, `passed`, `n_issues`, `message`.
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' tidy(results)
#' @rdname tidy
#' @exportS3Method generics::tidy
tidy.checktor_results <- function(x, ...) {
  parts <- lapply(names(.checktor_cat_map), function(short) {
    cn <- .checktor_cat_map[[short]]
    if (!cn %in% names(x)) return(NULL)
    .category_tidy_df(x[[cn]], category = short)[, c("category","check","passed","n_issues","message")]
  })
  out <- do.call(rbind, Filter(Negate(is.null), parts))
  rownames(out) <- NULL
  out
}

#' @rdname tidy
#' @exportS3Method generics::tidy
tidy.checktor_category_result <- function(x, ...) .category_tidy_df(x, NA_character_)

#' @rdname tidy
#' @export
as.data.frame.checktor_results <- function(x, ...) tidy(x)
#' @rdname tidy
#' @export
as.data.frame.checktor_category_result <- function(x, ...) tidy(x)

#' Per-category summary of checktor results
#'
#' @param object A `checktor_results` or `checktor_category_result` object.
#' @param ... Unused.
#' @return For results: a 5-row `data.frame` (`category, checks, passed,
#'   failed, issues`). For a category: a 1-row `data.frame` (`checks, passed,
#'   failed, issues`).
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#' summary(results)
#' @rdname checktor-summary
#' @export
summary.checktor_category_result <- function(object, ...) {
  p <- object$passed
  checks <- length(p); passed <- sum(p, na.rm = TRUE)
  issues <- sum(vapply(setdiff(names(object), "passed"),
                       function(nm) length(object[[nm]]$issues), integer(1)))
  data.frame(checks = checks, passed = passed, failed = checks - passed,
             issues = issues, stringsAsFactors = FALSE)
}

#' @rdname checktor-summary
#' @export
summary.checktor_results <- function(object, ...) {
  rows <- lapply(names(.checktor_cat_map), function(short) {
    cn <- .checktor_cat_map[[short]]
    if (!cn %in% names(object)) return(NULL)
    s <- summary.checktor_category_result(object[[cn]])
    cbind(category = short, s, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, Filter(Negate(is.null), rows))
  rownames(out) <- NULL
  out
}
```

- [ ] **Step 4: Document and run the tests**

Run: `Rscript -e 'devtools::document(); devtools::load_all(); testthat::test_file("tests/testthat/test-accessors.R")'`
Expected: PASS. Confirm NAMESPACE gained `export(tidy)` (re-export) and `S3method(tidy, checktor_results)` etc.

- [ ] **Step 5: Commit**

```bash
git add DESCRIPTION R/accessors.R R/checktor-package.R NAMESPACE man tests/testthat/test-accessors.R
git commit -m "feat: add tidy()/summary()/as.data.frame() result methods"
```

---

### Task 5: Print tweaks

**Files:**
- Modify: `R/checktor.R` (`print.checktor_results`, lines ~184–214)
- Test: `tests/testthat/test-accessors.R` (append, snapshot)

**Interfaces:**
- Consumes: `x$metadata$package_path`, `x$metadata$total_issues`.
- Produces: footer pointing to accessors; `Patient:` shows the package name.

- [ ] **Step 1: Write the failing test**

```r
test_that("print footer points to accessors and Patient shows package name", {
  pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  out <- cli::cli_fmt(print(r))
  txt <- paste(out, collapse = "\n")
  expect_match(txt, "summary\\(\\)")
  expect_match(txt, "issues\\(\\)")
  expect_false(grepl("Run `checktor\\(\\)` for detailed diagnosis", txt))
  # Patient line shows a short package name, not the wrapped temp path
  expect_false(grepl("/var/folders|/tmp/|Rtmp", txt))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-accessors.R")'`
Expected: FAIL — footer still says "Run `checktor()`…" and Patient prints the temp path.

- [ ] **Step 3: Implement**

Add a helper near the top of `R/checktor.R` (after the `checktor()` function):
```r
# Human-friendly package label: the DESCRIPTION Package field if readable,
# else the directory basename.
package_label <- function(path) {
  desc <- file.path(path, "DESCRIPTION")
  if (file.exists(desc)) {
    nm <- tryCatch(unname(read.dcf(desc, fields = "Package")[1, 1]),
                   error = function(e) NA_character_)
    if (!is.na(nm) && nzchar(nm)) return(nm)
  }
  basename(normalizePath(path, mustWork = FALSE))
}
```

In `print.checktor_results`, replace:
```r
  cli::cli_text("Patient: {.path {x$metadata$package_path}}")
```
with:
```r
  cli::cli_text("Patient: {.pkg {package_label(x$metadata$package_path)}}")
```

And replace the failing-branch footer:
```r
    cli::cli_text("Run {.code checktor()} for detailed diagnosis")
```
with:
```r
    cli::cli_text("Run {.code summary()}, {.code issues()}, or {.code prescribe()} for details")
```

- [ ] **Step 4: Run the test**

Run: `Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-accessors.R")'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/checktor.R tests/testthat/test-accessors.R
git commit -m "feat: print accessors footer and package-name Patient line"
```

---

### Task 6: Rewrite @examples to use accessors

**Files:**
- Modify: `R/checktor.R:53–58`, `R/diagnostics-code.R:30,117,152,189`,
  `R/diagnostics-description.R:22`, `R/diagnostics-documentation.R:29,83,163`,
  `R/diagnostics-general.R:100`, `R/diagnostics-policy.R:23`, `R/example-scenarios.R:56`

**Interfaces:**
- Consumes: `issues()`, `summary()`, `tidy()`, `is_healthy()` from Tasks 2–4.

- [ ] **Step 1: Rewrite each example site**

`R/checktor.R` — replace the three internal-access lines (currently `results$metadata$total_issues`, `results$metadata$failed_checks`, `results$code_issues$tf_usage$passed`) with:
```r
#' results              # the diagnosis summary
#' summary(results)     # per-category overview
#' issues(results)      # every issue as a tidy data frame
#' is_healthy(results)  # FALSE
```

`R/diagnostics-code.R:30` — replace `code_results$tf_usage$passed` with:
```r
#' summary(code_results)   # per-category overview
#' issues(code_results)    # the issues found
```
`R/diagnostics-code.R:117` — replace `diagnose_tf_usage(pkg, verbose = FALSE)$issues` with:
```r
#' issues(diagnose_tf_usage(pkg, verbose = FALSE))
```
`R/diagnostics-code.R:152` — replace `diagnose_seed_setting(pkg, verbose = FALSE)$passed` with:
```r
#' diagnose_seed_setting(pkg, verbose = FALSE)   # prints PASSED/FAILED
```
`R/diagnostics-code.R:189` — replace `diagnose_print_cat_usage(pkg, verbose = FALSE)$passed` with:
```r
#' diagnose_print_cat_usage(pkg, verbose = FALSE)
```
`R/diagnostics-description.R:22` — replace `results$license$passed` line with:
```r
#' issues(results)     # description-field problems, if any
```
`R/diagnostics-documentation.R:29` — replace `doc_results$value_tags$passed` with:
```r
#' summary(doc_results)
#' issues(doc_results)
```
`R/diagnostics-documentation.R:83` — replace `diagnose_value_tags(pkg_path, verbose = FALSE)$passed` with:
```r
#' issues(diagnose_value_tags(pkg_path, verbose = FALSE))
```
`R/diagnostics-documentation.R:163` — replace `diagnose_example_structure(pkg_path, verbose = FALSE)$passed` with:
```r
#' diagnose_example_structure(pkg_path, verbose = FALSE)
```
`R/diagnostics-general.R:100` — replace `diagnose_urls(pkg_path, verbose = FALSE)$passed` with:
```r
#' issues(diagnose_urls(pkg_path, verbose = FALSE))
```
`R/diagnostics-policy.R:23` — replace `policy$browser_calls$passed` with:
```r
#' summary(policy)
#' issues(policy)
```
`R/example-scenarios.R:56` — this example's `result` is the **path** returned by `example_diagnose_scenario()`, so `length(result$issues)` is wrong. Replace with a line that uses the path correctly, e.g.:
```r
#' issues(checktor(result, verbose = FALSE, progress = FALSE))
```
(Read the surrounding example first to confirm the variable name; adapt if it differs.)

- [ ] **Step 2: Document and run all examples**

Run: `Rscript -e 'devtools::document(); devtools::run_examples(document = FALSE)'`
Expected: all examples execute without error.

- [ ] **Step 3: Commit**

```bash
git add R man
git commit -m "docs: rewrite examples to use accessors instead of sublist navigation"
```

---

### Task 7: pkgdown reference, NEWS, and full verification

**Files:**
- Modify: `_pkgdown.yml` (new reference section), `NEWS.md`

- [ ] **Step 1: Add a pkgdown reference section**

In `_pkgdown.yml`, after the "Result classes" section, add:
```yaml
- title: Result accessors
  desc: >
    Plain accessors over diagnostic results so you never navigate nested
    sublists. Work on a full `checktor()` result, a single category, or a
    single check.
  contents:
  - issues
  - tidy
  - summary.checktor_results
  - predicates
```

- [ ] **Step 2: Add a NEWS entry**

In `NEWS.md`, under `# checktor 0.1.0`, add a bullet:
```markdown
* Added result accessors so you no longer navigate nested lists: `issues()`
  (per-issue table), `tidy()` (per-check table), `summary()` (per-category),
  plus `passed()`, `is_healthy()`, `n_issues()`, `n_failed_checks()`, and
  `failed_checks()`. `as.data.frame()` on a result is equivalent to `tidy()`.
```

- [ ] **Step 3: Validate pkgdown config**

Run: `Rscript -e 'pkgdown::check_pkgdown(".")'`
Expected: "No problems found." (all new topics are indexed).

- [ ] **Step 4: Full test suite + R CMD check with manual**

Run: `Rscript -e 'devtools::test()'` → expect all pass.
Run: `Rscript -e 'devtools::check(document = TRUE, manual = TRUE, args = "--as-cran")'`
Expected: `0 errors | 0 warnings | 0 notes`. (Confirms the new `generics` import is declared, all exports are documented, examples run, and the PDF manual still builds.)

- [ ] **Step 5: Commit**

```bash
git add _pkgdown.yml NEWS.md man NAMESPACE DESCRIPTION
git commit -m "docs: document result accessors in pkgdown and NEWS"
```

---

## Self-Review

- **Spec coverage:** object classing (Task 1), `issues`/`passed`/predicates (Tasks 2–3), `tidy`/`summary`/`as.data.frame` + `generics` dep (Task 4), print tweaks (Task 5), example rewrite (Task 6), pkgdown/NEWS/verification (Task 7). All spec sections mapped.
- **Granularity:** `summary` per-category, `tidy` per-check, `issues` per-issue; `as.data.frame ≡ tidy`. Matches spec.
- **Type consistency:** `.checktor_cat_map`, `.split_issue`, `.category_issue_df`, `.category_tidy_df`, `package_label` named identically across tasks; column orders consistent (`issues`: category,check,file,line,location,message; `tidy`: category,check,passed,n_issues,message; `summary`: category,checks,passed,failed,issues).
- **No new deps beyond `generics`.** Healthy objects return 0-row frames. Nested access preserved.

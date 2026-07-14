# checktor 0.2.0

## Checks removed

checktor exists to run the checks `R CMD check` does not. Seven checks failed that
test and have been removed. Each was verified by running `R CMD check --as-cran` on
a fixture that violates the rule.

* `urls`, `license`, `title_case`, `authors` (the presence half),
  `description_starts_with` and `unexported_example_ns` all duplicated
  `R CMD check`, and in each case R's version is better. R *fetches* every URL and
  reports status codes and redirect targets; R's title-case check restores
  single-quoted spans before comparing, which is why it does not flag `'shiny'`
  and ours did; R's missing-`Authors@R` NOTE even prints the `person()` call to
  paste in; and a bare call to an unexported function in `\examples` is already a
  hard ERROR.

* `roxygen_usage` could not fail. All three of its return paths passed a literal
  `TRUE`. It only inflated the check count.

* `license_year` has no authority behind it. A `LICENSE` reading `YEAR: 1999`
  passes `R CMD check --as-cran` in silence, and `tools:::.check_package_license()`
  only checks that the field exists. It fired on every package not touched in the
  current calendar year.

The default run is now 38 checks rather than 45.

## Checks corrected

Two checks did the opposite of their job.

* `home_writing` was inverted. It inspected only `path.expand()`,
  `normalizePath()`, `file.path()` and `Sys.getenv()`, which are all *reads*, so it
  flagged `Sys.getenv("HOME")` (which writes nothing) while missing
  `writeLines(x, "~/leaked.txt")`, the actual CRAN violation. It now flags a WRITE
  whose destination resolves to the user's home.

* `print_cat_usage` missed most real violations. Its guard was "not inside any
  `if`/`for`/`while`", which exempted a call under *any* enclosing control flow, so
  `if (x > 0) print("debug")` and `for (i in xs) print(i)` were let through. Only a
  verbosity gate counts as a guard now. The S3 exemption also covers `summary.*`
  methods (CRAN's own sentence ends "except for print, summary, interactive
  functions") and print-method *delegates*, i.e. helpers whose only callers are S3
  output methods.

* `globalenv_mod` flagged every `<<-`. But `<<-` assigns in the first enclosing
  frame where the name is already bound, and only reaches `.GlobalEnv` when the
  name is bound nowhere else, so it false-positived on both correct idioms: a
  closure updating its parent frame, and the package-level cache
  (`.cache <<- ...`). It now flags a `<<-` only when its target binds in neither an
  enclosing function nor the package. The `.GlobalEnv`/`globalenv()` *reference*
  rule is gone, since it flagged pure reads and the one write form that matters,
  `assign(x, envir = .GlobalEnv)`, is already an `R CMD check` NOTE.

* `core_usage` was rebuilt and widened. It required an `mc.cores` argument on the
  call, but `mc.cores` belongs to `mclapply()`/`pvec()` only: `detectCores()` takes
  no arguments, so it was flagged 100% of the time, and `makeCluster(2L)` --
  explicitly CRAN-compliant -- was flagged too. CRAN's rule is about *using* more
  than two cores, not about calling `detectCores()`.

  The check now inspects the worker count itself, and understands **parallel**,
  **snow**, **foreach** (`doParallel`, `doMC`, `doSNOW`), **future** and **furrr**,
  **mirai**, **RcppParallel**, **data.table** and **BiocParallel**. A count is safe
  when it comes from `availableCores()` (which caps itself at 2 under
  `_R_CHECK_LIMIT_CORES_`, where `detectCores()` does not), when it is capped at 2,
  or when the enclosing function guards on the CRAN environment variables.

* `commented_examples` flagged any comment containing an open parenthesis, so it
  reported ordinary English: "Simulate random choices (default)" and "(Columns are
  attributes, rows are alternatives)". A comment is now reported only when it has
  the shape of a call *and* parses as R.

* `missing_examples` now honours `\keyword{internal}`. R's own
  `tools::checkRdContents()` grants such pages substantive leniency, keying off the
  keyword alone and never reading NAMESPACE, so requiring a runnable example of a
  deprecated shim is not a rule anyone enforces.

* `description_quoted_quotes` asserted that "double quotes are for publication
  titles" and flagged any short double-quoted phrase, which caught scare-quoted
  jargon. Writing R Extensions actually reserves double quotes for quotations and
  requires single quotes for *software names*, so only a recognised software name
  is flagged now.

* `value_tags` now delegates to `tools::checkRdContents()`, which is the engine
  behind `R CMD check`'s "checking Rd contents" step and already skips non-function
  topics and `\keyword{internal}` pages.

## Checks added

* `authors` now detects an unfilled `usethis` template, e.g.
  `person("First", "Last", , "you@example.com", ...)`. `R CMD check` says nothing
  about this, because the field is present, and a CRAN reviewer then rejects it.
  The missing-`Authors@R` half is kept deliberately: R only raises a NOTE, while
  checktor treats it as a failure, which is the more useful signal before a
  submission.

## Bug fixes

* `prescribe()` now surfaces every failed check. It previously walked only the
  curated treatment list, so a check could fail and `prescribe()` would say
  nothing about it. Failures without a curated remedy now fall back to a generic
  block that names the check and lists the issues it found (#4, thanks
  @january3).

* `prescribe()` no longer prints raw `cli` markup. The stored treatment strings
  carry inline markup such as `{.code TRUE}`, and it was reaching `cli` as an
  interpolated value rather than as part of the format string. `cli` does not
  re-parse markup inside interpolated values, so readers saw literal braces
  instead of styled code.

* The DESCRIPTION acronym check no longer flags an acronym that the text already
  spells out. A conventional parenthetical gloss in either order, as in
  `principal component analysis (PCA)` or `PCA (principal component analysis)`,
  now counts as explained, and a line-wrapped gloss is detected too (#5, thanks
  @january3).

* `diagnose_print_cat_usage()` no longer flags `cat()` or `print()` inside S3
  `print.*` and `format.*` methods, where `cat()` is the required idiom. Base R's
  own `print.default()` and `print.lm()` use it (#6, thanks @jhelvy).

* `example_diagnose_scenario()` no longer prints the temporary package path when
  `show_content = TRUE`. It now shows the example file and nothing else, which
  keeps machine-specific paths out of help examples and vignettes.

* `diagnose_urls()` no longer flags an `http://` that appears inside a `\verb{}`
  or `\code{}` span in an `.Rd` file. Those are literal spans, so a package that
  *documents* the string is not linking to it, and flagging it was the same class
  of false positive the AST checks exist to prevent. Real links live in `\url{}`,
  `\href{}`, or plain prose, none of which are skipped. checktor's own
  `?diagnose_urls` page was tripping this.

* `diagnose_option_changes()` no longer flags a setter that captures the previous
  value and hands it back. `options()`, `par()` and `setwd()` all return their old
  value, so `old <- options(digits = 3); invisible(old)` honours the base R
  contract and leaves the caller able to restore. A bare `options(digits = 3)`
  whose old value is discarded is still flagged.

* `diagnose_file_operations()` no longer flags a write whose destination the
  caller supplied, as in `function(results, file) writeLines(results, file)`.
  CRAN's rule concerns writing to the user's filespace *without permission*, and
  a path passed in by the caller is permission. The exemption looks only at the
  destination argument, so a hardcoded `writeLines(x, "~/data.csv")` is still
  flagged even when some other argument happens to be a formal, and a formal that
  *defaults* into the user's filespace, as in `function(file = "~/report.txt")`,
  is still flagged too.

* The DESCRIPTION acronym check no longer flags `CMD`, which is not an acronym
  anyone expands but part of the literal command name `R CMD check`.

## Documentation

* The three vignettes gained figures. "Getting Started" now shows a coverage map
  of what `R CMD check`, `lintr`, and `checktor` each catch, and a diagram of the
  three data frames the accessors return. "checktor in Continuous Integration"
  shows the same `checkup()` call running at three latencies. "Writing Your Own
  Checks" shows the road from source to finding, the XPath axes around a
  `SYMBOL_FUNCTION_CALL` anchor, and why the parse tree never trips over a
  pattern in a string or a comment.

* "Getting Started" now runs `prescribe()` rather than hiding it, so the remedy
  the section promises is actually on the page.

* Corrected two claims in "Getting Started". `R CMD check` does flag a `Title`
  that is not in title case, and `lintr` does flag a bare `T`, so neither belongs
  in the list of things only `checktor` catches.

* Corrected the diagnostic count in "Writing Your Own Checks", and the parse-tree
  figure there now shows all eight children of a call expression, including the
  `OP-COMMA` that the prose had omitted.

## Website

* The pkgdown site picked up a theme drawn from the package logo, with a light
  and dark mode toggle in the navbar.

## Continuous integration

* Bumped `actions/checkout` to v7 and `JamesIves/github-pages-deploy-action` to
  v4.8.0, and added `quarto-dev/quarto-actions/setup` so the Quarto vignette
  engine builds against a pinned Quarto rather than whatever the runner ships.

# checktor 0.1.0

* Initial release.
* Adds [`checktor()`] as the top-level orchestrator, running five categories
  of diagnostics (code, DESCRIPTION, documentation, general, CRAN policy)
  against an R package directory.
* Adds the [`checkup()`] boolean wrapper for CI use, [`prescribe()`] for
  treatment recommendations, and [`health_report()`] for Markdown / HTML /
  text reports.
* All code-side diagnostics run XPath queries against the parsed AST via
  `xmlparsedata` + `xml2`. Documentation-side checks walk `.Rd` files via
  `tools::parse_Rd()`. DESCRIPTION is parsed with `base::read.dcf()`.
* Added result accessors so you no longer navigate nested lists: `issues()`
  (per-issue table), `tidy()` (per-check table), `summary()` (per-category),
  plus `passed()`, `is_healthy()`, `n_issues()`, `n_failed_checks()`, and
  `failed_checks()`. `as.data.frame()` on a result is equivalent to `tidy()`.
* Expanded the CRAN-submission diagnostics with additional heuristics:
  * General: flags a missing `NEWS` file (`diagnose_news_file()`) and `README`
    relative links whose target is missing or excluded by `.Rbuildignore`
    and so absent from the built tarball (`diagnose_readme_relative_links()`).
    `diagnose_cran_comments_file()` is also provided but, since a
    `cran-comments.md` is a workflow convention rather than a CRAN requirement,
    it is opt-in and not part of the default `checktor()` run.
  * DESCRIPTION: flags `Title` fields of 65 or more characters, single-quoted
    function names in `Title`/`Description` (quotes are for software names),
    and over-capitalized small words in the `Title`.
  * Documentation: flags exported functions whose `.Rd` lacks an `\examples`
    section (`diagnose_missing_examples()`) and examples that use a Suggested
    package without a `requireNamespace()` / `@examplesIf` guard
    (`diagnose_suggested_in_examples()`).

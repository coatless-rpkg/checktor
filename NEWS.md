# checktor 0.2.0

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

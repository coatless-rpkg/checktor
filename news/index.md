# Changelog

## checktor 0.1.0

- Initial release.
- Adds
  \[[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)\]
  as the top-level orchestrator, running five categories of diagnostics
  (code, DESCRIPTION, documentation, general, CRAN policy) against an R
  package directory.
- Adds the
  \[[`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)\]
  boolean wrapper for CI use,
  \[[`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)\]
  for treatment recommendations, and
  \[[`health_report()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/health_report.md)\]
  for Markdown / HTML / text reports.
- All code-side diagnostics run XPath queries against the parsed AST via
  `xmlparsedata` + `xml2`. Documentation-side checks walk `.Rd` files
  via [`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html).
  DESCRIPTION is parsed with
  [`base::read.dcf()`](https://rdrr.io/r/base/dcf.html).
- Added result accessors so you no longer navigate nested lists:
  [`issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/issues.md)
  (per-issue table),
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html) (per-check
  table), [`summary()`](https://rdrr.io/r/base/summary.html)
  (per-category), plus
  [`passed()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/predicates.md),
  [`is_healthy()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/predicates.md),
  [`n_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/predicates.md),
  [`n_failed_checks()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/predicates.md),
  and
  [`failed_checks()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/predicates.md).
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) on a
  result is equivalent to
  [`tidy()`](https://generics.r-lib.org/reference/tidy.html).
- Expanded the CRAN-submission diagnostics with additional heuristics:
  - General: flags a missing `NEWS` file
    ([`diagnose_news_file()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_news_file.md))
    and `README` relative links whose target is missing or excluded by
    `.Rbuildignore` and so absent from the built tarball
    ([`diagnose_readme_relative_links()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_readme_relative_links.md)).
    [`diagnose_cran_comments_file()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_cran_comments_file.md)
    is also provided but, since a `cran-comments.md` is a workflow
    convention rather than a CRAN requirement, it is opt-in and not part
    of the default
    [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
    run.
  - DESCRIPTION: flags `Title` fields of 65 or more characters,
    single-quoted function names in `Title`/`Description` (quotes are
    for software names), and over-capitalized small words in the
    `Title`.
  - Documentation: flags exported functions whose `.Rd` lacks an
    `\examples` section
    ([`diagnose_missing_examples()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_missing_examples.md))
    and examples that use a Suggested package without a
    [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) /
    `@examplesIf` guard
    ([`diagnose_suggested_in_examples()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_suggested_in_examples.md)).

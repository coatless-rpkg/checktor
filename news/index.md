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

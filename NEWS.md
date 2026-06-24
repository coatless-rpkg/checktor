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

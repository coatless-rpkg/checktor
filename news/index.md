# Changelog

## checktor 0.2.0

Every check now carries a severity tier, so a clean bill of health means
something precise: your package is submission-ready, and nothing here
will crash a user. New checks widen that ground, bringing part of CRAN’s
incoming filter offline: the `Date`, `Encoding` and `Version` fields,
`Authors@R` structure, ORCID and ROR identifiers, a `detectCores()` that
can return `NA`, and a scan for a leaked credential. Many existing
checks are sharper and quieter. Every diagnostic is now exported and
callable on its own, and a package can tune checktor from
`Config/checktor/*` fields in its own DESCRIPTION.

### Breaking changes

- **Severity tiers.** Every check carries one, and
  [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
  gained a `severity` argument that says which tiers the verdict is
  about. It defaults to `c("policy", "robustness")`.

  - `policy` is a citable CRAN Repository Policy or Writing R Extensions
    violation.
  - `robustness` is a real defect that CRAN will nonetheless let you
    ship, such as a `detectCores()` that may return `NA`.
  - `opinion` is a convention with no authority behind it.

  Every check still runs and every finding is still reported with its
  tier. What the tier decides is whether a finding counts against a
  clean bill of health, so `0 issues` now means *your package is
  submission-ready, and nothing here will crash a user*.
  [`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
  follows the same default, so a missing `NEWS.md` no longer fails a
  build. A check’s tier is where its authority sits, not how much we
  like it, which is why `value_tags` and `missing_examples` are
  `opinion`: no `R CMD check` equivalent exists for either.

- **Every `diagnose_*` function is now exported.** The old split was
  accidental:
  [`diagnose_tf_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_tf_usage.md)
  was public while
  [`diagnose_option_changes()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_option_changes.md)
  was not. The DESCRIPTION checks took a pre-parsed `DESCRIPTION` as
  their first argument, which is not something a caller has; they now
  take `(path, verbose, desc = NULL)` like every other check.

- **[`issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/issues.md)
  and [`tidy()`](https://generics.r-lib.org/reference/tidy.html) gained
  a `severity` column.**

- **Three checks were dropped from the default run** because no
  authority supports them. Each stays exported and callable for anyone
  who wants it.

  - `description_bare_r` demanded that every bare `R` in the
    `Description` be single-quoted. Writing R Extensions reserves single
    quotes for *other* packages and external software, and R is the host
    language. Across CRAN, about 92% of the packages that mention R in
    their `Description` write it bare, and packages first published in
    2026 are no different.
  - `title_starts_with_article` was a mis-transplant of CRAN’s real
    rule, which applies to the `Description` field and requires the
    literal word “package” after the article. `jsonlite` (“A Simple and
    Robust JSON Parser and Generator for R”) and `curl` (“A Modern and
    Flexible Web Client for R”) are both on CRAN.
  - `description_function_quotes` asserted that single quotes are
    reserved for software names. Writing R Extensions says single quotes
    are for non-English usage *including* other packages: an inclusive
    list, so a quoted function name breaks no rule.

### New checks

- `detect_cores_robustness` flags a `detectCores()` result used without
  an `NA` guard. `?detectCores` says it plainly, *“An integer, `NA` if
  the answer is unknown”*, and `NA - 1` is `NA`, so the next comparison
  dies with `missing value where TRUE/FALSE needed`. `logitr` and
  `cbcTools` both ship this. The fix is `parallelly::availableCores()`,
  which never returns `NA`.

- A family of new checks mirrors CRAN’s incoming filter, the run that
  happens under `R CMD check --as-cran` against a built tarball, so you
  see the same findings offline against your sources before you submit:

  - `date_format` flags a `Date` field that is not ISO 8601
    `yyyy-mm-dd`, is over a month old, or lies in the future.
  - `version_format` flags a `Version` component with a leading zero or
    a suspiciously large one (a calendar-year version is exempt).
  - `encoding_utf8` flags a non-portable `Encoding`, one outside the
    `UTF-8`, `latin1` and `latin2` that Writing R Extensions names as
    portable.
  - `identifier_format` validates the ORCID and ROR identifiers in
    `Authors@R`, ORCID against its checksum and ROR against its shape.

- `hardcoded_credentials` scans string literals in `R/` for a leaked
  secret: tokens and keys from providers such as GitHub, AWS, Google,
  OpenAI, Anthropic and Stripe, plus PEM private keys and JSON Web
  Tokens, each keyed on its published prefix. `R CMD check` does not
  look for these, and a token published to CRAN is public and must be
  revoked. Only string literals are examined, so the same text in a
  comment never matches. See
  [`?diagnose_hardcoded_credentials`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_hardcoded_credentials.md)
  for the full list.

- `spelling` runs
  [`utils::aspell()`](https://rdrr.io/r/utils/aspell.html) over the
  `Title` and `Description`, mirroring CRAN’s incoming spelling pass and
  reporting possibly-misspelled words. It reads any `.aspell/`
  dictionary, `inst/WORDLIST`, or `Config/checktor` vocabulary you
  already keep, so it is silenceable however you prefer. It needs a
  spell-check backend to run and passes quietly without one, exactly as
  CRAN’s check skips spelling when none is present, which is why it is
  `opinion` tier and can be turned off with
  `options(checktor.spelling = FALSE)`. When it fires,
  [`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)
  prints a ready-to-paste `.aspell/` snippet with the flagged words
  filled in (`inst/WORDLIST` alone does not clear CRAN’s aspell NOTE; a
  `.aspell/` dictionary does).

### Configuration and extension

- A package can now configure checktor from `Config/checktor/*` fields
  in its own DESCRIPTION. `disable` skips a check; `allow` mutes
  reviewed findings (a whole check, or `check:substring`), the escape
  hatch a green
  [`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
  gate needs; and `software_names` and `acronyms` extend those checks’
  vocabularies. A package with no such fields is unaffected.

- [`register_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/register_check.md)
  adds a custom diagnostic to every
  [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
  run without editing checktor’s source. You give it a name, a function
  returning a
  [`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md),
  a category, and a severity tier; the check then runs alongside the
  built-ins, appears in
  [`issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/issues.md)
  and [`tidy()`](https://generics.r-lib.org/reference/tidy.html), and
  counts toward the verdict at its tier.
  [`unregister_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/unregister_check.md)
  and
  [`registered_checks()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/registered_checks.md)
  manage the registry.

- The AST toolkit the built-in checks use is now exported, so a
  registered check has the same tools:
  [`read_r_xml()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/read_r_xml.md),
  [`xpath_lints()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/xpath_lints.md),
  [`xpath_per_file()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/xpath_per_file.md),
  [`undesirable_function_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/undesirable_function_check.md),
  [`not_under_fn_with_call_xpath()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/not_under_fn_with_call_xpath.md),
  and the `.Rd` walkers
  [`extract_rd_section()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/extract_rd_section.md)
  and
  [`collect_rd_text()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/collect_rd_text.md).
  The *Writing Your Own Checks* vignette walks through building and
  registering one.

### Checks improved

Several checks are now substantially more accurate, and a few delegate
to R’s own engines instead of reimplementing them.

- `home_writing` now flags a write whose destination resolves to the
  user’s home, such as `writeLines(x, "~/leaked.txt")` or
  `saveRDS(x, "~/.cache/x.rds")`. It previously looked only at reads
  like `Sys.getenv("HOME")`, so the writes that matter slipped past.

- `globalenv_mod` now flags a `<<-` only when its target genuinely
  reaches `.GlobalEnv`, that is, binds in neither an enclosing function
  nor the package. The two correct idioms, a closure updating its parent
  frame and the package-level cache (`.cache <<- ...`), come out clean.

- `core_usage` now inspects the worker count itself and understands
  **parallel**, **snow**, **foreach**, **future**, **furrr**, **mirai**,
  **RcppParallel**, **data.table** and **BiocParallel**. It no longer
  keys off an `mc.cores` argument (which belongs to `mclapply()` alone),
  so `detectCores()` and a compliant `makeCluster(2L)` are no longer
  flagged.

- `roxygen_usage` now detects roxygen that never reached `NAMESPACE`, a
  function tagged `@export` that is not exported, which is the real cost
  of a forgotten `devtools::document()` and which `R CMD check` cannot
  see. It reads `NAMESPACE` rather than file timestamps, so it behaves
  the same in CI, where `git` does not preserve mtimes.

- `license_year` now flags a genuinely unfilled `LICENSE` template
  (`<YEAR>` / `<COPYRIGHT HOLDER>`), the thing CRAN asks you to
  complete, rather than a valid but non-current year.

- `authors` now catches an unfilled `usethis` template, such as
  `person("First", "Last", , "you@example.com", ...)`, which
  `R CMD check` passes because the field is present but a CRAN reviewer
  sends back. It also validates the field’s structure: a person with no
  name, a person with no role, an `Authors@R` that does not parse, or no
  maintainer (`cre`).

- `title_case` and `license` now delegate to R’s own engines
  ([`tools::toTitleCase()`](https://rdrr.io/r/tools/toTitleCase.html)
  and
  [`tools::analyze_license()`](https://rdrr.io/r/tools/licensetools.html)),
  so they match R’s own behaviour, for instance `title_case` handles
  quoted package names and punctuation the way R does. `license` also
  flags a bare `MIT`, which needs `MIT + file LICENSE` pointing at a
  file that exists. `value_tags` walks each `.Rd` with
  [`tools::parse_Rd()`](https://rdrr.io/r/tools/parse_Rd.html),
  exempting data, class, package and `\keyword{internal}` topics, so its
  verdict does not depend on the R version.

- `print_cat_usage` now flags unsuppressable console output only from a
  function that also returns a value, and treats a verbosity gate as the
  guard rather than any enclosing `if`/`for`/`while`.

### Understands more of R

checktor reads far more of the ways R is actually written, so a clean
run reflects the code you wrote.

**It now understands more ways of writing R.**

- `NAMESPACE` is parsed with R’s own
  [`base::parseNamespaceFile()`](https://rdrr.io/r/base/ns-internal.html),
  so a multi-line `export()` block, an `exportPattern()`, and a method
  under a quoted non-syntactic generic (`S3method("[", foo)`) all read
  correctly. Every “is this exported?” check now sees `digest`’s nine
  exports, not one.

- An `=` assignment is read as an assignment, and a classic
  `"print.foo" <- function(x)` definition, whose name parses as a
  `STR_CONST`, is visible to every name-based exemption. `geoR` writes
  201 of its 208 functions that way.

- An S4 `setMethod("show", ...)` is an output method where
  [`cat()`](https://rdrr.io/r/base/cat.html) is the required idiom,
  `app$cat(...)` is a method call rather than
  [`base::cat`](https://rdrr.io/r/base/cat.html), and a verbosity flag
  named `messages` counts as a gate.

- A `<<-` inside [`local()`](https://rdrr.io/r/base/eval.html),
  `setRefClass()` or `R6Class()` binds in that scope rather than
  `.GlobalEnv`, a call in a default argument is scoped to that argument
  rather than the function body (preserving the
  [`on.exit()`](https://rdrr.io/r/base/on.exit.html) that
  `option_changes`, `temp_cleanup` and `sys_setenv` rely on), and only
  the R chunks of a vignette are parsed, so its prose stays prose.

**It now tells a read from a write, and a package’s own state from the
user’s.**

- [`options()`](https://rdrr.io/r/base/options.html) and
  [`par()`](https://rdrr.io/r/graphics/par.html) both read and write,
  and only a named argument makes the call a write, so `par("usr")[3]`
  and `withr`’s own `reset_options()` stay clean. A restore factored
  into its own helper and registered by the caller with
  `on.exit(restore_par(op))` is recognised as the restore it is, not
  flagged as an unreset change.

- A package’s own namespaced option (`options(datatable.verbose = ...)`)
  is its own state, and a [`setwd()`](https://rdrr.io/r/base/getwd.html)
  or [`options()`](https://rdrr.io/r/base/options.html) inside a `callr`
  subprocess cannot reach the calling session.

- `file_operations` proves where a write lands:
  `writeLines(x, "out.csv")` is flagged, `writeLines(x, out_file)` is
  trusted to the caller who passed the path, and a formal that defaults
  into `~` is still caught.

- `package_size` measures the gzipped tarball CRAN actually limits:
  `billboarder` is 6.3 MB on disk and 2.93 MB packed.

- A [`Sys.setenv()`](https://rdrr.io/r/base/Sys.setenv.html) setter that
  captures the prior state and hands it back
  (`old <- get_path(); Sys.setenv(...); invisible(old)`) honours the
  same restore contract `option_changes` already follows. `withr`’s own
  path and env-var setters are shaped that way.

**It now recognises the guards CRAN sanctions.**

- `if (require("pkgB"))` and roxygen’s `@examplesIf` both count as the
  conditional-Suggests guard in an example;
  [`interactive()`](https://rdrr.io/r/base/interactive.html) does not,
  because it does not make the package available. A
  [`system()`](https://rdrr.io/r/base/system.html) call inside an OS
  branch is the platform check the fix asks for, and an
  [`install.packages()`](https://rdrr.io/r/utils/install.packages.html)
  behind a consent prompt is consent.

- `set.seed(123)` inside `if (FALSE)` cannot reach the RNG, and `T`/`F`
  inside [`quote()`](https://rdrr.io/r/base/substitute.html),
  [`expression()`](https://rdrr.io/r/base/expression.html) or
  [`substitute()`](https://rdrr.io/r/base/substitute.html) are language
  tokens rather than logicals.

- `commented_examples` fires only when an entire `\examples{}` block is
  commented out, `example_structure` accepts a database, prompt or Shiny
  reactive context as justifying `\dontrun{}`, and `library_in_pkg`
  exempts code sent to a parallel worker, whose search path starts
  empty.

- `software_names` flags only R-package and software-product names,
  which CRAN consistently requires quoted (`ggplot2` is quoted in 96% of
  the Descriptions that mention it). Programming languages and markup
  (`Python`, `Java`, `SQL`, `HTML`) are quoted only 20-57% of the time
  across CRAN, a coin flip rather than a convention, so they were
  dropped.

- Smaller sharpenings: `description_quoted_quotes` flags only a
  recognised software name rather than scare-quoted jargon,
  `description_length` counts words, `description_starts_with` gained
  its initial-capital rule, `acronyms` no longer flags `CMD`, and `urls`
  names the offending URL while skipping fenced code and `\verb{}`
  spans.

### Bug fixes

- `package_size` now honours a bare directory entry in `.Rbuildignore`,
  such as the `^docs$` a pkgdown package uses. R CMD build excludes a
  matched directory’s whole subtree, so an untracked `docs/` or
  `.quarto` cache never reaches the tarball. `package_size` matched only
  leaf paths, so it counted those trees and could report a package many
  times its real tarball size. It now tests each file’s ancestor
  directories too, case-insensitively, as R does.

- `mean(x, na.rm = T)`, the most common bare `T` in R, is now reported.
  An argument name parses as `SYMBOL_SUB` rather than `SYMBOL`, so a
  guard meant to skip `f(T = 1)` was inadvertently skipping the argument
  *value* too.

- [`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)
  now surfaces every failed check. It previously walked only the curated
  treatment list, so a check could fail and
  [`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)
  would say nothing
  ([\#4](https://github.com/coatless-rpkg/checktor/issues/4), thanks
  [@january3](https://github.com/january3)).

- [`prescribe()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/prescribe.md)
  no longer prints raw `cli` markup. Treatment strings carry inline
  markup such as `{.code TRUE}`, and it reached `cli` as an interpolated
  value rather than as part of the format string.

- [`diagnose_print_cat_usage()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_print_cat_usage.md)
  no longer flags [`cat()`](https://rdrr.io/r/base/cat.html) inside S3
  `print.*` and `format.*` methods, where it is the required idiom. Base
  R’s own [`print.default()`](https://rdrr.io/r/base/print.default.html)
  uses it ([\#6](https://github.com/coatless-rpkg/checktor/issues/6),
  thanks [@jhelvy](https://github.com/jhelvy)).

- The `acronyms` check treats `principal component analysis (PCA)` and
  `PCA (principal component analysis)` alike as explained, and detects a
  line-wrapped gloss
  ([\#5](https://github.com/coatless-rpkg/checktor/issues/5), thanks
  [@january3](https://github.com/january3)).

- [`example_diagnose_scenario()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/example_diagnose_scenario.md)
  no longer prints the temporary package path, keeping machine-specific
  paths out of help pages.

### Documentation and website

- The three vignettes gained figures: a coverage map of what
  `R CMD check`, `lintr` and `checktor` each catch; the three data
  frames the accessors return;
  [`checkup()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checkup.md)
  running at three latencies in CI; and, for “Writing Your Own Checks”,
  the road from source to finding and the XPath axes around a
  `SYMBOL_FUNCTION_CALL` anchor.

- Corrected two claims in “Getting Started”: `R CMD check` *does* flag a
  `Title` that is not in title case, and `lintr` *does* flag a bare `T`,
  so neither belongs in the list of things only checktor catches.

- The pkgdown site picked up a theme drawn from the package logo, with a
  light and dark toggle in the navbar.

### Continuous integration

- Bumped `actions/checkout` to v7 and
  `JamesIves/github-pages-deploy-action` to v4.8.0, and added
  `quarto-dev/quarto-actions/setup` so the Quarto vignette engine builds
  against a pinned Quarto.

## checktor 0.1.0

CRAN release: 2026-07-02

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

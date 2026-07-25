# checktor 0.2.0

Every check now carries a severity tier, so a clean bill of health tells you
something precise. Your package is submission ready, and nothing here will crash
a user. New checks widen that ground by bringing part of CRAN's incoming filter
offline, covering the `Date`, `Encoding` and `Version` fields, the structure of
`Authors@R`, ORCID and ROR identifiers, a `detectCores()` that can return `NA`,
and a scan for a leaked credential. Many existing checks are sharper and quieter,
every diagnostic is now exported and callable on its own, checktor runs from
anywhere inside a package the way `devtools::check()` does, and a package can tune
checktor through `Config/checktor/*` fields in its own DESCRIPTION.

## Breaking changes

* Every check now carries a severity tier, and `checktor()` gained a `severity`
  argument that decides which tiers the verdict is about. It defaults to policy
  and robustness.

  - A policy finding is a citable violation of CRAN Repository Policy or Writing
    R Extensions.
  - A robustness finding is a real defect that CRAN will still let you ship, such
    as a `detectCores()` that may return `NA`.
  - An opinion finding is a convention with no authority behind it.

  Every check still runs and every finding is still reported with its tier. The
  tier only decides whether a finding counts against a clean bill of health, so
  zero issues now means your package is submission ready and nothing here will
  crash a user. `checkup()` follows the same default, so a missing `NEWS.md` no
  longer fails a build. A check's tier reflects where its authority sits rather
  than how much we like it, which is why `value_tags` and `missing_examples` sit
  at opinion, since no `R CMD check` equivalent exists for either.

* Every `diagnose_*` function is now exported. The old split was accidental, with
  `diagnose_tf_usage()` public while `diagnose_option_changes()` was not. The
  DESCRIPTION checks used to take a pre-parsed `DESCRIPTION` as their first
  argument, which is not something a caller has, so they now take
  `(path, verbose, desc = NULL)` like every other check.

* `issues()` and `tidy()` gained a `severity` column.

* `description_bare_r` was removed. It flagged every bare `R` in the `Description`
  and asked you to quote it, but Writing R Extensions reserves single quotes for
  other packages and external software, and `R` is the host language, so most
  packages write it bare and stay on CRAN. The new `language_names` check settles
  the question the right way by leaving `R` alone.

* Two checks were dropped from the default run because no authority supports them,
  and each stays exported and callable for anyone who wants it.

  - `title_starts_with_article` was a mis-transplant of a real CRAN rule that
    applies to the `Description` field and requires the literal word "package"
    after the article. Plenty of packages sit on CRAN with titles that begin with
    an article.
  - `description_function_quotes` asserted that single quotes are reserved for
    software names. Writing R Extensions actually treats them as an inclusive list
    for non-English usage that includes other packages, so a quoted function name
    breaks no rule.

## New checks

* `detect_cores_robustness` flags a `detectCores()` result used without an `NA`
  guard. The help for `detectCores()` says plainly that it returns an integer, or
  `NA` when the answer is unknown, and `NA - 1` is `NA`, so the next comparison
  dies with `missing value where TRUE/FALSE needed`. The fix is
  `parallelly::availableCores()`, which never returns `NA`.

* A family of new checks mirrors CRAN's incoming filter, the run that happens
  under `R CMD check --as-cran` against a built tarball, so you can see the same
  findings offline against your own sources before you submit.

  - `date_format` flags a `Date` field that is not ISO 8601 `yyyy-mm-dd`, is over
    a month old, or lies in the future.
  - `version_format` flags a `Version` component with a leading zero or a
    suspiciously large one, while leaving a calendar-year version alone.
  - `encoding_utf8` flags a non-portable `Encoding`, meaning one outside the
    `UTF-8`, `latin1` and `latin2` that Writing R Extensions names as portable.
  - `identifier_format` validates the ORCID and ROR identifiers in `Authors@R`,
    checking ORCID against its checksum and ROR against its shape.

* `hardcoded_credentials` scans string literals in `R/` for a leaked secret. It
  knows the tokens and keys used by providers such as GitHub, AWS, Google, OpenAI,
  Anthropic and Stripe, along with PEM private keys and JSON Web Tokens, each
  recognised by its published prefix. `R CMD check` does not look for these, and a
  token published to CRAN is public and must be revoked. Only string literals are
  examined, so the same text in a comment never matches. See
  `?diagnose_hardcoded_credentials` for the full list.

* `spelling` runs `utils::aspell()` over the `Title` and `Description` to mirror
  CRAN's incoming spelling pass and report words that look misspelled. It reads
  any `.aspell/` dictionary, `inst/WORDLIST`, or `Config/checktor` vocabulary you
  already keep, so you can silence it however you prefer. It needs a spell-check
  backend to run and passes quietly without one, exactly as CRAN's check skips
  spelling when none is present, which is why it sits at opinion tier and can be
  turned off with `options(checktor.spelling = FALSE)`. When it fires,
  `prescribe()` prints a ready-to-paste `.aspell/` snippet with the flagged words
  filled in, since `inst/WORDLIST` alone does not clear CRAN's aspell NOTE but a
  `.aspell/` dictionary does.

* `url_liveness` fetches every URL in the DESCRIPTION, `.Rd` files and vignettes
  and reports the ones that return an error, a 404, or a redirect. This is what
  `R CMD check --as-cran` does through the same base R machinery in
  `tools::check_package_urls()`, with no dependency on the `urlchecker` package.
  Because it needs a network and is slow, it is opt-in and does nothing until you
  set `options(checktor.url_check = TRUE)`, passing quietly whenever it is off. It
  is the online half of the URL story, and `urls` remains the fast offline half
  that flags `http://` and shorteners without leaving the room.

* `language_names` flags a bare programming-language, markup, or
  statistical-computing name in the `Title` or `Description` that CRAN asks to see
  single-quoted, covering names like `Python`, `Java`, `C++`, `SQL`, `HTML`,
  `MATLAB` and `SAS`. It is the language counterpart to `software_names`, and both
  are policy-tier quoting checks kept separate because a language name and a
  package name are different kinds of thing. Single-letter and common-word names
  are left out to avoid false positives, and you can extend the list with
  `Config/checktor/language_names`.

## Configuration and extension

* checktor now runs from anywhere inside a package, the way `devtools::check()`
  does. It walks up from the path you give it to find the `DESCRIPTION`, so a call
  with your working directory in `R/` or `tests/testthat/` examines the whole
  package instead of failing, and pointing it at a file works as well as pointing
  it at a directory. Every entry point resolves the root the same way, from
  `checktor()` and `checkup()` down to each individual `diagnose_*()`, and
  `find_package_root()` is exported for custom checks that want the same rule.
  A directory that really is outside a package still says so.

* A package can now configure checktor through `Config/checktor/*` fields in its
  own DESCRIPTION. The `disable` field skips a check, `allow` mutes reviewed
  findings for either a whole check or a `check:substring` and gives a green
  `checkup()` gate the escape hatch it needs, and `software_names`,
  `language_names` and `acronyms` extend those checks' vocabularies. A package
  with no such fields is unaffected.

* `register_check()` adds a custom diagnostic to every `checktor()` run without
  editing checktor's source. You give it a name, a function that returns a
  `checktor_check_result()`, a category, and a severity tier, and the check then
  runs alongside the built-ins, appears in `issues()` and `tidy()`, and counts
  toward the verdict at its tier. `unregister_check()` and `registered_checks()`
  manage the registry.

* The AST toolkit that the built-in checks use is now exported, so a registered
  check has the same tools available. These include `read_r_xml()`,
  `xpath_lints()`, `xpath_per_file()`, `undesirable_function_check()`,
  `not_under_fn_with_call_xpath()`, and the `.Rd` walkers `extract_rd_section()`
  and `collect_rd_text()`. The Writing Your Own Checks vignette walks through
  building and registering one.

## Checks improved

Several checks are now substantially more accurate, and a few hand off to R's own
engines instead of reimplementing them.

* `option_changes` now prescribes a fix. When it fires, `prescribe()` shows the two
  ways out, namespacing a setting you keep for the session as
  `options(<PackageName>.key = ...)`, or restoring a temporary change with
  `on.exit()`.

* `home_writing` now flags a write whose destination resolves to the user's home,
  such as `writeLines(x, "~/leaked.txt")` or `saveRDS(x, "~/.cache/x.rds")`. It
  previously looked only at reads like `Sys.getenv("HOME")`, so the writes that
  actually matter slipped past.

* `globalenv_mod` now flags a `<<-` only when its target genuinely reaches
  `.GlobalEnv`, meaning it binds in neither an enclosing function nor the package.
  The two correct idioms, a closure updating its parent frame and the
  package-level cache written as `.cache <<- ...`, both come out clean.

* `core_usage` now inspects the worker count itself and understands the
  `parallel`, `snow`, `foreach`, `future`, `furrr`, `mirai`, `RcppParallel`,
  `data.table` and `BiocParallel` frameworks. It no longer keys off an `mc.cores`
  argument, which belongs to `mclapply()` alone, so `detectCores()` and a
  compliant `makeCluster(2L)` are no longer flagged.

* `roxygen_usage` now detects roxygen that never reached `NAMESPACE`, such as a
  function tagged `@export` that is not actually exported. That is the real cost
  of a forgotten `devtools::document()`, and it is something `R CMD check` cannot
  see. It reads `NAMESPACE` rather than file timestamps, so it behaves the same in
  CI, where `git` does not preserve modification times.

* `license_year` now flags a genuinely unfilled `LICENSE` template, meaning a
  leftover `<YEAR>` or `<COPYRIGHT HOLDER>` that CRAN asks you to complete, rather
  than a valid but non-current year.

* `authors` now catches an unfilled `usethis` template such as
  `person("First", "Last", , "you@example.com", ...)`, which `R CMD check` passes
  because the field is present but a CRAN reviewer sends back. It also validates
  the structure of the field and flags a person with no name, a person with no
  role, an `Authors@R` that does not parse, or a missing maintainer.

* `title_case` and `license` now hand off to R's own engines in
  `tools::toTitleCase()` and `tools::analyze_license()`, so they match R's
  behaviour, and `title_case` handles quoted package names and punctuation the way
  R does. `license` also flags a bare `MIT`, which needs `MIT + file LICENSE`
  pointing at a file that exists. `value_tags` walks each `.Rd` with
  `tools::parse_Rd()` and exempts data, class, package and `\keyword{internal}`
  topics, so its verdict no longer depends on the R version.

* `print_cat_usage` now flags unsuppressable console output only from a function
  that also returns a value, and it treats a verbosity gate as the guard rather
  than any enclosing `if`, `for` or `while`.

## Understands more of R

checktor reads far more of the ways R is actually written, so a clean run
reflects the code you wrote.

* `NAMESPACE` is parsed with R's own `base::parseNamespaceFile()`, so a multi-line
  `export()` block, an `exportPattern()`, and a method under a quoted
  non-syntactic generic such as `S3method("[", foo)` all read correctly. Every
  "is this exported?" check now sees a package's full set of exports rather than
  just the first.

* An `=` assignment is read as an assignment, and a classic
  `"print.foo" <- function(x)` definition, whose name parses as a `STR_CONST`, is
  visible to every name-based exemption. A package that defines nearly all of its
  functions that way now reads correctly.

* An S4 `setMethod("show", ...)` is treated as an output method where `cat()` is
  the required idiom, `app$cat(...)` is a method call rather than `base::cat`, and
  a verbosity flag named `messages` counts as a gate.

* A `<<-` inside `local()`, `setRefClass()` or `R6Class()` binds in that scope
  rather than `.GlobalEnv`, a call in a default argument is scoped to that argument
  rather than the function body, which preserves the `on.exit()` that
  `option_changes`, `temp_cleanup` and `sys_setenv` rely on, and only the R chunks
  of a vignette are parsed, so its prose stays prose.

checktor also tells a read apart from a write, and a package's own state apart
from the user's.

* `options()` and `par()` both read and write, and only a named argument makes the
  call a write, so `par("usr")[3]` and a package's own `reset_options()` stay
  clean. A restore factored into its own helper and registered by the caller with
  `on.exit(restore_par(op))` is recognised as the restore it is, not flagged as an
  unreset change.

* A package's own namespaced option such as `options(datatable.verbose = ...)` is
  its own state, and a `setwd()` or `options()` inside a `callr` subprocess cannot
  reach the calling session.

* `file_operations` proves where a write lands, so `writeLines(x, "out.csv")` is
  flagged, `writeLines(x, out_file)` is trusted to the caller who passed the path,
  and a formal that defaults into `~` is still caught.

* `package_size` measures the gzipped tarball that CRAN actually limits, which is
  often far smaller than the files on disk.

* A `Sys.setenv()` setter that captures the prior state and hands it back, as in
  `old <- get_path(); Sys.setenv(...); invisible(old)`, honours the same restore
  contract `option_changes` already follows. Many packages' env-var and path
  setters are shaped that way.

checktor recognises the guards CRAN sanctions, too.

* `if (require("pkgB"))` and roxygen's `@examplesIf` both count as the
  conditional-Suggests guard in an example, while `interactive()` does not,
  because it does not make the package available. A `system()` call inside an OS
  branch is the platform check the fix asks for, and an `install.packages()`
  behind a consent prompt is consent.

* `set.seed(123)` inside `if (FALSE)` cannot reach the RNG, and `T` or `F` inside
  `quote()`, `expression()` or `substitute()` are language tokens rather than
  logicals.

* `commented_examples` fires only when an entire `\examples{}` block is commented
  out. `example_structure` accepts a database, a prompt, or a Shiny reactive
  context as a reason for `\dontrun{}`, and it now takes an install or launcher
  call or a `path/to/...` placeholder the same way. And `library_in_pkg` exempts
  code sent to a parallel worker, whose search path starts empty.

* `software_names` flags the R-package and software-product names CRAN asks to see
  quoted, along with `WebAssembly`, a specific format the R WebAssembly ecosystem
  and CRAN quote consistently, and it recognises `WASM`, `webR` and `Shinylive`
  when quoted. Programming-language and markup names moved to their own
  `language_names` check. A package can add its own names with
  `Config/checktor/software_names`.

* A few smaller sharpenings round this out. `description_quoted_quotes` flags only
  a recognised software name rather than scare-quoted jargon, `description_length`
  counts words, `description_starts_with` gained its initial-capital rule,
  `acronyms` no longer flags `CMD`, and `urls` names the offending URL while
  skipping fenced code and `\verb{}` spans.

## Bug fixes

* `package_size` now honours a bare directory entry in `.Rbuildignore`, such as the
  `^docs$` a pkgdown package uses. R CMD build excludes a matched directory's whole
  subtree, so an untracked `docs/` or `.quarto` cache never reaches the tarball.
  `package_size` matched only leaf paths, so it counted those trees and could
  report a package many times its real tarball size. It now tests each file's
  ancestor directories too, case-insensitively, the way R does.

* `mean(x, na.rm = T)`, the most common bare `T` in R, is now reported. An argument
  name parses as `SYMBOL_SUB` rather than `SYMBOL`, so a guard meant to skip
  `f(T = 1)` was inadvertently skipping the argument value too.

* `prescribe()` now surfaces every failed check. It previously walked only the
  curated treatment list, so a check could fail and `prescribe()` would say nothing
  (#4, thanks @january3).

* `prescribe()` no longer prints raw `cli` markup. Treatment strings carry inline
  markup such as `{.code TRUE}`, and it reached `cli` as an interpolated value
  rather than as part of the format string.

* `diagnose_print_cat_usage()` no longer flags `cat()` inside S3 `print.*` and
  `format.*` methods, where it is the required idiom, and base R's own
  `print.default()` uses it (#6, thanks @jhelvy).

* The `acronyms` check treats `principal component analysis (PCA)` and
  `PCA (principal component analysis)` alike as explained, and it detects a
  line-wrapped gloss (#5, thanks @january3).

* `example_diagnose_scenario()` no longer prints the temporary package path,
  keeping machine-specific paths out of help pages.

## Documentation and website

* Two new vignettes explain where the rules come from. *Where the Checks Come From*
  maps every check to the CRAN Repository Policy or Writing R Extensions section it
  rests on, and to the CRAN Cookbook recipe where the authority is a convention
  rather than a rule, linking to each. *What R CMD check Checks* walks through every
  step `R CMD check` performs so the line between the standard checks and checktor's
  is clear.

* Every check's help page gained a *Source* section that names the rule behind it,
  a CRAN policy clause, a Writing R Extensions section, a CRAN Cookbook recipe, or
  an honest note that no rule applies, with a link wherever one exists.

* The original three vignettes gained figures. There is a coverage map of what
  `R CMD check`, `lintr` and `checktor` each catch, a view of the three data
  frames the accessors return, `checkup()` running at three latencies in CI, and,
  for Writing Your Own Checks, the road from source to finding alongside the XPath
  axes around a `SYMBOL_FUNCTION_CALL` anchor.

* Two claims in Getting Started were corrected. `R CMD check` does flag a `Title`
  that is not in title case, and `lintr` does flag a bare `T`, so neither belongs
  in the list of things only checktor catches.

* The pkgdown site picked up a theme drawn from the package logo, with a light and
  dark toggle in the navbar.

## Continuous integration

* Bumped `actions/checkout` to v7 and `JamesIves/github-pages-deploy-action` to
  v4.8.0, and added `quarto-dev/quarto-actions/setup` so the Quarto vignette engine
  builds against a pinned Quarto.

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

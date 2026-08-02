# checktor 0.2.0

Every check now carries a severity tier, so a clean bill of health means something
precise rather than merely quiet. Checks read your examples, vignettes and demos as
well as `R/`, which is where several of the most common rejections actually land.
New checks bring part of CRAN's incoming filter offline, covering the `Date`,
`Encoding` and `Version` fields, the structure of `Authors@R`, ORCID and ROR
identifiers, a `detectCores()` that can return `NA`, and a scan for a leaked
credential. Existing checks are sharper and quieter, every check is callable on its
own, findings can go straight to your build system, checktor runs from anywhere
inside a package tree, and a package can tune checktor through `Config/checktor/*`
fields in its own DESCRIPTION.

## Breaking changes

* checktor needs R 4.5.0 or later, where 0.1.0 asked only for R 3.5.0. R 4.5.0 added
  `tools::check_package_urls()`, which the new `url_liveness` check uses. An older
  installation stays on 0.1.0.

* The individual checks are now `lab_*()`, so the doctor orders a panel of labs.
  `diagnose_tf_usage()` is `lab_tf_usage()`, and the name after `lab_` is the check
  name `tidy()` reports and `Config/checktor` refers to, which several old names did
  not match. The five category functions such as `diagnose_code_issues()` keep their
  names, since they run a panel rather than one test. The names released in 0.1.0
  were renamed outright rather than deprecated, so update any call to
  `diagnose_tf_usage()`, `diagnose_seed_setting()`, `diagnose_print_cat_usage()`,
  `diagnose_roxygen_usage()`, `diagnose_value_tags()`, `diagnose_example_structure()`,
  `diagnose_package_size()` or `diagnose_urls()`.

* Every check carries a severity tier, and `checktor()` gained a `severity` argument
  deciding which tiers the verdict is about. It defaults to policy and robustness.

  - A policy finding is a citable violation of CRAN Repository Policy or Writing R
    Extensions.
  - A robustness finding is a real defect that CRAN will still accept, such as a
    `detectCores()` that may return `NA`.
  - An opinion finding is a convention with no authority behind it.

  Every check still runs and every finding is still reported with its tier. The tier
  only decides what counts against a clean bill of health, so zero issues now means
  your package is submission ready and nothing here will crash a user. `checkup()`
  follows the same default, so a missing `NEWS.md` no longer fails a build.

* A check that does not run is reported as skipped rather than as passing, so a
  clean bill of health never includes a check that never happened. `tidy()` gained a
  `skipped` column and `summary()` a `skipped` count, the names are in
  `metadata$skipped_checks`, and the printed result and every `health_report()`
  format name the checks that sat out.

* Every check is exported, so any check `checktor()` runs is one you can call
  yourself. The DESCRIPTION checks take `(path, verbose, desc = NULL)` like every
  other check, and `issues()` and `tidy()` gained a `severity` column.

* `description_bare_r` was removed. It asked you to quote every bare `R` in the
  `Description`, which is not a rule anyone enforces. Writing R Extensions asks for
  single quotes around other packages and external software without naming `R`
  either way, and both forms clear CRAN, so `language_names` leaves a bare `R` and a
  quoted `'R'` alone alike and takes no position on which you prefer.

* Two checks left the default run because no authority supports them, and each stays
  exported for anyone who wants it. The CRAN rule behind `title_starts_with_article`
  applies to the `Description` and requires the word "package" after the article, not
  to the `Title`. And Writing R Extensions treats single quotes as an inclusive list
  for non-English usage that a quoted function name fits, which is what
  `description_function_quotes` ruled out.

## New checks

* `detect_cores_robustness` catches a `detectCores()` result used without an `NA`
  guard. The help says it returns an integer, or `NA` when the answer is unknown, and
  `NA - 1` is `NA`, so the next comparison dies with `missing value where
  TRUE/FALSE needed`. The fix is `parallelly::availableCores()`.

* A family of checks mirrors CRAN's incoming filter, so you see those findings
  offline against your own sources before you submit.

  - `date_format` catches a `Date` that is not ISO 8601 `yyyy-mm-dd`, is over a month
    old, or lies in the future.
  - `version_format` catches a `Version` component with a leading zero or a
    suspiciously large one, while leaving a calendar-year version alone.
  - `encoding_utf8` catches an `Encoding` outside the portable `UTF-8`, `latin1` and
    `latin2`.
  - `identifier_format` validates the ORCID and ROR identifiers in `Authors@R`.

* `hardcoded_credentials` scans string literals in `R/` for a leaked secret, knowing
  the tokens and keys used by providers such as GitHub, AWS, Google, OpenAI,
  Anthropic and Stripe, along with PEM private keys and JSON Web Tokens. A token
  published to CRAN is public and must be revoked, and `R CMD check` does not look
  for these. Only string literals are examined, so the same text in a comment never
  matches. See `?lab_hardcoded_credentials` for the full list.

* `spelling` runs `utils::aspell()` over the `Title` and `Description` to mirror
  CRAN's incoming spelling pass. It reads any `.aspell/` dictionary, `inst/WORDLIST`,
  or `Config/checktor` vocabulary you already keep, and passes quietly without a
  spell-check backend installed. Turn it off with
  `options(checktor.spelling = FALSE)`. When it reports a word, `prescribe()` prints
  a ready-to-paste `.aspell/` snippet, since `inst/WORDLIST` alone does not clear
  CRAN's aspell NOTE but a `.aspell/` dictionary does.

* `url_liveness` fetches every URL in the DESCRIPTION, `.Rd` files and vignettes and
  reports the ones that return an error, a 404, or a redirect, which is what
  `R CMD check --as-cran` does through `tools::check_package_urls()`. It runs when
  you are at the console and stays off in scripts, in continuous integration and
  under `R CMD check`, where a slow or unreachable network would make the result
  depend on the machine rather than the package. Set
  `options(checktor.url_check = TRUE)` or `FALSE` to decide for yourself. With no
  network reachable it comes back marked as a check that did not run, rather than
  calling every link broken or quietly reading as though every link resolved, while
  a single unreachable host among reachable ones still counts. `urls` remains the
  offline half, catching `http://` links and shorteners without leaving the room.

* A family of checks reads the code outside `R/`, where several of the most common
  rejections land. Every code check used to read `R/` alone, so an install in an
  example, a write to the working directory in a vignette, or an `options()` call
  in `inst/demo` that was never put back all went unseen. Each rule below is one a
  maintainer has received verbatim from CRAN.

  - `example_interactive` asks for `if (interactive())` where an interactive
    function is hidden in `\dontrun{}`, so a reader sees it is not for a script.
  - `example_installs` catches installing a package from an example, a vignette or
    a demo.
  - `example_writes` catches a write to anywhere but `tempdir()`, judged with the
    same destination logic the `R/` check uses.
    The write checks now share one list of what counts as a write, so they agree
    with each other, and it covers the readr, data.table, arrow, spreadsheet and
    JSON writers alongside the base ones. `write_csv()`, `write_rds()`, `fwrite()`,
    `write_xlsx()`, `write_parquet()` and `ggsave()` are all seen now, in `R/` and
    in examples alike.
  - `example_state` catches `options()`, `par()` or the working directory changed
    and never restored.
  - `example_internal_ns` catches `:::` in an example or vignette.

  `internal_ns` covers the same rule in `R/`, where a `:::` call reaches an object
  another author is free to change in routine maintenance. `unexported_example_ns`
  used to suggest adding `:::` to an example, which is the change CRAN asks you to
  undo, so it now says to export the object or keep the topic internal instead.

* `language_names` catches a bare programming-language, markup or
  statistical-computing name in the `Title` or `Description` that CRAN asks to see
  single-quoted, covering names like `Python`, `Java`, `C++`, `SQL`, `HTML`, `MATLAB`
  and `SAS`. It is the language counterpart to `software_names`, kept separate
  because a language name and a package name are different kinds of thing.
  Single-letter and common-word names are left out so ordinary prose stays quiet, and
  you can extend the list with `Config/checktor/language_names`.

## Configuration and extension

* checktor runs from anywhere inside a package (#12, thanks @january3). It walks up
  from the path you give it to find the `DESCRIPTION`, so a call with your working
  directory in `R/` or `tests/testthat/` examines the whole package instead of
  failing, and a file works as well as a directory. Every entry point resolves the
  root the same way, and `find_package_root()` is exported for custom checks. A
  directory outside any package still says so.

* A package can configure checktor through `Config/checktor/*` fields in its own
  DESCRIPTION. `disable` skips a check, `allow` mutes reviewed findings for a whole
  check or a `check:substring`, and `software_names`, `language_names` and `acronyms`
  extend those checks' vocabularies. A package with no such fields is unaffected.

* `ci_report()` writes findings in the shape your build system reads, so each one
  lands on the line that caused it rather than in a log somebody has to scroll.
  Called with no arguments it examines the package, works out where it is running,
  and emits the right thing. GitHub Actions gets workflow commands that annotate the
  pull request diff, and Gitea and Forgejo read the same ones. GitLab gets a Code
  Quality report for the merge request diff, Azure Pipelines gets logging commands,
  and Checkstyle XML covers Jenkins, reviewdog and the review bots. SARIF is there
  for GitHub code scanning. It reports every tier, since an annotation is
  information rather than a verdict, and `checkup()` stays the gate. Checks that
  did not run are named once alongside the findings, so a quiet pipeline never
  implies a check that never happened, and the report formats write a document
  even when nothing was found, which is what lets a forge clear the findings an
  earlier run left behind.

* A few checks sit outside every run, because no authority backs them or they ask
  about a submission workflow rather than the package itself. The summary now names
  them so you can find out they are there, and `metadata$on_request_checks` carries
  the list. Calling one is the only way to run it, and since they sit in the opinion
  tier, running one never changes a verdict.

* `register_check()` adds a check of your own to every `checktor()` run without
  editing checktor's source. Give it a name, a function returning a
  `checktor_check_result()`, a category and a severity tier, and it runs alongside
  the built-ins, appears in `issues()` and `tidy()`, and counts toward the verdict at
  its tier. `unregister_check()` and `registered_checks()` manage the registry.

* The AST toolkit the built-in checks use is exported, so a registered check has the
  same tools: `read_r_xml()`, `xpath_lints()`, `xpath_per_file()`,
  `undesirable_function_check()`, `not_under_fn_with_call_xpath()`, and the `.Rd`
  walkers `extract_rd_section()` and `collect_rd_text()`. The Writing Your Own Checks
  vignette walks through building and registering one.

## Checks improved

Several checks are more accurate, and a few hand off to R's own engines instead of
reimplementing them.

* `option_changes` suggests a fix. `prescribe()` shows the two ways out, namespacing
  a setting you keep for the session as `options(<PackageName>.key = ...)`, or
  restoring a temporary change with `on.exit()`.

* `home_writing` catches a write whose destination resolves to the user's home, such
  as `writeLines(x, "~/leaked.txt")`, rather than reads like `Sys.getenv("HOME")`.

* `globalenv_mod` reports a `<<-` only when its target genuinely reaches
  `.GlobalEnv`, so a closure updating its parent frame and a package-level cache
  written as `.cache <<- ...` both come out clean.

* `core_usage` inspects the worker count itself and understands the `parallel`,
  `snow`, `foreach`, `future`, `furrr`, `mirai`, `RcppParallel`, `data.table` and
  `BiocParallel` frameworks. It no longer keys off an `mc.cores` argument, which
  belongs to `mclapply()` alone, so `detectCores()` and a compliant `makeCluster(2L)`
  come out clean.

* `roxygen_usage` spots roxygen that never reached `NAMESPACE`, such as a function
  tagged `@export` that is not actually exported, which is the real cost of a
  forgotten `document()` run and something `R CMD check` cannot see. It reads
  `NAMESPACE` rather than file timestamps, so it behaves the same in CI.

* `license_year` looks for a genuinely unfilled `LICENSE` template, a leftover
  `<YEAR>` or `<COPYRIGHT HOLDER>`, rather than a valid but non-current year.

* `authors` catches an unfilled `usethis` template such as
  `person("First", "Last", , "you@example.com", ...)`, which `R CMD check` passes
  because the field is present but a reviewer sends back. It also validates the
  field's structure, including a person with no name or no role, an `Authors@R` that
  does not parse, and a missing maintainer.

* `title_case` and `license` hand off to R's own `tools::toTitleCase()` and
  `tools::analyze_license()`, so they match R's behaviour. `license` also catches a
  bare `MIT`, which needs `MIT + file LICENSE` pointing at a file that exists.
  `value_tags` walks each `.Rd` with `tools::parse_Rd()` and exempts data, class,
  package and `\keyword{internal}` topics, so its verdict no longer depends on the R
  version.

* `print_cat_usage` reports unsuppressable console output only from a function that
  also returns a value, and treats a verbosity gate as the guard rather than any
  enclosing `if`, `for` or `while` (#10, thanks @january3).

## Understands more of R

checktor reads far more of the ways R is actually written, so a clean run reflects
the code you wrote.

* `NAMESPACE` is parsed with R's own `base::parseNamespaceFile()`, so a multi-line
  `export()` block, an `exportPattern()`, and a method under a quoted non-syntactic
  generic such as `S3method("[", foo)` all read correctly. An `=` assignment is read
  as an assignment, and a classic `"print.foo" <- function(x)` definition, whose name
  parses as a `STR_CONST`, is visible to every name-based exemption.

* An S4 `setMethod("show", ...)` is an output method where `cat()` is the required
  idiom, `app$cat(...)` is a method call rather than `base::cat`, and a verbosity
  flag named `messages` counts as a gate.

* A `<<-` inside `local()`, `setRefClass()` or `R6Class()` binds in that scope rather
  than `.GlobalEnv`, a call in a default argument is scoped to that argument rather
  than the function body, and only the R chunks of a vignette are parsed, so its
  prose stays prose.

* `options()` and `par()` both read and write, and only a named argument makes the
  call a write, so `par("usr")[3]` and a package's own `reset_options()` stay clean.
  A restore factored into its own helper and registered with
  `on.exit(restore_par(op))` is recognised as the restore it is. A package's own
  namespaced option such as `options(datatable.verbose = ...)` is its own state, and
  a `setwd()` or `options()` inside a `callr` subprocess cannot reach the calling
  session. A `Sys.setenv()` setter that captures the prior state and hands it back
  honours the same restore contract.

* `file_operations` proves where a write lands, so `writeLines(x, "out.csv")` is
  reported, `writeLines(x, out_file)` is trusted to the caller who passed the path,
  and a formal that defaults into `~` is still caught.

* `if (require("pkgB"))` and roxygen's `@examplesIf` both count as the
  conditional-Suggests guard in an example, while `interactive()` does not, because
  it does not make the package available. A `system()` call inside an OS branch is
  the platform check the fix asks for, and an `install.packages()` behind a consent
  prompt is consent. `set.seed(123)` inside `if (FALSE)` cannot reach the RNG, and
  `T` or `F` inside `quote()`, `expression()` or `substitute()` are language tokens
  rather than logicals.

* `commented_examples` reports only an `\examples{}` block commented out entirely, so
  a prose comment beside working code is left alone (#9, thanks @TanguyBarthelemy).
  `example_structure` accepts a database, a prompt or a Shiny reactive context as a
  reason for `\dontrun{}`, and a `path/to/...` placeholder the same way. An install
  or a launcher call is not among them, since CRAN asks for `if (interactive())`
  there rather than for `\dontrun{}`. `library_in_pkg` exempts code sent to a
  parallel worker, whose search path starts empty.

* `software_names` catches the R-package and software-product names CRAN asks to see
  quoted, along with `WebAssembly`, and recognises `WASM`, `webR` and `Shinylive`
  when quoted. Programming-language and markup names moved to `language_names`, and a
  package can add its own with `Config/checktor/software_names`.

* Smaller sharpenings round this out. `description_quoted_quotes` looks only for a
  recognised software name rather than scare-quoted jargon, `description_length`
  counts words, `description_starts_with` gained its initial-capital rule, `acronyms`
  no longer reports `CMD`, and `urls` names the offending URL while skipping fenced
  code and `\verb{}` spans.

## Bug fixes

* `health_report()` reports the CRAN policy findings. It skipped that panel
  entirely, so the citable rejections were missing from every report, and the text
  and HTML formats carried no findings at all. Every format now lists each failing
  check, and says when the sections include advisory findings that the headline
  total leaves out.

* A treatment line renders its markup instead of printing braces. The report showed
  `{.code message()}` on screen, because the treatment reached `cli` as a value
  rather than as part of the format string.

* `package_size` measures what CRAN actually limits. It honours a bare directory
  entry in `.Rbuildignore`, such as the `^docs$` a pkgdown package uses, testing
  each file's ancestor directories as R does, so a pkgdown `docs/` or a build
  directory left beside your sources no longer counts. It also estimates the
  gzipped tarball rather than summing the files on disk, which over-reported any
  package whose bulk is compressible text.

* `issues()` keeps the file and line of a finding that carries a label. Only the
  plain `file.R:12` form used to parse, so a finding such as
  `a.R:3 (otherpkg:::helper)` or one from an example lost its location and could
  not be pointed at.

* `library_in_pkg` no longer reports a method that happens to be named `library` or
  `require`. An object calling its own `api$library()` was read as a call to the
  base function, which made the check awkward for packages built on reference
  classes.

* `title_length` treats the width a package listing may truncate to as a width
  rather than a limit, so a `Title` that exactly fills it is no longer reported.
  It shows in full, and only a longer one loses its tail. The message now says how
  much would be cut instead of only that the title is long.

* `mean(x, na.rm = T)`, the most common bare `T` in R, is now reported. An argument
  name parses as `SYMBOL_SUB` rather than `SYMBOL`, so a guard meant to skip
  `f(T = 1)` was skipping the argument value too.

* `prescribe()` surfaces every failed check. It previously walked only the curated
  treatment list, so a check could fail and `prescribe()` would say nothing
  (#4, thanks @january3). Its output no longer shows raw markup either.

* `print_cat_usage` no longer reports `cat()` inside S3 `print.*` and `format.*`
  methods, where it is the required idiom and base R's own `print.default()` uses
  it (#6, thanks @jhelvy).

* The `acronyms` check treats `principal component analysis (PCA)` and
  `PCA (principal component analysis)` alike as explained, and reads a line-wrapped
  gloss (#5, thanks @january3). A gloss whose expansion is a quoted software name
  counts too, so writing `'WebAssembly' (WASM)` as `software_names` asks satisfies
  both checks at once.

* `example_diagnose_scenario()` no longer prints the temporary package path, keeping
  machine-specific paths out of help pages.

## Documentation and website

* Two new vignettes explain where the rules come from (#8, thanks @TanguyBarthelemy).
  *Where the Checks Come From* maps every check to the CRAN Repository Policy or
  Writing R Extensions section it rests on, and to the CRAN Cookbook recipe where the
  authority is a convention rather than a rule. *What R CMD check Checks* walks
  through every step `R CMD check` performs, so the line between the standard checks
  and checktor's is clear.

* Every check's help page gained a *Source* section naming the rule behind it, a CRAN
  policy clause, a Writing R Extensions section, a CRAN Cookbook recipe, or an honest
  note that no rule applies, with a link wherever one exists.

* The original three vignettes gained figures. There is a coverage map of what
  `R CMD check`, `lintr` and `checktor` each catch, a view of the three data frames
  the accessors return, `checkup()` running at three latencies in CI, and, for
  Writing Your Own Checks, the road from source to finding alongside the XPath axes
  around a `SYMBOL_FUNCTION_CALL` anchor.

* The pkgdown site picked up a theme drawn from the package logo, with a light and
  dark toggle in the navbar.

# checktor 0.1.0

* Initial release.
* Adds `checktor()` as the top-level orchestrator, running five categories
  of diagnostics (code, DESCRIPTION, documentation, general, CRAN policy)
  against an R package directory.
* Adds the `checkup()` boolean wrapper for CI use, `prescribe()` for
  treatment recommendations, and `health_report()` for Markdown / HTML /
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

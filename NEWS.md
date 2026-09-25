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
  were renamed outright rather than deprecated, so replace `diagnose_` with `lab_`
  in any call to `diagnose_tf_usage()`, `diagnose_seed_setting()`,
  `diagnose_print_cat_usage()`, `diagnose_roxygen_usage()`, `diagnose_value_tags()`,
  `diagnose_example_structure()`, `diagnose_missing_examples()`,
  `diagnose_suggested_in_examples()`, `diagnose_package_size()`, `diagnose_urls()`,
  `diagnose_news_file()` or `diagnose_cran_comments_file()`.
  `diagnose_readme_relative_links()` is now `lab_readme_links()`, after the
  `readme_links` check it runs.

  Check names themselves are unchanged, so code that picks rows of `tidy()` or
  `issues()` by check name keeps working.

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
  follows the same default, so a missing `NEWS.md` no longer fails a build. On a
  `checktor()` result, `metadata$total_issues`, `metadata$failed_checks`,
  `n_issues()`, `n_failed_checks()` and `is_healthy()` now count those tiers alone,
  while `issues()` and `failed_checks()` still list every finding.

* A check that does not run is reported as skipped rather than as passing, so a
  clean bill of health never includes a check that never happened. `tidy()` gained a
  `skipped` column and `summary()` a `skipped` count, the names are in
  `metadata$skipped_checks`, and the printed result and every `health_report()`
  format name the checks that sat out. Printing a check or a category shows a
  skipped check as skipped, `summary()` counts it only as skipped, and a skipped row
  in `tidy()` is never `passed`, so `!passed & !skipped` picks out the failures and
  the `passed`, `failed` and `skipped` counts of `summary()` add up to `checks`.
  `passed()` asks only whether a check failed, so it is `TRUE` for a skipped one
  (#15, thanks @TroyHernandez).

* Every check is exported, so any check `checktor()` runs is one you can call
  yourself. The checks of the `DESCRIPTION` fields take
  `(path, verbose, desc = NULL)`, as the code checks take
  `(path, verbose, parsed = NULL)`, so either can reuse a parse you already have.
  `desc` may be what `read.dcf()` returns, and `issues()` and `tidy()` gained a
  `severity` column.

* `description_bare_r` was removed. It asked you to quote every bare `R` in the
  `Description`, which is not a rule anyone enforces. Writing R Extensions asks for
  single quotes around other packages and external software without naming `R`
  either way, and both forms clear CRAN, so `language_names` leaves a bare `R` and a
  quoted `'R'` alone alike and takes no position on which you prefer.

* Three checks left the default run because no authority supports them, and each
  stays exported for anyone who wants it. The CRAN rule behind
  `title_starts_with_article` applies to the `Description` and requires the word
  "package" after the article, not to the `Title`. Writing R Extensions treats
  single quotes as an inclusive list for non-English usage that a quoted function
  name fits, which is what `description_function_quotes` ruled out. And `?person`
  says authors who are natural persons hold copyright by default and need no `cph`
  role, which is what `cph_role` asked for (#17, thanks @eddelbuettel).

## New checks

* `detect_cores_robustness` catches a `detectCores()` result used without an `NA`
  guard. The help says it returns an integer, or `NA` when the answer is unknown,
  and `NA - 1` is `NA`, so the next comparison dies with `missing value where
  TRUE/FALSE needed`. The fix is `parallelly::availableCores()`.

* A family of checks mirrors CRAN's incoming filter, so you see those findings
  offline against your own sources before you submit.

  - `date_format` catches a `Date` that is not ISO 8601 `yyyy-mm-dd`, is over a
    month old, or lies in the future.
  - `version_format` catches a `Version` component with a leading zero or a
    suspiciously large one, while leaving a calendar-year version alone.
  - `encoding_utf8` catches an `Encoding` other than exactly `UTF-8`. CRAN's
    incoming check calls `latin1` and `latin2` deprecated, and a lower-case
    `utf-8` draws the same NOTE.
  - `identifier_format` validates the ORCID and ROR identifiers in `Authors@R`, and
    is reported as skipped when `Authors@R` cannot be read.

* `description_file` catches a `DESCRIPTION` that R cannot read: a line that is
  neither a field nor an indented continuation, a blank line that splits the file in
  two, or a file R cannot open at all, such as a directory in its place or one
  without read permission. `R CMD build` and `R CMD INSTALL` both stop on such a
  file. For a malformed line checktor used to skip the `DESCRIPTION` checks with
  nothing counted, so the file could not count against a clean bill of health, and
  for a blank line it judged the package on the fields above it alone. It is now a
  policy finding, the checks that read the fields, registered ones included, are
  reported as skipped, and `prescribe()` shows how to fix it.

* `description_fields` catches a `DESCRIPTION` field R does not know, which CRAN's
  incoming check NOTEs. The usual one is `Remotes`, which CRAN ignores since it
  installs dependencies from CRAN and Bioconductor alone. A typo such as
  `Bugreports`, `Import` or `Suggest` is silently ignored by R, so the finding
  names the field that was meant. `Config/` fields, `RoxygenNote` and the other
  forms R allows pass.

* `description_placeholders` catches a `Title`, `Description`, `Author` or
  `Maintainer` still holding the text a `usethis` or `package.skeleton()`
  template wrote, such as "What the Package Does (One Line, Title Case)", with the
  tests CRAN's incoming check uses.

* `title_package_name` catches a `Title` that is just the package name or opens
  with it and a colon, as in `toypkg: Fit Simple Models`, which Writing R
  Extensions asks you not to do and CRAN's incoming check NOTEs. A `Title` that
  opens with a name that is an ordinary word, as in "Survival Analysis", is left
  alone, since CRAN accepts it routinely.

* `license_file_unneeded` catches `+ file LICENSE` on a standard license such as
  `GPL-3`, `LGPL-3` or Apache, which the CRAN Cookbook asks you to drop along with
  the file, since "these are part of R". MIT and BSD, whose templates need the
  file, are left alone. A `LICENSE` that adds attribution requirements is the
  exception CRAN allows, and `Config/checktor/allow` records it.

* `hardcoded_credentials` scans string literals in `R/` for a leaked secret, knowing
  the tokens and keys used by providers such as GitHub, AWS, Google, OpenAI,
  Anthropic and Stripe, along with PEM private keys and JSON Web Tokens. A token
  published to CRAN is public and must be revoked, and `R CMD check` does not look
  for these. Only string literals are examined, so the same text in a comment never
  matches. See `?lab_hardcoded_credentials` for the full list.

* `spelling` runs `utils::aspell()` over the `Title` and `Description` to mirror
  CRAN's incoming spelling pass, with the same ignores (single-quoted names, `fn()`
  calls, `<doi:...>` targets) and British and `en_stats` words. It reads any
  `.aspell/` dictionary, `inst/WORDLIST`, or `Config/checktor` vocabulary you
  already keep, and is reported as skipped when no spell-check backend is installed
  or the one found fails to run. Turn it off with `options(checktor.spelling =
  FALSE)`. When it reports a word, `prescribe()` prints a ready-to-paste `.aspell/`
  snippet, since `inst/WORDLIST` alone does not clear CRAN's aspell NOTE but a
  `.aspell/` dictionary does.

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
    It reports one in `\donttest{}` too, since `R CMD check --as-cran` runs that
    code, where a prompt errors and an app waits for input. It reads the parsed
    example, so a function named in a comment or a string is not a call, an app
    `shinyApp()` builds without printing is not a launch, and only a guard that
    encloses the call excuses it, `@examplesIf interactive()` included (#19, thanks
    @TanguyBarthelemy). A guard still counts when it is combined with `&&`, or with
    `||` against another guard, wrapped in `suppressWarnings()`, split by a comment
    or kept in a variable assigned before it on every path, and
    `interactive() && f()` guards `f()` as an `if` would. An assignment on the
    right of `&&` or `||`, which may never run, is not such a path.
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
    and never put back. A change is put back when its old value is captured and
    later handed to the setter of the same kind in the same file, as in
    `old <- setwd(tempdir())` then `setwd(old)`. `par(no.readonly = TRUE)` is a
    read, not a change, and an `on.exit()` outside a function or a call that
    runs code in a frame of its own (`local()`, `with()`, `within()`, `eval()`,
    `evalq()`) is no restore: `R CMD check` never runs it, and knitr runs it
    straight away.
  - `example_internal_ns` catches `:::` in an example or vignette.
  - `example_tf_usage` catches `T` or `F` for `TRUE` or `FALSE` in an example, a
    vignette or a demo, judged by the same rule `tf_usage` applies to `R/`. Tests
    are read only with `tests = TRUE`, since CRAN rarely reads them.
  - `example_unparseable` catches an `\examples{}` section that is not valid R,
    `\dontrun{}` included, and names the line the parser stopped on. `R CMD check`
    writes `\dontrun{}` code out as comments and never parses it, while reviewers
    run it and send back "Unexecutable code in man/...". It is a robustness finding
    rather than policy, since Writing R Extensions lets `\dontrun{}` hold text that
    is not R.

  `internal_ns` covers the same rule in `R/`, where a `:::` call reaches an object
  another author is free to change in routine maintenance. `unexported_example_ns`
  used to suggest adding `:::` to an example, which is the change CRAN asks you to
  undo, so it now says to export the object or keep the topic internal instead.

  Every check in this family reads an example as R runs it. An Rd `%` comment is
  dropped, code that shares a line with a `\dontrun{}` or `\donttest{}` block is
  still read, a line of a hidden block that is not R, such as a `<your key>`
  placeholder, is passed over without hiding the rest of the example, and code under
  `#ifdef` is read for every platform. Sweave (`.Rnw`) vignettes are read alongside
  R Markdown and Quarto, and the line a finding gives is its line in the `.Rd` file
  or vignette.

* `rd_bibliography` reads the `\bibcitet{}`, `\bibcitep{}` and `\bibshow{}` macros R
  4.6.0 added to `.Rd` files and reports what `R CMD check` would: a key no
  bibliography holds, which R drops from the page, a key cited but never listed, and
  a `REFERENCES` file left at the top level. Keys are looked up as R does, in the
  package's `REFERENCES.rds`, `.R` or `.bib`, in R's own bibliography, and for
  `pkg::key` in an installed dependency, without running `REFERENCES.R`.
  `rd_bibliography_files`, at robustness tier, reports a `REFERENCES.bib` without
  `bibtex` in `Suggests` and a bibliography that is not installed because it is
  outside `inst/` or excluded by `.Rbuildignore`.

* `language_names` catches a bare programming-language or statistical-computing name
  in the `Title` or `Description` that CRAN asks to see single-quoted, covering
  names like `Python`, `Java`, `JavaScript`, `Rust`, `MATLAB`, `SAS` and `Stata`. It
  is the language counterpart to `software_names`, kept separate because a language
  name and a package name are different kinds of thing. Single-letter and
  common-word names are left out so ordinary prose stays quiet, and you can extend
  the list with `Config/checktor/language_names`. Like `software_names`, it judges
  each mention on its own and skips a quoted longer name such as `'MATLAB Runtime'`,
  a link, a DOI, a function call and a double-quoted title.

* `format_names` reports a format or markup name written without single quotes in
  the `Title` or `Description`: `JSON`, `HTML`, `XML`, `CSS`, `YAML`, `TOML`,
  `Markdown`, `LaTeX`, `TeX` and `SQL`, plus `C++`, `Fortran` and `Tcl`, which CRAN
  packages write either way. It runs only when you call it, at opinion tier. A
  census of CRAN in September 2026 found that packages accepted at new-package
  review in the previous 18 months wrote these names bare 62% of the time, against
  28% for the languages `language_names` covers, so a bare one does not count
  against a clean bill of health, and one in double quotes is not a
  `description_quoted_quotes` finding either (#16, thanks @TroyHernandez).
  `Config/checktor/format_names` extends its list.

* `code_exercised` catches a package that exports code but ships no examples, no
  tests and no vignettes, which CRAN's incoming check WARNs about as "No examples,
  no tests, no vignettes". `devtools::check()` leaves that check off, so the WARNING
  usually surfaces only at submission. It counts what `R CMD check` runs: a
  `tests/testthat/` folder without `tests/testthat.R` is not a test, and files
  `.Rbuildignore` excludes do not count.

* `citation_file` reads `inst/CITATION` for the calls CRAN's incoming check NOTEs:
  the old-style `citEntry()`, `personList()` and `as.personList()`, and
  `packageDescription()`, `library()` or `require()`, which assume the package is
  installed when R already hands the file its DESCRIPTION as `meta`. R's own
  `if (!exists("meta") || is.null(meta))` fallback is exempt. The file is parsed,
  never run, and one that does not parse is reported with its line.

## Configuration and extension

* checktor runs from anywhere inside a package (#12, thanks @january3). It walks up
  from the path you give it to find the `DESCRIPTION`, so a call with your working
  directory in `R/` or `tests/testthat/` examines the whole package instead of
  failing, and a file works as well as a directory. Every entry point resolves the
  root the same way, and `find_package_root()` is exported for custom checks. A
  directory outside any package still says so.

* A package can configure checktor through `Config/checktor/*` fields in its own
  DESCRIPTION. `disable` skips a check, `allow` mutes reviewed findings for a whole
  check or a `check:substring`, and `software_names`, `language_names`,
  `format_names` and `acronyms` extend those checks' vocabularies. A package with no
  such fields is unaffected.

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
  about a submission workflow rather than the package itself. The summary a verbose
  `checktor()` run prints now names them so you can find out they are there, and
  `metadata$on_request_checks` carries the list. Calling one is the only way to run
  it, and since they sit in the opinion tier, running one never changes a verdict.

* `register_check()` adds a check of your own to every `checktor()` run without
  editing checktor's source. Give it a name, a function returning a
  `checktor_check_result()`, a category and a severity tier, and it runs alongside
  the built-ins, appears in `issues()` and `tidy()`, and counts toward the verdict
  at its tier. `unregister_check()` and `registered_checks()` manage the registry. A
  check that cannot run returns `checktor_check_result()` with `skipped = TRUE` and
  a `skip_reason`, and is reported as skipped like a built-in one (#15).

* The AST toolkit the built-in checks use is exported, so a registered check has the
  same tools: `read_r_xml()`, `xpath_lints()`, `xpath_per_file()`,
  `undesirable_function_check()`, `not_under_fn_with_call_xpath()`, and the `.Rd`
  walkers `extract_rd_section()` and `collect_rd_text()`. The Writing Your Own
  Checks vignette walks through building and registering one.

## Checks improved

Several checks are more accurate, and a few hand off to R's own engines instead of
reimplementing them.

* `option_changes` suggests a fix. `prescribe()` shows the two ways out, namespacing
  a setting you keep for the session as `options(<PackageName>.key = ...)`, or
  restoring a temporary change with `on.exit()`.

* `home_writing` catches a write whose destination resolves to the user's home, such
  as `writeLines(x, "~/leaked.txt")`, or is an argument that defaults there, as in
  `function(x, path = "~/x.txt") writeLines(x, path)`. A read like
  `Sys.getenv("HOME")`, or a home path that is only the text being written or the
  file being copied, is not a write to the user's home.

* `globalenv_mod` reports a `<<-` only when its target genuinely reaches
  `.GlobalEnv`, so a closure updating its parent frame and a package-level cache
  written as `.cache <<- ...` both come out clean.

* `core_usage` inspects the worker count itself and understands the `parallel`,
  `snow`, `foreach`, `future`, `furrr`, `mirai`, `RcppParallel`, `data.table` and
  `BiocParallel` frameworks. It no longer keys off an `mc.cores` argument, which
  belongs to `mclapply()` alone, so `detectCores()` and a compliant
  `makeCluster(2L)` come out clean.

* `roxygen_usage` spots roxygen that never reached `NAMESPACE`, such as a function
  tagged `@export` that is not actually exported, which is the real cost of a
  forgotten `document()` run and something `R CMD check` cannot see. It reads
  `NAMESPACE` rather than file timestamps, so it behaves the same in CI.

* `license_year` looks for a genuinely unfilled `LICENSE` template, a leftover
  `<YEAR>` or `<COPYRIGHT HOLDER>`, rather than a valid but non-current year.

* `authors` catches an unfilled `usethis` template such as
  `person("First", "Last", , "you@example.com", ...)`, or the `Givenname` and
  `yourfault@somewhere.net` of `package.skeleton()`, which `R CMD check` passes
  because the field is present but a reviewer sends back. It also validates the
  field's structure, including a person with no name or no role, an `Authors@R` that
  does not parse, and a missing maintainer. It accepts the calls R's own reader
  accepts from R 4.6.0 on, a value wrapped in parentheses included, and reports any
  other call, a namespaced `utils::person()` among them, since `R CMD build` refuses
  it as a malformed `Authors@R` field. A person combined with a list in `c()`, from
  which R cannot read the authors, is reported as well.

* `references` applies the rules of CRAN's incoming check to the `Description`,
  which `devtools::check()` turns off. It catches a URL outside angle brackets, a
  DOI written as a `https://doi.org/` link or a bare `doi:`, a publisher link that
  embeds a DOI, and an arXiv id or link where CRAN now asks for the arXiv DOI
  `<doi:10.48550/arXiv.ID>`. It used to accept `<arXiv:...>` as correct. Each rule
  is one finding quoting the references that break it, and an arXiv finding gives
  the DOI to write. A space after `doi:` is no longer reported, since R does not
  NOTE it and CRAN's page links it all the same.

* `title_case` and `license` hand off to R's own `tools::toTitleCase()` and
  `tools::analyze_license()`, so they match R's behaviour. `license` also catches a
  bare `MIT`, which needs `MIT + file LICENSE` pointing at a file that exists, and
  a `LICENSE` holding the full MIT or BSD text rather than the `YEAR` /
  `COPYRIGHT HOLDER` stub, which `R CMD check` NOTEs as invalid DCF.
  `value_tags` walks each `.Rd` with `tools::parse_Rd()` and exempts data, class,
  package and `\keyword{internal}` topics, so its verdict no longer depends on the R
  version.

* `print_cat_usage` reports unsuppressable console output only from a function that
  also returns a value, and treats a verbosity gate as the guard rather than any
  enclosing `if`, `for` or `while` (#10, thanks @january3).

* `network_operations` reads an example as parsed R rather than searching its text,
  so a function named in a comment, a string or an Rd `%` comment is not a call. A
  request counts as guarded only when a guard encloses it, such as
  `if (curl::has_internet())`, `if (interactive())` or an `@examplesIf` asking one
  of them, combined with `&&` or with `||` against another guard. Only a call that
  makes a request is reported, and a request function handed to something that calls
  it, as in `lapply(urls, download.file)`, still counts, as does one called through
  parentheses, as in `(download.file)(u, f)`, or wrapped by `Vectorize()` or
  `purrr::possibly()`. Code in `\dontshow{}` and `\dontdiff{}` is now checked,
  since `R CMD check` runs it, even when the block sits against another one, as in
  `\dontrun{f()}\dontdiff{g()}`, which used to stop the example parsing; the other
  Rd example checks read such an example too. See `?lab_network_operations` for
  every guard it accepts.

* `suggested_in_examples` reads an example as parsed R and judges each use of a
  Suggested package by the guards that enclose it, so a package named in a comment
  or a string is not a use, and a guard for another package, or one elsewhere in the
  example, no longer excuses the use. A condition that is false under `R CMD check`,
  such as `interactive()`, excuses it too. A use inside `\donttest{}` is now
  reported, because `R CMD check --as-cran` runs that code, while R's base and
  recommended packages, such as parallel, MASS and survival, are never reported,
  since they ship with R. The advice now suggests `requireNamespace()` rather than
  `rlang::is_installed()`. See `?lab_suggested_in_examples` for every guard it
  accepts.

* `donttest_vs_dontrun` no longer suggests moving a slow `\dontrun{}` block to
  `\donttest{}` when the block uses a Suggested package without a guard, since
  `R CMD check --as-cran` runs `\donttest{}` code and the move would trade its
  advice for a `suggested_in_examples` finding. Each block is judged on its own, so
  such a block does not hold back the advice for another that is only slow.

* A run parses each help page, R file and example once, rather than once for every
  check that reads it, so `checktor()` finishes in well under half the time it
  took.

## Understands more of R

checktor reads far more of the ways R is actually written, so a clean run reflects
the code you wrote.

* `NAMESPACE` is parsed with R's own `base::parseNamespaceFile()`, so a multi-line
  `export()` block, an `exportPattern()`, and a method under a quoted non-syntactic
  generic such as `S3method("[", foo)` all read correctly. An `=` assignment is read
  as an assignment, and a classic `"print.foo" <- function(x)` definition, whose
  name parses as a `STR_CONST`, is visible to every name-based exemption.

* An S4 `setMethod("show", ...)` is an output method where `cat()` is the required
  idiom, `app$cat(...)` is a method call rather than `base::cat`, and a verbosity
  flag named `messages` counts as a gate.

* A `<<-` inside `local()`, `setRefClass()` or `R6Class()` binds in that scope
  rather than `.GlobalEnv`, a call in a default argument is scoped to that argument
  rather than the function body, and only the R chunks of a vignette are parsed, so
  its prose stays prose. A chunk set not to run is skipped, whether its header says
  `eval = FALSE` or a Quarto `#| eval: false` line does, and the header is read to
  its last brace, so a figure caption with braces of its own does not hide the
  option after it.

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
  and a formal that defaults into `~` is still caught. The write checks,
  `file_operations`, `home_writing` and `example_writes`, find the destination as R
  matches arguments: a named argument such as `sep =` does not move it, `to =` is
  where `file.copy()` and `file.rename()` write, and a call on the right of `|>` or
  `%>%` takes the piped value as its first argument, so
  `mtcars |> write.csv("out.csv")` is seen. A method that shares a writer's name,
  such as htmltools' `tags$svg()`, is not a write.

* A `system()` call inside an OS branch is the platform check the fix asks for, and
  an `install.packages()` behind a consent prompt is consent. `set.seed(123)` inside
  `if (FALSE)` cannot reach the RNG, and `T` or `F` inside `quote()`, `expression()`
  or `substitute()` are language tokens rather than logicals.

* `commented_examples` reports only an `\examples{}` block commented out entirely,
  so a prose comment beside working code is left alone (#9, thanks
  @TanguyBarthelemy). `example_structure` accepts a database, a prompt or a Shiny
  reactive context as a reason for `\dontrun{}`, and a `path/to/...` placeholder the
  same way. An install or a launcher call is not among them, since CRAN asks for `if
  (interactive())` there rather than for `\dontrun{}`. `library_in_pkg` exempts code
  sent to a parallel worker, whose search path starts empty.

* `software_names` catches the R-package and software-product names CRAN asks to see
  quoted, along with `WebAssembly`, and recognises `WASM`, `webR` and `Shinylive`
  when quoted. Programming-language names moved to `language_names` and format and
  markup names to `format_names`, and a package can add its own with
  `Config/checktor/software_names`. It judges each place a name appears, so one
  quoted mention no longer excuses a bare one elsewhere. A name is not bare inside a
  quoted longer name such as `'shiny.semantic'`, or in a span CRAN's own incoming
  spell check skips, a `<https://...>` or `<doi:...>` link or a function call such
  as `purrr::map()`. checktor also skips a plain web address and a double-quoted
  title, and does not read a dotted name such as `shiny.semantic` as `shiny`.

* Smaller sharpenings round this out. `description_quoted_quotes` looks only for a
  recognised software name rather than scare-quoted jargon, in the `Title` as well
  as the `Description`. It knows every name `software_names` and `language_names`
  ask to see quoted, including those a package adds, and reads a lower-case `"rust"`
  or `"r"` as a word rather than `Rust` or `R`, or a quote glued to a word, as in
  `"R"estrictions`, as a quotation. A Title Case `"Bugs"` in the `Title` is the
  word, not `BUGS`. `description_length` counts words,
  `description_starts_with` gained its initial-capital rule, `acronyms` no longer
  reports `CMD`, `YAML` or `TOML`, and `urls` names the offending URL while skipping
  fenced code and `\verb{}` spans. `urls` and `network_operations` read every
  vignette source R builds, Sweave's `.Rnw` included, and nothing in a subfolder
  R does not build, and a URL ends at the brace closing a LaTeX `\url{}`.

## Bug fixes

* `health_report()` reports the CRAN policy findings. It skipped that panel
  entirely, so the citable rejections were missing from every report, and the text
  and HTML formats carried no findings at all. Every format now lists each failing
  check, and the Markdown report says when the sections include advisory findings
  that the headline total leaves out.

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

* `cph_role` accepts a `Copyright` field as well as a `cph` role. It reads the roles
  from the parsed `Authors@R` rather than searching the field's text, so an address
  such as `cph@example.com` no longer passes for the role. A package with no
  `Authors@R` is read from its `Author` field, where a role in square brackets such
  as `ACME Corporation [cph]` counts, rather than failing for the missing field.

* `mean(x, na.rm = T)`, the most common bare `T` in R, is now reported. An argument
  name parses as `SYMBOL_SUB` rather than `SYMBOL`, so a guard meant to skip
  `f(T = 1)` was skipping the argument value too.

* The code checks read your code when the `keep.parse.data` option is off, as it is
  while `sys.source()` runs a file. R then keeps no parse tree, so every check that
  reads one saw an empty file and passed, whatever the code contained.

* `prescribe()` surfaces every failed check. It previously walked only the curated
  treatment list, so a check could fail and `prescribe()` would say nothing
  (#4, thanks @january3). Its output no longer shows raw markup either.

* `prescribe()` and `health_report()` take their treatments from one table, so a
  check's remedy reads the same wherever it is printed. Every check now has one,
  where `prescribe()` covered seven and `health_report()` three, and the text and
  HTML reports carry it too. `prescribe()` lists what a check found above its
  treatment.

* `print_cat_usage` no longer reports `cat()` inside S3 `print.*` and `format.*`
  methods, where it is the required idiom and base R's own `print.default()` uses
  it (#6, thanks @jhelvy).

* The `acronyms` check treats `principal component analysis (PCA)` and
  `PCA (principal component analysis)` alike as explained, and reads a line-wrapped
  gloss (#5, thanks @january3). A gloss whose expansion is a quoted software name
  counts too, so writing `'WebAssembly' (WASM)` as `software_names` asks satisfies
  both checks at once.

* `acronyms` skips anything in quotes, single or double, straight or typographic, so
  a `'MATLAB'` or `'SPSS'` written the way `language_names` asks is no longer
  reported as an unexplained acronym, and neither is one inside a quoted article
  title, even beside an em dash, an ellipsis or a non-breaking space. It also
  ignores the letters inside a link, a `<doi:...>` or a function call.

* `readme_links` no longer reads `[[` subsetting in an R code block as a link
  (#13, thanks @TanguyBarthelemy).

* Checks skip whatever `.Rbuildignore` excludes, such as {devtag} `@dev` help pages
  and `vignettes/articles/` (#14, thanks @TanguyBarthelemy).

* `urls` skips tilde-fenced and nested code blocks, and drops the backtick from a
  quoted URL.

* `unexported_example_ns` reads a topic whose alias begins with an operator, such as
  `[.myclass`, instead of stopping with "invalid regular expression" (#18, thanks
  @RodrigoZepeda).

* A check named in `Config/checktor/disable` no longer runs. It used to run and
  print its finding before being dropped from the results. To turn a check off in
  every package without touching each `DESCRIPTION`, set
  `options(checktor.disable = ...)` (#17, thanks @eddelbuettel).

* A finding prints the text it quotes from your package as written. A `Title`, file
  name or README link reached `cli` as part of a template, so a brace in it, such as
  a tidyverse-style `{pkg}` or the `{id}` of a URL template, was evaluated as R
  code, which either ran it or turned the finding into an error. Messages naming
  `\dontrun{}` and `\donttest{}` keep their braces.

* A README, NEWS file, vignette or `DESCRIPTION` that R cannot open, such as a
  directory where the file is expected or a file without read permission, no longer
  prints R's own warnings in the middle of checktor's output.

* `example_diagnose_scenario()` no longer prints the temporary package path, keeping
  machine-specific paths out of help pages. It names that package with `tempfile()`,
  so it no longer creates or advances `.Random.seed`, and two scenarios built in the
  same second can no longer share a directory. It places a scenario by its extension
  rather than its folder, an `.R` file in `R/`, an `.Rd` file in `man/`, a vignette
  in `vignettes/` and a `.txt` file as the `DESCRIPTION`, so
  `network_examples/bad_network_example.Rd` is read by the Rd checks rather than
  landing in `R/`. Any other extension is an error.

* `example_diagnose_scenario()` and `show_example_files()` report through `cli`,
  like the rest of checktor, so the file `show_content` prints arrives as a message
  rather than on standard output. It still prints exactly as written, braces and
  all.

* The `configure_doctor()` example puts back the options it sets. It relied on an
  `on.exit()` outside any function, which an example never runs at the right time,
  so running the example left them changed.

## Documentation and website

* Two new vignettes explain where the rules come from (#8, thanks
  @TanguyBarthelemy). *Where the Checks Come From* maps every check to the CRAN
  Repository Policy or Writing R Extensions section it rests on, and to the CRAN
  Cookbook recipe where the authority is a convention rather than a rule. *What R
  CMD check Checks* walks through every step `R CMD check` performs, so the line
  between the standard checks and checktor's is clear.

* Every check's help page gained a *Source* section naming the rule behind it, a
  CRAN policy clause, a Writing R Extensions section, a CRAN Cookbook recipe, or an
  honest note that no rule applies, with a link wherever one exists.

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

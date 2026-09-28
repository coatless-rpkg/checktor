# Where the Checks Come From

Every checktor check exists for a reason, and that reason has a source.
This page maps each check to where its authority comes from, linking to
the exact section wherever one exists, and to the severity tier that
authority earns. For the full argument behind any single check, read its
help page (for example
[`?lab_option_changes`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/lab_option_changes.md)),
which spells out the reasoning and the exemptions. This page is the map
across all of them.

## The tiers, and what each one rests on

A check’s severity tier tells you what kind of authority stands behind
it.

- **`policy`** is a rule CRAN enforces, so breaking one can get a
  package rejected and a policy finding counts against a clean bill of
  health. Most are written in the [CRAN Repository
  Policy](https://cran.r-project.org/web/packages/policies.html) or
  [Writing R
  Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html),
  the two documents CRAN treats as binding, and some mirror a **CRAN
  incoming check**, one of the NOTEs that
  [`R CMD check --as-cran`](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
  raises against a submission. A handful are long-standing requirements
  reviewers apply that no clause in either manual actually states, and
  for those the [CRAN
  Cookbook](https://contributor.r-project.org/cran-cookbook/) is the
  written record. Restoring
  [`options()`](https://rdrr.io/r/base/options.html),
  [`par()`](https://rdrr.io/r/graphics/par.html) and the working
  directory is the clearest example: it is one of the most common
  reasons a package is sent back, and neither manual mentions it.
- **`robustness`** is a real defect that CRAN will still accept, such as
  a `detectCores()` that can return `NA`. It counts toward the verdict
  too, because it can still crash a user.
- **`opinion`** is a convention that experienced maintainers and
  reviewers tend to ask for, with nothing enforcing it. Worth knowing,
  but it stays outside the default verdict, which is `policy` and
  `robustness` only.

The source column names which kind each check is. Many conventions are
written down in the [CRAN
Cookbook](https://contributor.r-project.org/cran-cookbook/), the R
Contributor guide to the problems that get packages sent back, and the
column links to the individual recipe wherever there is one. Where a
check has no citable source at all, it says so plainly.

## Which checks run

Almost every check runs every time. Two depend on the machine, and when
one cannot run
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
reports it as skipped rather than passed, so a clean bill of health
never includes a check that never happened.
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) carries a
`skipped` column, and the names are in `metadata$skipped_checks`. The
same goes for the checks that read `DESCRIPTION` fields when R cannot
read the file, which `description_file` reports as a policy finding, and
for `identifier_format` when `Authors@R` cannot be read. Five more run
only when you call them; they were never asked for, so they are not
skipped, and `metadata$on_request_checks` names them so you can find
them.

| Check | Runs | Why |
|----|----|----|
| `url_liveness` | at the console | It fetches every URL, so it stays off in scripts and under `R CMD check`, where the network would decide the result. `options(checktor.url_check = TRUE)` runs it everywhere. |
| `spelling` | with a backend | It needs `aspell` or `hunspell` installed. `options(checktor.spelling = FALSE)` turns it off and reports it as skipped; `options(checktor.disable = "spelling")` or `Config/checktor/disable: spelling` leaves it out of the run entirely. |
| `cran_comments_file` | when you call it | A `cran-comments.md` is a submission workflow rather than a property of the package. |
| `title_starts_with_article` | when you call it | No authority supports it, so it stays available without being part of a run. |
| `description_function_quotes` | when you call it | The same, and Writing R Extensions reads the other way. |
| `cph_role` | when you call it | [`?person`](https://rdrr.io/r/utils/person.html) says authors who are natural persons hold copyright by default, so most packages need no `cph` role. |
| `format_names` | when you call it | CRAN accepts `JSON`, `HTML`, `SQL` and the other format names written bare, so quoting them is a matter of style. |

Everything else runs always, and a new check is part of the run unless
it says otherwise, so nothing goes missing by being forgotten.

## Code checks

| Check | Tier | Source |
|----|----|----|
| `seed_setting` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): a package “should not modify the global environment”, and [`set.seed()`](https://rdrr.io/r/base/Random.html) writes `.Random.seed` there. Recipe: [Setting a Specific Seed](https://contributor.r-project.org/cran-cookbook/code_issues.html#setting-a-specific-seed). |
| `print_cat_usage` | `policy` | [Cookbook: Using print()/cat()](https://contributor.r-project.org/cran-cookbook/code_issues.html#using-printcat): diagnostic output belongs in [`message()`](https://rdrr.io/r/base/message.html) or [`warning()`](https://rdrr.io/r/base/warning.html), which a user can suppress. A reviewer requirement rather than a clause in the manuals. |
| `option_changes` | `policy` | [Cookbook: Change of Options, Graphical Parameters and Working Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory): restore anything a function changes, via [`on.exit()`](https://rdrr.io/r/base/on.exit.html). Neither manual states this, but it is among the most common reasons a package is sent back. |
| `warn_option` | `policy` | [Cookbook: Setting options(warn = -1)](https://contributor.r-project.org/cran-cookbook/code_issues.html#setting-optionswarn--1): the same requirement, for the warning level. |
| `home_writing` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): “Packages should not write in the user’s home filespace … nor anywhere else on the file system apart from the R session’s temporary directory”. Recipe: [Writing Files and Directories to the Home Filespace](https://contributor.r-project.org/cran-cookbook/code_issues.html#writing-files-and-directories-to-the-home-filespace). |
| `globalenv_mod` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): “Packages should not modify the global environment (user’s workspace).” Recipe: [Writing to the .GlobalEnv](https://contributor.r-project.org/cran-cookbook/code_issues.html#writing-to-the-.globalenv). |
| `installed_packages` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): a package must not install other packages when it runs. Recipe: [Calling installed.packages()](https://contributor.r-project.org/cran-cookbook/code_issues.html#calling-installed.packages). |
| `software_install` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): a package must not download and install external software at load or run time. Recipe: [Installing Software](https://contributor.r-project.org/cran-cookbook/code_issues.html#installing-software). |
| `core_usage` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): “If running a package uses multiple threads/cores it must never use more than two simultaneously”. Recipe: [Using more than 2 Cores](https://contributor.r-project.org/cran-cookbook/code_issues.html#using-more-than-2-cores). |
| `sys_setenv` | `policy` | No clause names environment variables, but they are session state exactly as [`options()`](https://rdrr.io/r/base/options.html) are, and the same restore-on-exit requirement applies. See [Cookbook: Change of Options, Graphical Parameters and Working Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory). |
| `tf_usage` | `robustness` | No binding rule, but a documented one: [Cookbook: T/F Instead of TRUE/FALSE](https://contributor.r-project.org/cran-cookbook/code_issues.html#tf-instead-of-truefalse). `T` and `F` are ordinary variables (see [`?logical`](https://rdrr.io/r/base/logical.html)) that can be rebound, so they are unsafe stand-ins. |
| `library_in_pkg` | `robustness` | [WRE: Package Dependencies](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Package-Dependencies): package code should reach dependencies through `Imports` and `::`, not attach them with [`library()`](https://rdrr.io/r/base/library.html). |
| `detect_cores_robustness` | `robustness` | No formal rule. `?detectCores` states it returns “`NA` if the answer is unknown”, and the arithmetic that usually follows then crashes. |
| `hardcoded_credentials` | `robustness` | No formal rule. A token or key committed to a package is public the moment it reaches CRAN and must be revoked. |
| `internal_ns` | `robustness` | CRAN asks you to omit one colon, since `:::` reaches an object whose author may change it. `R CMD check` reports it too, under dependencies in R code. |
| `temp_cleanup` | `opinion` | [Cookbook: Leaving Files in the Temporary Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#leaving-files-in-the-temporary-directory). [`tempdir()`](https://rdrr.io/r/base/tempfile.html) is removed at session end, so an un-[`unlink()`](https://rdrr.io/r/base/unlink.html)ed tempfile breaks no rule, which is why this stays advisory. |

## DESCRIPTION checks

| Check | Tier | Source |
|----|----|----|
| `description_file` | `policy` | [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file): “Fields start with an ASCII name immediately followed by a colon” and “Continuation lines … start with a space or tab”. `R CMD build` and `R CMD INSTALL` stop on a file that breaks this, or that a blank line splits in two. |
| `description_fields` | `policy` | [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages): it NOTEs “Unknown, possibly misspelled, fields in DESCRIPTION”, allowing `Config/` and a few other prefixes. `Remotes` is the usual one; [CRAN Policy](https://cran.r-project.org/web/packages/policies.html) wants strong dependencies “available from CRAN or the Bioconductor software repository”. |
| `description_placeholders` | `policy` | [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages): it NOTEs “DESCRIPTION fields with placeholder content”, the `Title`, `Description`, `Author` or `Maintainer` a `usethis` or [`package.skeleton()`](https://rdrr.io/r/utils/package.skeleton.html) template wrote. |
| `software_names` | `policy` | [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file): “Refer to other packages and external software in single quotes”. Recipe: [Formatting Software Names](https://contributor.r-project.org/cran-cookbook/description_issues.html#formatting-software-names). |
| `language_names` | `policy` | [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file): the same rule, for programming languages and statistical software such as `Python`, `Java`, `MATLAB` and `SAS`. Recipe: [Formatting Software Names](https://contributor.r-project.org/cran-cookbook/description_issues.html#formatting-software-names). |
| `description_quoted_quotes` | `policy` | [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file): double quotes are for book titles and similar; software names take single quotes. The format names `format_names` covers are left out, since CRAN accepts them bare. Recipe: [Formatting Software Names](https://contributor.r-project.org/cran-cookbook/description_issues.html#formatting-software-names). |
| `license` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): an invalid or unrecognised `License` field is a rejection. Recipe: [LICENSE files](https://contributor.r-project.org/cran-cookbook/description_issues.html#license-files). |
| `license_file_unneeded` | `policy` | [Cookbook: LICENSE files](https://contributor.r-project.org/cran-cookbook/description_issues.html#license-files): CRAN does “not need” `+ file LICENSE` “and the file as these are part of R”, unless the file adds attribution requirements or restrictions. `R CMD check` NOTEs the pointer on a license that takes no extension, and the [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages) on one that does, such as `GPL-3`. |
| `authors` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): a placeholder or malformed `Authors@R`, including a missing maintainer, is a rejection. Recipe: [Using Authors@R](https://contributor.r-project.org/cran-cookbook/description_issues.html#using-authorsr). |
| `title_case` | `policy` | [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file): the `Title` “should use title case”; the [`--as-cran`](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages) incoming check flags one that does not. Recipe: [Title Case](https://contributor.r-project.org/cran-cookbook/description_issues.html#title-case). |
| `title_package_name` | `policy` | [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file): “Do not repeat the package name: it is often used prefixed by the name.” The [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages) NOTEs a `Title` that is the name or starts with it. Only the name alone and `name:` are flagged, since CRAN routinely accepts a name that is an ordinary word, as in “Survival Analysis”. |
| `date_format` | `policy` | [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file): “the ‘yyyy-mm-dd’ format of the ISO 8601 standard is strongly recommended”; the [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages) also flags a stale or future date. |
| `version_format` | `policy` | [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file): a `Version` is “a sequence of at least two … non-negative integers”; the [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages) flags a leading zero or an implausible value. |
| `encoding_utf8` | `policy` | [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file): a non-ASCII DESCRIPTION “should contain an ‘Encoding’ field”; the [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages) NOTEs any value but `UTF-8`, `latin1` and `latin2` included, as deprecated. |
| `description_starts_with` | `policy` | [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file): “It is good practice not to start with the package name, ‘This package’ or similar”; flagged by the [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages). |
| `references` | `policy` | [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages): it NOTEs a URL outside `<...>`, a DOI not written `<doi:prefix/suffix>` or given as a publisher link, and an arXiv id where the [submission checklist](https://cran.r-project.org/web/packages/submission_checklist.html) asks for the arXiv DOI `<doi:10.48550/arXiv.ID>`. Recipe: [References](https://contributor.r-project.org/cran-cookbook/description_issues.html#references). |
| `identifier_format` | `policy` | [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages): it NOTEs a malformed ORCID or ROR identifier in `Authors@R`. |
| `license_year` | `robustness` | No binding rule. An unfilled `LICENSE` template, with `<YEAR>` or `<COPYRIGHT HOLDER>` left in, leaves a placeholder. Recipe: [LICENSE files](https://contributor.r-project.org/cran-cookbook/description_issues.html#license-files). |
| `spelling` | `opinion` | [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages) (aspell), but it needs a spell-check backend and is noisy, so checktor keeps it advisory. |
| `acronyms` | `opinion` | [Cookbook: Explaining Acronyms](https://contributor.r-project.org/cran-cookbook/description_issues.html#explaining-acronyms). Reviewers ask for an acronym to be spelled out once, but nothing enforces it. |
| `cph_role` | `opinion` | [`?person`](https://rdrr.io/r/utils/person.html): `cph` is for copyright holders, and authors who are natural persons hold copyright by default without it. CRAN Policy asks only that ownership be clear, which a `Copyright` field also does. Runs on request. |
| `format_names` | `opinion` | No rule. [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file) asks for quotes around software, and `JSON`, `HTML`, `XML`, `CSS`, `YAML`, `TOML`, `Markdown`, `LaTeX`, `TeX` and `SQL` are formats; `C++`, `Fortran` and `Tcl` are written either way. A census of CRAN in September 2026 found that packages accepted at new-package review in the previous 18 months wrote these bare 62% of the time, against 28% for the names `language_names` checks. Runs on request. |
| `description_length` | `opinion` | [Cookbook: Description Length](https://contributor.r-project.org/cran-cookbook/general_issues.html#description-length). A one-line `Description` is thin, and reviewers ask for more. |
| `title_length` | `opinion` | [WRE: The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file): “Some package listings may truncate the title to 65 characters”. That is a display width, not a limit, so a `Title` filling it exactly still shows in full and nothing rejects a longer one. |
| `title_redundant_phrases` | `opinion` | Convention only. Phrases like “R package to” are redundant in a `Title`. |
| `title_starts_with_article` | `opinion` | No rule. A mis-transplant of a real CRAN rule, kept callable but off by default. |
| `description_function_quotes` | `opinion` | No rule. An invented rule, kept callable but off by default. |

## Documentation checks

| Check | Tier | Source |
|----|----|----|
| `suggested_in_examples` | `policy` | [WRE: Suggested packages](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Suggested-packages): a package from `Suggests` used in an example must be guarded so the example still runs without it. |
| `rd_bibliography` | `policy` | [WRE: Bibliographic citations and references](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Bibliographic-citations-and-references): R 4.6’s `\bibcitet{}`, `\bibcitep{}` and `\bibshow{}` read the package bibliography. `R CMD check` warns “Could not find bibentries for the following keys” and notes “Bibentries cited but not shown”, and `--as-cran` notes a `REFERENCES` file at the top level as non-standard. |
| `roxygen_usage` | `robustness` | No binding rule. A function tagged `@export` that never reached `NAMESPACE` is not actually exported. Recipe: [Repeated Rejections of Issues in Manuals If Using roxygen2](https://contributor.r-project.org/cran-cookbook/docs_issues.html#repeated-rejections-of-issues-in-manuals-if-using-roxygen2). |
| `unexported_example_ns` | `robustness` | No formal rule. An example that reaches for an unexported object will error when it runs. |
| `rd_bibliography_files` | `robustness` | [WRE: Bibliographic citations and references](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Bibliographic-citations-and-references) keeps the bibliography as `inst/REFERENCES.R` or `inst/REFERENCES.bib`, which “needs bibtex to be installed”. Nothing checks either: a `.bib` with no `bibtex` in `Suggests` fails a build that installs only what is declared, and one outside `inst/` is never installed for another package’s `pkg::key`. |
| `value_tags` | `opinion` | [WRE: Documenting functions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Documenting-functions) describes `\value{}` and [Cookbook: Missing -tags in .Rd-files](https://contributor.r-project.org/cran-cookbook/docs_issues.html#missing-value-tags-in-.rd-files) is the recipe reviewers cite, but `R CMD check` does not require it. |
| `example_structure` | `opinion` | [Cookbook: Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples). `\dontrun{}` should wrap only code that genuinely cannot run inside a check. |
| `donttest_vs_dontrun` | `opinion` | [Cookbook: Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples): `\donttest{}` is the wrapper for examples that merely run long, where `\dontrun{}` is often reached for instead. |
| `missing_examples` | `opinion` | [Cookbook: Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples). Exported functions are expected to carry an `\examples{}` block. |
| `commented_examples` | `opinion` | Convention only. An `\examples{}` block that is entirely commented out demonstrates nothing. |

## Example, vignette and demo checks

These cover the code outside `R/` that CRAN reads, where several of the
most common rejections land. Each rule below is one a maintainer has
received verbatim.

| Check | Tier | Source |
|----|----|----|
| `example_interactive` | `policy` | [Cookbook: Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples): a function that only runs interactively belongs in `if (interactive())`, so a reader sees it is not for a script, rather than in `\dontrun{}`. In `\donttest{}` it is worse: `R CMD check --as-cran` runs that code, where a prompt errors and an app waits for input. |
| `example_installs` | `policy` | [Cookbook: Installing Software](https://contributor.r-project.org/cran-cookbook/code_issues.html#installing-software): do not install packages from a function, an example or a vignette. |
| `example_writes` | `policy` | [Cookbook: Writing Files and Directories to the Home Filespace](https://contributor.r-project.org/cran-cookbook/code_issues.html#writing-files-and-directories-to-the-home-filespace): an example, vignette or test may write only to [`tempdir()`](https://rdrr.io/r/base/tempfile.html). |
| `example_state` | `policy` | [Cookbook: Change of Options, Graphical Parameters and Working Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory): restore [`options()`](https://rdrr.io/r/base/options.html), [`par()`](https://rdrr.io/r/graphics/par.html) and the working directory changed in an example, vignette or demo. |
| `example_internal_ns` | `policy` | CRAN asks you to omit one colon, since `:::` reaches an object whose behaviour the author may change. |
| `example_tf_usage` | `robustness` | [Cookbook: T/F Instead of TRUE/FALSE](https://contributor.r-project.org/cran-cookbook/code_issues.html#tf-instead-of-truefalse): `T` and `F` “should not be used as variable names in your code, examples, tests or vignettes”. The same rule as `tf_usage`, over examples, vignettes and demos. |
| `example_unparseable` | `robustness` | A rejection reviewers send verbatim: “Unexecutable code in man/…Rd”. [WRE: Documenting functions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Documenting-functions) lets `\dontrun{}` text be something other than R, but reviewers run examples with it included, and `R CMD check` never parses it, so a missing bracket or a `<your key>` placeholder there goes unseen. |

## General checks

| Check | Tier | Source |
|----|----|----|
| `code_exercised` | `policy` | [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages): `--as-cran` WARNs “No examples, no tests, no vignettes” for a package that exports code and ships none of the three. [CRAN Policy](https://cran.r-project.org/web/packages/policies.html) asks that “the checks that are left do exercise all the features of the package”. |
| `citation_file` | `policy` | [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages): `--as-cran` NOTEs an `inst/CITATION` that calls the old-style [`citEntry()`](https://rdrr.io/r/utils/citEntry.html) or [`personList()`](https://rdrr.io/r/utils/personList.html) and lists calls to [`packageDescription()`](https://rdrr.io/r/utils/packageDescription.html), [`library()`](https://rdrr.io/r/base/library.html) and [`require()`](https://rdrr.io/r/base/library.html). [WRE: CITATION files](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#CITATION-files): “It is desirable (and essential for CRAN) that the CITATION file does not contain calls to functions such as packageDescription which assume the package is installed”. |
| `package_size` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): CRAN limits the size of the built tarball. Recipe: [Package Size](https://contributor.r-project.org/cran-cookbook/general_issues.html#package-size), which gives the practical figures. |
| `url_liveness` | `robustness` | [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages): `--as-cran` fetches URLs and NOTEs 404s and redirects. It runs at the console and stays off in scripts and checks, where the network would decide the result. |
| `readme_links` | `robustness` | No formal rule. A relative README link whose target is excluded from the tarball breaks on the package page. |
| `urls` | `opinion` | Convention only. Preferring `https://` is good advice, but CRAN’s NOTE is about broken URLs rather than the scheme. |
| `news_file` | `opinion` | Convention only. A `NEWS` file is expected but not required. |
| `cran_comments_file` | `opinion` | Convention only. A `cran-comments.md` is a submission workflow rather than a property of the package, which is why it runs only when you call it. |

## CRAN policy checks

| Check | Tier | Source |
|----|----|----|
| `browser_calls` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): checks run non-interactively, so a debugging leftover such as [`browser()`](https://rdrr.io/r/base/browser.html) must not be left in. |
| `file_operations` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): “Packages should not write … anywhere … apart from the R session’s temporary directory”. Recipe: [Writing Files and Directories to the Home Filespace](https://contributor.r-project.org/cran-cookbook/code_issues.html#writing-files-and-directories-to-the-home-filespace). |
| `network_operations` | `policy` | [CRAN Policy](https://cran.r-project.org/web/packages/policies.html): “Packages which use Internet resources should fail gracefully with an informative message if the resource is not available”. |
| `system_calls` | `robustness` | No flat rule. A raw [`system()`](https://rdrr.io/r/base/system.html) or [`system2()`](https://rdrr.io/r/base/system2.html) call needs review for portability rather than being an automatic violation. |

## What the Cookbook covers that checktor does not

checktor has a check for every [CRAN
Cookbook](https://contributor.r-project.org/cran-cookbook/) recipe that
describes a pattern in your sources. Two recipes do not, and neither is
something a static reader can answer.

*Overall Checktime* is about a measurement rather than a pattern. The
NOTE reads “Overall checktime 20 min \> 10 min”, and nothing in your
sources says how long they will take to run. `R CMD check` reports the
figure, and the fix is fewer or smaller examples, vignettes and tests.

*Communicating with CRAN* is advice on writing to CRAN, including
copying `cran-submissions@r-project.org` and explaining yourself in
`cran-comments.md`. The one checkable part of it, whether that file is
there, is `cran_comments_file`.

## When checktor and an authority disagree

A tier is where a check’s authority sits, not how strongly checktor
feels about it. A few checks are deliberately `opinion` because no
authority backs them in either direction, and three of those
(`title_starts_with_article`, `description_function_quotes` and
`format_names`) are kept callable but left out of the default run for
the same reason. Two more `opinion` checks run only when you call them:
`cph_role`, because its source says most authors need no `cph` role, and
`cran_comments_file`, because it asks about a submission workflow rather
than the package. If a finding does not match your reading of the
policy, the tier is the first thing to look at: an `opinion` finding is
a conversation, not a requirement. You can turn any check off for one
package with `Config/checktor/disable` in its DESCRIPTION, or for every
package with `options(checktor.disable = ...)`, for example in
`.Rprofile`. A disabled check does not run at all.

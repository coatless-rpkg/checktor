# The remedy for each built-in check, kept in one place.
#
# prescribe() and every health_report() format read their treatment from here, so
# a check's remedy reads the same wherever it is printed. Each entry is keyed by
# check name and holds
#   title      the heading prescribe() prints above the remedy
#   treatment  one line, in cli inline markup ({.code x}, {.file x}); a literal
#              brace is doubled, as cli expects
#   example    optional worked example, printed as code, or
#   example_fn optional function(check_result) that builds the example from the
#              finding itself (spelling fills in the words it flagged)
#
# A test holds this list to BUILTIN_CHECKS, so a new check cannot ship without
# a remedy. A check added with register_check() has no entry, and prescribe()
# falls back to listing its issues.
treatments <- list(
  # ---- code ----
  tf_usage = list(
    title = "T/F Usage Issues",
    treatment = "Replace {.code T} with {.code TRUE} and {.code F} with {.code FALSE}",
    example = c(
      "# Before",
      "result <- T",
      "",
      "# After",
      "result <- TRUE"
    )
  ),
  seed_setting = list(
    title = "Hardcoded Seed Issues",
    treatment = paste0(
      "Add a {.code seed} argument to functions that set a seed, so callers ",
      "control randomness"
    ),
    example = c(
      "# Before",
      "my_function <- function(data) {",
      "  set.seed(123)",
      "  # ...",
      "}",
      "",
      "# After",
      "my_function <- function(data, seed = NULL) {",
      "  if (!is.null(seed)) set.seed(seed)",
      "  # ...",
      "}"
    )
  ),
  print_cat_usage = list(
    title = "Unsuppressable Output Issues",
    treatment = paste0(
      "Replace {.code print()} and {.code cat()} with {.code message()}, or gate ",
      "the output on a {.code verbose} argument"
    ),
    example = c(
      "# Before",
      "print('Processing...')",
      "",
      "# After - option 1",
      "message('Processing...')",
      "",
      "# After - option 2",
      "my_function <- function(data, verbose = TRUE) {",
      "  if (verbose) cli::cli_inform('Processing...')",
      "}"
    )
  ),
  option_changes = list(
    title = "Unrestored Option Changes",
    treatment = paste0(
      "Namespace a setting you keep for the session as ",
      "{.code options(<PackageName>.key = ...)}, or restore a temporary change ",
      "on exit, as in {.code oldpar <- par(no.readonly = TRUE); on.exit(par(oldpar))}"
    ),
    example = c(
      "# Before",
      "set_threshold <- function(x) {",
      "  options(threshold = x)",
      "}",
      "",
      "# After - option 1: a namespaced setting, kept for the session",
      "set_threshold <- function(x) {",
      "  options(mypkg.threshold = x)   # read with getOption('mypkg.threshold')",
      "}",
      "",
      "# After - option 2: a temporary change, restored on exit",
      "with_quiet <- function(expr) {",
      "  old <- options(warn = -1)",
      "  on.exit(options(old))",
      "  expr",
      "}"
    )
  ),
  home_writing = list(
    title = "Writes to the Home Directory",
    treatment = "Write to {.code tempdir()}, or to a path the caller supplies"
  ),
  temp_cleanup = list(
    title = "Temporary Files Left Behind",
    treatment = paste0(
      "Remove the file when done, with {.code on.exit(unlink(path))} or ",
      "{.code withr::local_tempfile()}"
    )
  ),
  globalenv_mod = list(
    title = "Writes to the Global Environment",
    treatment = paste0(
      "Bind the name in the package or an enclosing function, or keep state in ",
      "a cache environment the package creates with {.code new.env()}"
    )
  ),
  installed_packages = list(
    title = "installed.packages() Usage",
    treatment = paste0(
      "Use {.code requireNamespace()} or {.code find.package()} to ask about ",
      "one package instead"
    )
  ),
  warn_option = list(
    title = "Changes to options(warn)",
    treatment = paste0(
      "Use {.code suppressWarnings()} for a narrow scope, or restore the old ",
      "value with {.code on.exit()}"
    )
  ),
  software_install = list(
    title = "Package Installation From Package Code",
    treatment = paste0(
      "Remove the install. Declare what the package needs in DESCRIPTION and ",
      "tell users what to install"
    )
  ),
  core_usage = list(
    title = "Parallel Core Usage",
    treatment = paste0(
      "Use {.code parallelly::availableCores()}, which caps at 2 under ",
      "{.envvar _R_CHECK_LIMIT_CORES_}, or guard the count yourself"
    )
  ),
  library_in_pkg = list(
    title = "library() in Package Code",
    treatment = paste0(
      "Declare the dependency in DESCRIPTION Imports and call it as ",
      "{.code pkg::fn()}"
    )
  ),
  detect_cores_robustness = list(
    title = "Unguarded detectCores()",
    treatment = paste0(
      "Use {.code parallelly::availableCores()}, which never returns NA, or ",
      "guard the result of {.code detectCores()} against NA"
    )
  ),
  sys_setenv = list(
    title = "Unrestored Environment Variables",
    treatment = paste0(
      "Restore the variable with {.code on.exit(Sys.unsetenv(...))}, or set it ",
      "with {.code withr::local_envvar()}"
    )
  ),
  internal_ns = list(
    title = "::: in Package Code",
    treatment = paste0(
      "Use {.code ::} on an exported object, or ask the other author to export ",
      "what you need"
    )
  ),
  hardcoded_credentials = list(
    title = "Hardcoded Credentials",
    treatment = paste0(
      "Remove the secret, revoke it, and read it from an environment variable ",
      "at run time"
    )
  ),

  # ---- description ----
  description_file = list(
    title = "DESCRIPTION R Cannot Read",
    treatment = paste0(
      "Make {.file DESCRIPTION} a file R can open, with every line a ",
      "{.code Field: value} pair or a continuation indented by a space or tab, ",
      "and no blank line between fields"
    ),
    # The finding says where R stopped, which the worked example cannot know,
    # and why: the reflowed line is the fix for a malformed file only, so a
    # missing file or one R cannot open gets a fix of its own.
    example_fn = function(check) {
      found <- if (is.list(check)) check$issues else character(0)
      fix <- if (any(found == "DESCRIPTION file not found")) {
        c(
          "# Every package has a DESCRIPTION at its root; write one to fill in",
          "usethis::use_description()"
        )
      } else if (any(found == "DESCRIPTION is a directory, not a file")) {
        c(
          "# DESCRIPTION has to be a file: move the directory out of the way",
          "# and write the file in its place"
        )
      } else if (
        any(found == "DESCRIPTION cannot be read (permission denied)")
      ) {
        c(
          "# Give the file read permission",
          "Sys.chmod(\"DESCRIPTION\", \"644\")"
        )
      } else {
        c(
          "# Before: a reflowed paragraph lost the indent on its second line",
          "Description: Reads survey exports and tidies them. The paragraph was",
          "reflowed, and this line lost its leading space.",
          "",
          "# After: every continuation line starts with a space",
          "Description: Reads survey exports and tidies them. The paragraph was",
          "    reflowed, and this line keeps its leading space."
        )
      }
      c(
        paste("#", found),
        "",
        fix,
        "",
        "# Check the fix with the reader R CMD build uses",
        "read.dcf(\"DESCRIPTION\")"
      )
    }
  ),
  description_fields = list(
    title = "DESCRIPTION Fields R Does Not Know",
    treatment = paste0(
      "Fix a misspelt field name, and remove {.field Remotes} and any other ",
      "field R does not know, or move it under {.field Config/}"
    )
  ),
  description_placeholders = list(
    title = "Template Text Left in DESCRIPTION",
    treatment = paste0(
      "Replace the template text with the package's own Title, Description and ",
      "authors"
    )
  ),
  software_names = list(
    title = "Unquoted Software Names",
    treatment = paste0(
      "Put package and software names in single quotes in the Title and ",
      "Description, as in {.code 'ggplot2'}"
    )
  ),
  language_names = list(
    title = "Unquoted Programming-Language Names",
    treatment = paste0(
      "Put programming-language names in single quotes in the Title and ",
      "Description, as in {.code 'Python'}"
    )
  ),
  format_names = list(
    title = "Bare Format Names",
    treatment = paste0(
      "Optional. CRAN accepts these names bare; quote them only to keep the ",
      "quoting consistent throughout the Title and Description"
    )
  ),
  acronyms = list(
    title = "Unexplained Acronyms",
    treatment = paste0(
      "Spell each acronym out once, as in {.code principal component analysis ",
      "(PCA)}, or add it to {.field Config/checktor/acronyms}"
    )
  ),
  license = list(
    title = "License Field",
    treatment = paste0(
      "Use a standardizable license, and add {.code + file LICENSE} for MIT and ",
      "BSD, with the file present"
    )
  ),
  license_file_unneeded = list(
    title = "Unneeded LICENSE File Pointer",
    treatment = paste0(
      "Drop {.code + file LICENSE} and the file, since R ships the text of ",
      "standard licenses, unless LICENSE adds attribution requirements or other ",
      "restrictions"
    )
  ),
  title_case = list(
    title = "Title Case",
    treatment = "Use the capitalisation {.code tools::toTitleCase()} proposes"
  ),
  title_length = list(
    title = "Title Length",
    treatment = "Bring the Title down to 65 characters so none of it is cut off"
  ),
  title_package_name = list(
    title = "Title Repeats the Package Name",
    treatment = paste0(
      "Drop the package name from the Title, since listings show it already"
    )
  ),
  title_starts_with_article = list(
    title = "Title Starting With an Article",
    treatment = "Drop the leading 'A', 'An' or 'The'"
  ),
  title_redundant_phrases = list(
    title = "Redundant Phrases in Title",
    treatment = "Remove phrases such as 'for R', 'A Toolkit for' and 'Tools for'"
  ),
  description_function_quotes = list(
    title = "Single-Quoted Function Names",
    treatment = "Drop the single quotes around function names like 'fn()'"
  ),
  authors = list(
    title = "Authors@R Field",
    treatment = paste0(
      "Add {.field Authors@R}, replace any usethis template placeholder with ",
      "the real name and email, and give every person a name and role with one ",
      "maintainer (cre)"
    )
  ),
  identifier_format = list(
    title = "Author Identifiers",
    treatment = paste0(
      "Use a valid ORCID iD ({.code 0000-0000-0000-0000}) or ROR ID in the ",
      "person's comment"
    )
  ),
  cph_role = list(
    title = "No Copyright Holder",
    treatment = paste0(
      "If an organisation owns the copyright, give it role 'cph' or name it in ",
      "a {.field Copyright} field. Authors who are natural persons hold ",
      "copyright already"
    )
  ),
  references = list(
    title = "Reference Formatting",
    treatment = paste0(
      "Write links as {.code <https://...>}, DOIs as {.code <doi:prefix/suffix>} ",
      "and arXiv e-prints as {.code <doi:10.48550/arXiv.ID>}, each closed with ",
      "{.code >}"
    )
  ),
  date_format = list(
    title = "Date Field",
    treatment = paste0(
      "Use ISO 8601 {.code yyyy-mm-dd} and keep it current, or drop the ",
      "{.field Date} field"
    )
  ),
  encoding_utf8 = list(
    title = "Encoding Other Than UTF-8",
    treatment = "Re-encode sources as UTF-8 and set {.code Encoding: UTF-8}"
  ),
  version_format = list(
    title = "Version Field",
    treatment = "Use a numeric {.code x.y.z} version without leading zeroes"
  ),
  spelling = list(
    title = "Possibly Misspelled Words",
    treatment = paste0(
      "Record the correct terms in a {.file .aspell} dictionary, which ",
      "{.code R CMD check --as-cran} reads"
    ),
    example_fn = function(check) {
      words <- if (is.list(check)) check$issues else character(0)
      build_aspell_snippet(words)
    }
  ),
  description_length = list(
    title = "Short Description",
    treatment = "Say what the package does, in a sentence or two"
  ),
  description_starts_with = list(
    title = "Description Opening",
    treatment = paste0(
      "Start with a capital letter and say what the package does, not ",
      "'This package'"
    )
  ),
  description_quoted_quotes = list(
    title = "Double-Quoted Software Names",
    treatment = "Use single quotes for software and package names"
  ),
  license_year = list(
    title = "Unfilled LICENSE Template",
    treatment = "Replace the template placeholders with the real year and holder"
  ),

  # ---- documentation ----
  value_tags = list(
    title = "Missing \\value Tags",
    treatment = "Add {.code @return} tags to your roxygen documentation",
    example = c(
      "#' My Function",
      "#' @param x A parameter",
      "#' @return A character vector with results",
      "#' @export",
      "my_function <- function(x) paste('Result:', x)"
    )
  ),
  missing_examples = list(
    title = "Exported Functions Missing Examples",
    treatment = paste0(
      "Add a runnable {.code @examples} (side-effect-only functions may be ",
      "exempt)"
    )
  ),
  roxygen_usage = list(
    title = "Stale Generated Documentation",
    treatment = paste0(
      "Run {.code devtools::document()} to regenerate {.file man/} and ",
      "{.file NAMESPACE}"
    )
  ),
  example_structure = list(
    title = "Unneeded \\dontrun{} in Examples",
    treatment = paste0(
      "Let code that can run in a check run: drop the {.code \\dontrun{{}}}, ",
      "or use {.code \\donttest{{}}} for code that is only slow"
    )
  ),
  commented_examples = list(
    title = "Examples That Run Nothing",
    treatment = "Uncomment the demonstration, or remove the empty example"
  ),
  donttest_vs_dontrun = list(
    title = "\\dontrun{} Where \\donttest{} Belongs",
    treatment = "Slow-only code belongs in {.code \\donttest{{}}}"
  ),
  unexported_example_ns = list(
    title = "Examples Calling Unexported Functions",
    treatment = paste0(
      "Export the object, or keep the topic internal with {.code @noRd} and ",
      "drop the runnable example. Reaching for it with {.code :::} is what ",
      "CRAN asks you to remove."
    )
  ),
  suggested_in_examples = list(
    title = "Unguarded Suggested Packages in Examples",
    treatment = paste0(
      "Guard the use with ",
      "{.code if (requireNamespace(\"pkg\", quietly = TRUE))}, or with ",
      "{.code @examplesIf requireNamespace(\"pkg\", quietly = TRUE)}"
    )
  ),
  rd_bibliography = list(
    title = "Citations Missing From the Bibliography",
    treatment = paste0(
      "Add the entry to {.file inst/REFERENCES.bib} or {.file .R}, and list ",
      "what you cite with {.code \\bibshow{{*}}}"
    )
  ),
  rd_bibliography_files = list(
    title = "Bibliography R Cannot Read or Install",
    treatment = paste0(
      "Keep it as {.file inst/REFERENCES.bib} with {.pkg bibtex} in Suggests, ",
      "or as {.file inst/REFERENCES.R}"
    )
  ),
  example_interactive = list(
    title = "Interactive Examples in \\dontrun{} or \\donttest{}",
    treatment = paste0(
      "Guard the call with {.code if (interactive()) {{ ... }}}. CRAN asks for ",
      "that in place of {.code \\dontrun{{}}}, and ",
      "{.code R CMD check --as-cran} runs {.code \\donttest{{}}} code, where an ",
      "interactive call errors or waits for input"
    )
  ),
  example_installs = list(
    title = "Installs in Examples, Vignettes and Demos",
    treatment = paste0(
      "Assume the package is already available, or guard the example with ",
      "{.code if (requireNamespace(...))}"
    )
  ),
  example_writes = list(
    title = "Writes Outside the Temporary Directory in Examples",
    treatment = "Write to {.code tempfile()} or {.code tempdir()} in an example"
  ),
  example_state = list(
    title = "Session State Left Changed by Examples",
    treatment = paste0(
      "Capture and restore, as in {.code old <- options(digits = 3)} then ",
      "{.code options(old)}"
    )
  ),
  example_tf_usage = list(
    title = "T/F Usage in Examples",
    treatment = "Write {.code TRUE} and {.code FALSE} in full"
  ),
  example_unparseable = list(
    title = "Examples That Are Not Valid R",
    treatment = paste0(
      "Fix the syntax, or put a placeholder in a string, as in ",
      "{.code key <- \"<your key>\"}"
    )
  ),
  example_internal_ns = list(
    title = "::: in Examples",
    treatment = paste0(
      "Use {.code ::} on an exported object, or export the object the example ",
      "needs"
    )
  ),

  # ---- general ----
  package_size = list(
    title = "Package Size",
    treatment = paste0(
      "Reduce the package size, for instance by excluding files in ",
      "{.file .Rbuildignore}, or explain it in {.file cran-comments.md}"
    )
  ),
  urls = list(
    title = "URL Issues",
    treatment = "Switch to https://, and replace shorteners with the real target"
  ),
  url_liveness = list(
    title = "Broken and Redirecting URLs",
    treatment = paste0(
      "Fix or remove broken URLs, and point redirects at their final target"
    )
  ),
  news_file = list(
    title = "Missing NEWS File",
    treatment = paste0(
      "Add a {.file NEWS.md} documenting changes per version ",
      "({.code usethis::use_news_md()})"
    )
  ),
  cran_comments_file = list(
    title = "Missing cran-comments.md",
    treatment = paste0(
      "Add {.file cran-comments.md} with submission notes ",
      "({.code usethis::use_cran_comments()})"
    )
  ),
  readme_links = list(
    title = "Relative Links in the README",
    treatment = paste0(
      "Use full URLs, or make sure the target ships (not excluded by ",
      "{.file .Rbuildignore})"
    )
  ),
  code_exercised = list(
    title = "Package Nothing Exercises",
    treatment = paste0(
      "Add {.code @examples} to exported functions, tests ",
      "({.code usethis::use_testthat()}) or a vignette"
    )
  ),
  citation_file = list(
    title = "Old-Style or Unsafe inst/CITATION",
    treatment = paste0(
      "Use {.code bibentry()} and {.code c()} on {.code person()} objects, read ",
      "the DESCRIPTION through {.code meta}, and fix any syntax error so R can ",
      "read the file"
    )
  ),

  # ---- policy ----
  browser_calls = list(
    title = "Leftover browser() Calls",
    treatment = "Remove the {.code browser()} calls before submitting"
  ),
  system_calls = list(
    title = "System Calls",
    treatment = paste0(
      "Review each call for portability across platforms and for shell ",
      "injection, and prefer {.code system2()} with arguments passed separately"
    )
  ),
  file_operations = list(
    title = "Writes to the User's Filespace",
    treatment = paste0(
      "Write to {.code tempdir()}, or take the destination as an argument"
    )
  ),
  network_operations = list(
    title = "Unguarded Network Access",
    treatment = paste0(
      "Guard the request with {.code curl::has_internet()} or ",
      "{.code interactive()}, in an {.code if} or {.code @examplesIf}, or wrap ",
      "it in {.code \\donttest{{}}}, so it fails gracefully without a connection"
    )
  )
)

# The worked example for a failed check, built from the finding when the entry
# has an example_fn, or NULL when it has none.
treatment_example <- function(rx, check) {
  if (!is.null(rx$example_fn)) {
    rx$example_fn(check)
  } else {
    rx$example
  }
}

# A treatment's cli markup as Markdown: an inline class becomes a code span, or
# plain text for emphasis and package names, and a doubled brace a single one.
# The plain text and HTML reports use the same rendering, so the remedy reads
# the same in every format.
treatment_markdown <- function(x) {
  span <- "\\{\\.([a-z]+) ((?:[^{}]|\\{\\{|\\}\\})*)\\}"
  repeat {
    m <- regexpr(span, x, perl = TRUE)
    if (m == -1L) {
      break
    }
    starts <- attr(m, "capture.start")
    lens <- attr(m, "capture.length")
    cls <- substr(x, starts[1], starts[1] + lens[1] - 1L)
    body <- substr(x, starts[2], starts[2] + lens[2] - 1L)
    body <- gsub("}}", "}", gsub("{{", "{", body, fixed = TRUE), fixed = TRUE)
    rendered <- if (cls %in% c("strong", "emph", "pkg")) {
      body
    } else {
      paste0("`", body, "`")
    }
    x <- paste0(
      substr(x, 1L, m - 1L),
      rendered,
      substr(x, m + attr(m, "match.length"), nchar(x))
    )
  }
  x
}

# The same, as HTML: escaped, with each code span in <code>.
treatment_html <- function(x) {
  gsub("`([^`]*)`", "<code>\\1</code>", escape_html(treatment_markdown(x)))
}

# Build the .aspell/ setup snippet, pre-filled with the words a run flagged.
# inst/WORDLIST (the spelling package) does NOT clear CRAN's aspell NOTE; a
# .aspell/ dictionary does, so that is what we prescribe.
build_aspell_snippet <- function(words) {
  if (length(words) == 0L) {
    words <- "TechnicalTerm"
  }
  vec <- paste0(
    "c(",
    paste(sprintf('"%s"', words), collapse = ", "),
    ")"
  )
  c(
    "# In the package root, record the accepted spellings:",
    paste0("saveRDS(", vec, ', ".aspell/words.rds")'),
    "",
    "# .aspell/defaults.R (point aspell at that dictionary):",
    "Rd_files <- vignettes <- R_files <- description <-",
    '  list(encoding = "UTF-8", dictionaries = c("en_stats", "words"))'
  )
}

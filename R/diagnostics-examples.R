# Checks over the code CRAN reads outside R/: examples, vignettes and demos.
#
# Each rule here comes from a rejection letter rather than from a guess, and the
# CRAN Cookbook records every one of them.

#' Diagnose Installs in Examples, Vignettes and Demos
#'
#' Flags a call that installs a package or external software from an example, a
#' vignette or a demo. CRAN asks maintainers not to install anything from these,
#' because a check then has to do the install too, and the user did not ask for it.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Installing Software](https://contributor.r-project.org/cran-cookbook/code_issues.html#installing-software),
#' and it is a rejection maintainers receive verbatim: "Please do not install
#' packages in your functions, examples or vignette." See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_software_install()] for the same rule in `R/`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_example_installs(pkg, verbose = FALSE)$passed
lab_example_installs <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette", "demo"))
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Example installs check"))
  }

  installers <- c(
    "install.packages",
    "install_github",
    "install_gitlab",
    "install_bitbucket",
    "install_version",
    "install_local",
    "install_deps",
    "pak",
    "pkg_install",
    "biocLite"
  )
  predicate <- paste(
    sprintf("text() = '%s'", installers),
    collapse = " or "
  )
  issues <- example_lints(
    parsed,
    sprintf("//SYMBOL_FUNCTION_CALL[%s]", predicate),
    label = "installs software"
  )

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No installs in examples, vignettes or demos",
    "Installs found in examples, vignettes or demos",
    "Treatment: Assume the package is already available, or guard the example with {.code if (requireNamespace(...))}"
  )
  checktor_check_result(passed, issues, "Example installs check")
}

#' Diagnose Writes Outside the Temporary Directory in Examples
#'
#' Flags a write from an example, vignette or demo whose destination is a literal
#' path, so it lands in the user's filespace rather than in `tempdir()`. A
#' destination the caller supplies is permission and is not flagged.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Writing Files and Directories to the Home Filespace](https://contributor.r-project.org/cran-cookbook/code_issues.html#writing-files-and-directories-to-the-home-filespace),
#' and the rejection reads "Please ensure that your functions do not write by
#' default or in your examples/vignettes/tests in the user's home filespace". See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_file_operations()] for the same rule in `R/`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_example_writes(pkg, verbose = FALSE)$passed
lab_example_writes <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette", "demo"))
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Example writes check"))
  }

  predicate <- paste(
    sprintf("text() = '%s'", WRITE_FUNCTIONS),
    collapse = " or "
  )
  xpath <- sprintf("//SYMBOL_FUNCTION_CALL[%s]", predicate)

  # The same destination logic the R/ check uses, so a write is judged the same way
  # wherever it appears. Only a literal root can be proven to land in the user's
  # filespace, and anything built from tempfile() or tempdir() is the safe place.
  issues <- character(0)
  for (src in parsed) {
    nodes <- tryCatch(
      xml2::xml_find_all(src$xml, xpath),
      error = function(e) NULL
    )
    if (is.null(nodes) || length(nodes) == 0L) {
      next
    }
    keep <- vapply(
      nodes,
      function(n) dest_is_unsafe_literal(write_destination(n)),
      logical(1)
    )
    nodes <- nodes[keep]
    if (length(nodes) == 0L) {
      next
    }
    issues <- c(
      issues,
      paste0(
        src$kind,
        " ",
        basename(src$file),
        ":",
        xml2::xml_attr(nodes, "line1"),
        " (",
        xml2::xml_text(nodes),
        "())"
      )
    )
  }
  issues <- unique(issues)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Examples write only to {.code tempdir()} or a caller-supplied path",
    "Examples write to a literal path outside {.code tempdir()}",
    "Treatment: Write to {.code tempfile()} or {.code tempdir()} in an example"
  )
  checktor_check_result(passed, issues, "Example writes check")
}

#' Diagnose Examples That Are Not Valid R
#'
#' Flags an `\examples{}` section whose code does not parse as R, reporting the
#' `.Rd` file and the line the parser stopped on. The code inside `\dontrun{}` is
#' read too. `R CMD check` writes it out as comments and never parses it, so a
#' missing bracket or a `<your key>` placeholder there passes every check.
#'
#' @section Source:
#' A rejection CRAN reviewers send verbatim: "Warning: Unexecutable code in
#' man/make.trait.model.Rd". [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Documenting-functions),
#' under "Documenting functions", says example code outside `\dontrun{}` "must be
#' executable", and that the text inside it "need not be valid R code". Reviewers
#' run the examples with `\dontrun{}` included all the same, so a placeholder
#' belongs in a string or a variable, as in `key <- "<your key>"`. An example that
#' is deliberately not R, such as C++ source shown for reading, can be turned off
#' with `Config/checktor/disable`. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_example_structure()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario(
#'   "documentation_examples/example_unparseable_bad.Rd", show_content = FALSE)
#' issues(lab_example_unparseable(pkg, verbose = FALSE))
lab_example_unparseable <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  issues <- character(0)
  for (file in list_rd_files(path)) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    section <- if (!is.null(rd)) extract_rd_section(rd, "\\examples")
    if (is.null(section)) {
      next
    }
    src <- rd_example_source(section)
    err <- tryCatch(
      {
        parse(text = src$code, keep.source = FALSE)
        NULL
      },
      error = conditionMessage
    )
    if (is.null(err)) {
      next
    }
    issues <- c(issues, unparseable_issue(err, src, basename(file)))
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Every example parses as R",
    "Examples that do not parse as R, {.code \\dontrun{{}}} included",
    "Treatment: Fix the syntax, or put a placeholder in a string, as in {.code key <- \"<your key>\"}"
  )
  checktor_check_result(passed, issues, "Example parse check")
}

# "example f.Rd:12 (unexpected symbol)" from a parse error in code that
# rd_example_source() gave. The parser gives `<text>:line:col: message` and then
# the offending lines; the position is on the code's lines, which `src$lines`
# maps to the .Rd file's. An unfinished example ends past its last line of
# code, so the line is held to the last one with code on it.
unparseable_issue <- function(err, src, file) {
  first <- strsplit(err, "\n", fixed = TRUE)[[1L]][[1L]]
  at <- suppressWarnings(
    as.integer(sub("^<text>:([0-9]+):[0-9]+: .*$", "\\1", first))
  )
  what <- sub("^<text>:[0-9]+:[0-9]+: ", "", first)
  if (is.na(at)) {
    return(paste0("example ", file, " (", what, ")"))
  }
  code <- strsplit(src$code, "\n", fixed = TRUE)[[1L]]
  last <- max(c(1L, which(nzchar(trimws(code)))))
  line <- src$lines[min(at, last, length(src$lines))]
  paste0("example ", file, ":", line, " (", what, ")")
}

#' Diagnose `T`/`F` Usage in Examples, Vignettes and Demos
#'
#' Flags a bare `T` or `F` in an example, a vignette chunk that runs, or a demo,
#' judged exactly as [lab_tf_usage()] judges `R/`: a `T` in a string, a comment,
#' an argument name, `x$T` or language built by `quote()` is not reported.
#'
#' @section Source:
#' The CRAN Cookbook recipe
#' [T/F Instead of TRUE/FALSE](https://contributor.r-project.org/cran-cookbook/code_issues.html#tf-instead-of-truefalse)
#' says `T` and `F` "should not be used as variable names in your code, examples,
#' tests or vignettes", and the reviewer's letter names the `.Rd` file: "'T' and
#' 'F' instead of TRUE and FALSE: man/quiet.Rd: quiet(x, be_quiet = T)". No rule
#' makes it binding, so it sits at `robustness` tier like [lab_tf_usage()]. Tests
#' are left out unless `tests = TRUE`, since CRAN rarely reads them. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param tests Logical. Read `tests/` as well. Default: `FALSE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_tf_usage()] for the same rule in `R/`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/example_tf_usage_bad.Rd",
#'                                  show_content = FALSE)
#' issues(lab_example_tf_usage(pkg, verbose = FALSE))
lab_example_tf_usage <- function(path = ".", verbose = TRUE, tests = FALSE) {
  path <- find_package_root(path)
  kinds <- c("example", "vignette", "demo", if (isTRUE(tests)) "test")
  parsed <- read_example_xml(path, kinds = kinds)
  issues <- example_lints(parsed, TF_XPATH)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No {.code T}/{.code F} usage in examples, vignettes or demos",
    "Found {.code T}/{.code F} usage in examples, vignettes or demos",
    "Treatment: Write {.code TRUE} and {.code FALSE} in full"
  )
  checktor_check_result(passed, issues, "Example T/F usage check")
}

#' Diagnose Session State Left Changed by Examples
#'
#' Flags an example, vignette or demo that changes `options()`, `par()` or the
#' working directory without putting it back. A reader who runs the example is left
#' with a session that behaves differently afterwards.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Change of Options, Graphical Parameters and Working Directory](https://contributor.r-project.org/cran-cookbook/code_issues.html#change-of-options-graphical-parameters-and-working-directory),
#' and the rejection reads "Please always make sure to reset to user's options(),
#' working directory or par() after you changed it in examples and vignettes and
#' demos." See `vignette("check-sources", package = "checktor")` for how every check
#' maps to its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_option_changes()] for the same rule in `R/`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_example_state(pkg, verbose = FALSE)$passed
lab_example_state <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette", "demo"))
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Example state check"))
  }

  issues <- character(0)
  for (src in parsed) {
    # A named argument is what makes options() or par() a write rather than a
    # read. par()'s no.readonly is the exception: it asks for the settings and
    # changes none of them.
    setters <- xml2::xml_find_all(
      src$xml,
      paste0(
        "//SYMBOL_FUNCTION_CALL[text() = 'options']",
        "/parent::expr/parent::expr[SYMBOL_SUB]",
        " | //SYMBOL_FUNCTION_CALL[text() = 'par']",
        "/parent::expr/parent::expr[SYMBOL_SUB[text() != 'no.readonly']]",
        " | //SYMBOL_FUNCTION_CALL[text() = 'setwd']/parent::expr/parent::expr"
      )
    )
    if (length(setters) == 0L) {
      next
    }
    # Each kind of state is judged on its own: par() put back leaves a changed
    # working directory changed.
    kinds <- STATE_RESTORE_KIND[xml2::xml_text(
      xml2::xml_find_first(setters, "./expr[1]/SYMBOL_FUNCTION_CALL")
    )]
    setters <- setters[!kinds %in% state_restored(src$xml)]
    if (length(setters) == 0L) {
      next
    }
    lines <- xml2::xml_attr(setters, "line1")
    issues <- c(
      issues,
      paste0(src$kind, " ", basename(src$file), ":", lines, " (never restored)")
    )
  }
  issues <- unique(issues)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Examples restore any session state they change",
    "Examples change session state without restoring it",
    "Treatment: Capture and restore, as in {.code old <- options(digits = 3)} then {.code options(old)}"
  )
  checktor_check_result(passed, issues, "Example state check")
}

# The kinds of state an example can change, by the calls that read or replace
# them. A value captured from one kind is put back only by that kind's setter:
# an old directory handed to options() restores nothing.
STATE_CAPTURE_KIND <- c(
  options = "options",
  getOption = "options",
  par = "par",
  setwd = "wd",
  getwd = "wd"
)
STATE_RESTORE_KIND <- c(options = "options", par = "par", setwd = "wd")

# Calls that return the value they wrap, so `suppressWarnings(par(...))` still
# holds what par() returned.
STATE_VALUE_WRAPPERS <- c("suppressWarnings", "suppressMessages", "invisible")

# Which kinds of state does this example, vignette or demo put back? The old value
# has to be captured and then handed back, which is what the reviewer asks for,
# and a restore anywhere later in the same file counts.
#
# A capture is an assignment whose value IS the call that reads or replaces the
# state, or one setting taken out of it: `old <- options(digits = 3)`, `op <-
# par(no.readonly = TRUE)`, `owd = getwd()`, `old <- par()[["mfrow"]]`, `old <-
# getOption("digits")`, or `old <- setwd(tempdir())`, since setwd() returns the
# directory it leaves as options() and par() return the values they replace. The
# call may be wrapped in suppressWarnings() or invisible(), or be the right-hand
# side of a pipe, as in `old <- tempdir() |> setwd()`. A function that calls
# setwd(), or a tryCatch() around it, holds no old state.
#
# The restore is that captured name handed back to the setter of the same kind,
# by position or by name, through do.call(), or down a pipe. Inside on.exit() it
# counts only when the on.exit() belongs to a function or local(): at top level
# there is nothing to exit, so R CMD check never runs it, and knitr runs it right
# after its own line, before the change it was meant to undo. A capture never
# handed back keeps the way home and never takes it, which is the shape CRAN
# sends back.
state_restored <- function(xml) {
  targets <- xml2::xml_find_all(
    xml,
    paste0(
      "//", ASSIGN_NODE, "[LEFT_ASSIGN or EQ_ASSIGN]/expr[1][count(*) = 1]/SYMBOL",
      " | //", ASSIGN_NODE, "[RIGHT_ASSIGN]/expr[2][count(*) = 1]/SYMBOL"
    )
  )
  top_level_exit <- paste0(
    "ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[text() = 'on.exit']]",
    "[not(ancestor::expr[FUNCTION or OP-LAMBDA or ",
    "expr[1]/SYMBOL_FUNCTION_CALL[text() = 'local']])]"
  )
  restored <- character(0)
  for (target in targets) {
    assignment <- xml2::xml_find_first(target, "parent::expr/parent::*")
    right <- xml2::xml_find_lgl(assignment, "boolean(RIGHT_ASSIGN)")
    value <- xml2::xml_find_first(assignment, if (right) "expr[1]" else "expr[2]")
    kind <- captured_state(value)
    if (is.na(kind) || kind %in% restored) {
      next
    }
    setter <- names(STATE_RESTORE_KIND)[STATE_RESTORE_KIND == kind]
    calls <- sprintf("following::SYMBOL_FUNCTION_CALL[text() = '%s']", setter)
    do_calls <- sprintf(
      paste0(
        "following::SYMBOL_FUNCTION_CALL[text() = 'do.call']/parent::expr",
        "/parent::expr[expr[2][SYMBOL[text() = '%1$s']",
        " or STR_CONST[text() = '\"%1$s\"' or text() = \"'%1$s'\"]]]"
      ),
      setter
    )
    pipes <- sprintf(
      paste0(
        "following::expr[PIPE or SPECIAL[%s]]",
        "[expr[2]/expr[1]/SYMBOL_FUNCTION_CALL[text() = '%s']]"
      ),
      paste(sprintf("text() = '%s'", MAGRITTR_PIPES), collapse = " or "),
      setter
    )
    handed_back <- xml2::xml_find_all(
      assignment,
      paste0(
        calls, "/parent::expr/parent::expr[not(", top_level_exit, ")]",
        "/expr[position() > 1][count(*) = 1]/SYMBOL",
        " | ", do_calls, "[not(", top_level_exit, ")]/expr[3][count(*) = 1]/SYMBOL",
        " | ", pipes, "[not(", top_level_exit, ")]/expr[1][count(*) = 1]/SYMBOL"
      )
    )
    if (xml2::xml_text(target) %in% xml2::xml_text(handed_back)) {
      restored <- c(restored, kind)
    }
  }
  restored
}

# The kind of state an assigned value holds, or NA. It holds one when it is a
# call that reads or replaces the state, one setting taken out of such a call,
# that call inside a wrapper that returns it, or that call on the right of a pipe
# that returns its result. `%T>%` returns its left-hand side, so it is not one.
captured_state <- function(node, depth = 0L) {
  if (inherits(node, "xml_missing") || depth > 5L) {
    return(NA_character_)
  }
  rhs <- xml2::xml_find_first(
    node,
    paste0(
      "./expr[preceding-sibling::*[1][self::PIPE",
      " or self::SPECIAL[text() = '%>%' or text() = '%!>%']]]"
    )
  )
  if (!inherits(rhs, "xml_missing")) {
    fn <- xml2::xml_text(xml2::xml_find_first(rhs, "./expr[1]/SYMBOL_FUNCTION_CALL"))
    if (fn %in% STATE_VALUE_WRAPPERS) {
      return(captured_state(xml2::xml_find_first(node, "./expr[1]"), depth + 1L))
    }
    return(unname(STATE_CAPTURE_KIND[fn]))
  }
  fn <- xml2::xml_text(xml2::xml_find_first(node, "./expr[1]/SYMBOL_FUNCTION_CALL"))
  if (!is.na(fn)) {
    if (fn %in% STATE_VALUE_WRAPPERS) {
      return(captured_state(xml2::xml_find_first(node, "./expr[2]"), depth + 1L))
    }
    return(unname(STATE_CAPTURE_KIND[fn]))
  }
  if (xml2::xml_find_lgl(node, "boolean(LBB or OP-LEFT-BRACKET or OP-DOLLAR)")) {
    return(captured_state(xml2::xml_find_first(node, "./expr[1]"), depth + 1L))
  }
  NA_character_
}

# Functions that need a person at the keyboard: an app or gadget that blocks until
# it is closed, a viewer, a browser, or a prompt waiting for input.
INTERACTIVE_CALLS <- c(
  "runApp", "shinyApp", "shinyAppDir", "shinyAppFile", "runGadget", "runExample",
  "runUrl", "runGitHub", "runGist", "browseURL", "browseVignettes", "View",
  "readline", "menu", "select.list", "askYesNo", "file.choose", "choose.files",
  "choose.dir", "file.edit"
)

# These build an app object, which runs only when it is printed. Kept in a
# variable or handed to another function, nothing starts.
INTERACTIVE_WHEN_PRINTED <- c("shinyApp", "shinyAppDir", "shinyAppFile")

# Launchers named for what they open, such as run_app(), launch_dashboard(),
# runShinyApp(), launch_shinystan() and launchGUI(). Every app package names its
# own, so this matches the shape of the name rather than a list of them.
INTERACTIVE_LAUNCHER_RE <- paste0(
  "^(run|launch)[A-Za-z0-9_.]*",
  "([Aa]pp|[Gg]adget|[Dd]ashboard|GUI|[Gg]ui|[Ss]hiny[A-Za-z0-9]*)$"
)

# The marker call each hidden block is wrapped in, so the parse tree records which
# block a call sits in.
HIDDEN_EXAMPLE_MARKERS <- c(
  "\\dontrun" = ".checktor_dontrun",
  "\\donttest" = ".checktor_donttest"
)

# The blocks whose body rd_example_marked(mark = FALSE) puts on lines of its
# own, as Rd2ex lays out a block whose code runs. Rd2ex ends the line the block
# opens on with a label such as `## No test: ` or `## IGNORE_RDIFF_BEGIN`,
# starts the body on the next line, and closes it with a label line such as
# `## End(No test)`, so the code after the closing brace starts a line too. A
# \dontrun{} is the exception. Under R CMD check's default commentDontrun = TRUE
# its body is commented out, and one of a single child is written in place
# after its `## Not run: ` label, taking the rest of the line into the comment.
# With commentDontrun = FALSE it has no label, and its body is on lines of its
# own like the others. checktor reads \dontrun{} code all the same, laid out
# that way: a reader copies it, and CRAN asks about installs and writes
# wherever they appear.
RD_EXAMPLE_BLOCKS <- c(
  "\\dontrun", "\\donttest", "\\dontshow", "\\testonly", "\\dontdiff"
)

# A line break rd_example_marked() adds, told apart from the example's own so
# rd_example_lines() can put each line of code back on its line of the .Rd file.
ADDED_BREAK <- "\001"

# An example as R code, with each \dontrun{} and \donttest{} body wrapped in its
# marker call. Rd `%` comments are dropped, as R drops them. The newline before
# `})` keeps a comment on the body's last line from swallowing the close.
#
# A hidden block may hold something that is not R -- output, JavaScript, a
# `<your key>` placeholder -- which stops the whole example parsing. With
# `repair = TRUE` each block keeps only the code in it that parses, so the rest of
# the example, and any guard around the block, can still be read.
#
# With `mark = FALSE` a block is left as its body, for the checks that ask what
# an example calls rather than which block the call sits in. The body of each
# of RD_EXAMPLE_BLOCKS goes between two added line breaks, as Rd2ex lays out a
# block it runs, so that `\dontrun{f()}\donttest{g()}` reads as two calls rather
# than `f()g()`, while `suppressWarnings(\donttest{f()})` is still one, since R
# reads on past a line break inside parentheses. Those breaks are ADDED_BREAK:
# rd_example_lines() makes the ones that part code newlines, drops the rest,
# and maps each line back to its line of the .Rd file.
#
# An `#ifdef` or `#ifndef` holds code for one platform, and CRAN checks on both,
# so its body is read either way. Its first child is the condition, a platform
# name that is not R. parse_Rd() folds the `#endif` line into the node as well,
# so each directive line becomes a blank one.
rd_example_marked <- function(node, repair = FALSE, mark = TRUE) {
  tag <- attr(node, "Rd_tag")
  if (identical(tag, "COMMENT")) {
    return("")
  }
  if (is.character(node)) {
    return(paste(node, collapse = ""))
  }
  if (!is.list(node)) {
    return("")
  }
  if (!is.null(tag) && tag %in% c("#ifdef", "#ifndef") && length(node) == 2L) {
    condition <- gsub("[^\n]", "", rd_example_marked(node[[1L]]))
    body <- rd_example_marked(node[[2L]], repair = repair, mark = mark)
    return(paste0(condition, body, "\n"))
  }
  body <- paste(
    vapply(
      node,
      rd_example_marked,
      character(1),
      repair = repair,
      mark = mark,
      USE.NAMES = FALSE
    ),
    collapse = ""
  )
  hidden <- !is.null(tag) && tag %in% names(HIDDEN_EXAMPLE_MARKERS)
  if (hidden && repair) {
    body <- parseable_text(body)
  }
  if (!mark && !is.null(tag) && tag %in% RD_EXAMPLE_BLOCKS) {
    return(paste0(ADDED_BREAK, body, ADDED_BREAK))
  }
  if (hidden) {
    return(paste0(HIDDEN_EXAMPLE_MARKERS[[tag]], "({", body, "\n})"))
  }
  body
}

# Code from rd_example_marked(mark = FALSE) with its added breaks made newlines,
# and the line of the source each line of that code comes from, counting only
# the source's own newlines. A break is kept only where it parts code from
# code: besides the ones drop_idle_breaks() drops, one at the start of a line
# would add nothing but a blank line.
rd_example_lines <- function(text) {
  b <- ADDED_BREAK
  text <- drop_idle_breaks(text)
  text <- gsub(paste0("(^|\n)([ \t]*)", b), "\\1\\2", text, perl = TRUE)
  breaks <- regmatches(text, gregexpr(paste0("[\n", b, "]"), text))[[1L]]
  list(
    code = gsub(b, "\n", text, fixed = TRUE),
    lines = 1L + c(0L, cumsum(breaks == "\n"))
  )
}

# `text` without the ADDED_BREAKs that part no code from code: those in front
# of a line break, another added break, a comment or the end, which would add
# nothing but a blank line, and those in front of whatever continues the line R
# reads: `;`, `else`, or a binary operator no line can start with, such as
# `|>`, `%>%`, `->`, `*` or `==`. A line of R cannot start with those, and at
# the top level R reads a line that starts with `else` as a new statement, so
# with the break the example did not parse. `\dontrun{f()}; g()` is read as
# `f(); g()`, and `\dontrun{f()} |> g()` as `f() |> g()`, on the line each is
# written on. `+`, `-`, `!`, `~` and `?` can start a line, so a break in front
# of them stays.
drop_idle_breaks <- function(text) {
  b <- ADDED_BREAK
  continues <- "\\|>|%[^%\n]*%|->|[*/^&|$@:=<>,)\\]]"
  gsub(
    paste0(b, "(?=[ \t]*(?:\n|", b, "|#|;|else\\b|", continues, "|$))"),
    "",
    text,
    perl = TRUE
  )
}

# The parts of `text` that parse, for code that will not parse whole, with every
# other line blanked so each part stays on its own line. A chunk grows a line at a
# time while the parser says more input could complete it, and a line nothing can
# complete is blanked. The parser's message is translated, so this reads only the
# `<text>:line:col:` position in front of it, and the INCOMPLETE_STRING token
# name, which are not.
#
# An ADDED_BREAK from a block nested in this one parts lines as a newline does,
# and is put back as it was, so `suppressWarnings(\dontrun{f()})` parses over
# three lines when one of them alone would not. The breaks rd_example_lines()
# would drop are dropped first, so `\dontrun{f()}; g()` is still one line.
parseable_text <- function(text) {
  text <- drop_idle_breaks(text)
  line_break <- paste0("[\n", ADDED_BREAK, "]")
  breaks <- regmatches(text, gregexpr(line_break, text))[[1L]]
  # strsplit() drops a trailing empty line, and that line is where whatever
  # follows the block begins.
  lines <- strsplit(paste0(text, "\n"), line_break)[[1L]]
  keep <- logical(length(lines))
  start <- 1L
  while (start <= length(lines)) {
    end <- start
    kept <- FALSE
    repeat {
      chunk <- paste(lines[start:end], collapse = "\n")
      err <- tryCatch(
        {
          parse(text = chunk, keep.source = FALSE)
          NULL
        },
        error = conditionMessage
      )
      if (is.null(err)) {
        keep[start:end] <- TRUE
        start <- end + 1L
        kept <- TRUE
        break
      }
      at_line <- suppressWarnings(
        as.integer(sub("^<text>:([0-9]+):.*", "\\1", err))
      )
      incomplete <- isTRUE(at_line > end - start + 1L) ||
        grepl("INCOMPLETE_STRING", err, fixed = TRUE)
      if (!incomplete || end >= length(lines)) {
        break
      }
      end <- end + 1L
    }
    if (!kept) {
      start <- start + 1L
    }
  }
  lines[!keep] <- ""
  paste(paste0(lines, c(breaks, "")), collapse = "")
}

# The outermost \dontrun{} and \donttest{} blocks.
rd_hidden_blocks <- function(node) {
  tag <- attr(node, "Rd_tag")
  if (!is.null(tag) && tag %in% names(HIDDEN_EXAMPLE_MARKERS)) {
    return(list(node))
  }
  if (is.list(node)) {
    return(unlist(lapply(node, rd_hidden_blocks), recursive = FALSE))
  }
  list()
}

# The children of a node other than its comments. A comment is a node of its own
# in the parse tree, so `a && # why\n b` has four children, not three, and a
# reader that counts them must leave it out.
code_children <- function(node) {
  kids <- xml2::xml_children(node)
  kids[xml2::xml_name(kids) != "COMMENT"]
}

# The parts of a call to a named function: its name, its argument expressions,
# those of them passed by position, and the name each argument is passed by, ""
# for one passed by position. NULL when `node` is not such a call. A method call
# such as `session$interactive()` names no function.
call_parts <- function(node) {
  kids <- code_children(node)
  tags <- xml2::xml_name(kids)
  if (length(tags) < 3L || tags[[1L]] != "expr" || tags[[2L]] != "OP-LEFT-PAREN") {
    return(NULL)
  }
  fn <- xml2::xml_find_first(
    kids[[1L]],
    paste0("SYMBOL_FUNCTION_CALL[", NOT_MEMBER_ACCESS, "]")
  )
  if (inherits(fn, "xml_missing")) {
    return(NULL)
  }
  is_arg <- tags == "expr" & seq_along(tags) > 1L
  named <- c(FALSE, tags[-length(tags)] == "EQ_SUB")
  arg_names <- character(length(tags))
  arg_names[named] <- unquote_name(xml2::xml_text(kids[which(named) - 2L]))
  list(
    fn = xml2::xml_text(fn),
    args = kids[is_arg],
    positional = kids[is_arg & !named],
    arg_names = arg_names[is_arg]
  )
}

# The argument a call passes for each of `formals`, matched as R matches them: by
# name first, then by position into the formals still open. Named after
# `formals`, with NULL for one the call leaves out. So `Sys.getenv(unset = "",
# "NOT_CRAN")` passes "NOT_CRAN" as `x`.
matched_args <- function(parts, formals) {
  out <- stats::setNames(vector("list", length(formals)), formals)
  by_name <- parts$arg_names %in% formals
  for (i in which(by_name)) {
    out[[parts$arg_names[[i]]]] <- parts$args[[i]]
  }
  open <- setdiff(formals, parts$arg_names[by_name])
  by_position <- parts$args[parts$arg_names == ""]
  for (i in seq_len(min(length(open), length(by_position)))) {
    out[[open[[i]]]] <- by_position[[i]]
  }
  out
}

# The string literals among a call's arguments, unquoted, so a guard can be asked
# what it names: "libcurl" in `capabilities("libcurl")`, or both packages in
# `rlang::is_installed(c("dplyr", "tidyr"))`.
arg_strings <- function(args) {
  if (length(args) == 0L) {
    return(character(0))
  }
  unquote_name(xml2::xml_text(xml2::xml_find_all(args, "descendant-or-self::STR_CONST")))
}

# A literal FALSE. The branch it guards never runs, so nothing in it can fail,
# which is how roxygen's `@examplesIf FALSE` keeps an example off the checks.
is_false_constant <- function(node) {
  kids <- xml2::xml_children(node)
  length(kids) == 1L &&
    xml2::xml_name(kids) == "NUM_CONST" &&
    xml2::xml_text(kids) == "FALSE"
}

# Calls that hand back the value of their first argument, so a guard inside one is
# still the guard: `if (suppressWarnings(requireNamespace("x")))`. Each is named
# with its formals, so the argument can be found when it is passed by name.
TRANSPARENT_GUARD_WRAPPERS <- list(
  suppressWarnings = c("expr", "classes"),
  suppressMessages = c("expr", "classes"),
  suppressPackageStartupMessages = "expr",
  invisible = "x"
)

# What an `if` condition says about a guard: TRUE when the condition can be true
# only while the guard holds, FALSE when it can be false only while the guard
# holds, NA when it says neither. `holds(term)` judges one term, such as
# `interactive()` or `curl::has_internet()`; `!`, `&&`, `||`, parentheses,
# `isTRUE()`, `isFALSE()` and the wrappers that return their argument, such as
# `suppressWarnings()`, are read here, so every kind of guard combines the same
# way, and comments between the parts are skipped. `a && b` is true only when both
# sides are, so a guard on either side holds for it, but it is false when either
# side is, so its else branch is guarded only when both sides are negated guards;
# `a || b` is the mirror image. A braced
# condition, which roxygen writes for a multi-line `@examplesIf`, has the value of
# its last expression, and a variable has the value last assigned to it. Anything
# else, such as `CI == "" || interactive()`, which holds under R CMD check, is no
# guard.
guard_polarity <- function(node, holds) {
  kids <- code_children(node)
  tags <- xml2::xml_name(kids)
  if (identical(tags, c("OP-LEFT-PAREN", "expr", "OP-RIGHT-PAREN"))) {
    return(guard_polarity(kids[[2L]], holds))
  }
  if (identical(tags, c("OP-EXCLAMATION", "expr"))) {
    return(!guard_polarity(kids[[2L]], holds))
  }
  if (identical(tags, "SYMBOL")) {
    value <- assigned_value(node)
    return(if (is.null(value)) NA else guard_polarity(value, holds))
  }
  if (length(tags) >= 2L && tags[[1L]] == "OP-LEFT-BRACE") {
    body <- kids[tags %in% c("expr", "expr_or_assign_or_help", "equal_assign")]
    if (length(body) == 0L) {
      return(NA)
    }
    return(guard_polarity(body[[length(body)]], holds))
  }
  if (length(tags) == 3L && tags[[2L]] %in% c("AND2", "AND", "OR2", "OR")) {
    sides <- c(
      guard_polarity(kids[[1L]], holds),
      guard_polarity(kids[[3L]], holds)
    )
    both <- tags[[2L]] %in% c("AND2", "AND")
    if (if (both) any(sides %in% TRUE) else all(sides %in% TRUE)) {
      return(TRUE)
    }
    if (if (both) all(sides %in% FALSE) else any(sides %in% FALSE)) {
      return(FALSE)
    }
    return(NA)
  }
  parts <- call_parts(node)
  if (
    !is.null(parts) &&
      parts$fn %in% c("isTRUE", "isFALSE") &&
      length(parts$args) == 1L
  ) {
    # Some terms are a guard only whole: in
    # `isTRUE(as.logical(Sys.getenv("NOT_CRAN")))` the argument alone is NA
    # under R CMD check.
    if (isTRUE(holds(node))) {
      return(TRUE)
    }
    polarity <- guard_polarity(parts$args[[1L]], holds)
    return(if (parts$fn == "isTRUE") polarity else !polarity)
  }
  if (!is.null(parts) && parts$fn %in% names(TRANSPARENT_GUARD_WRAPPERS)) {
    wrapped <- matched_args(parts, TRANSPARENT_GUARD_WRAPPERS[[parts$fn]])[[1L]]
    return(if (is.null(wrapped)) NA else guard_polarity(wrapped, holds))
  }
  if (isTRUE(holds(node))) TRUE else NA
}

# The nodes that open a scope of their own: a function body, whose assignments stay
# inside it, and local(), which evaluates its code in a new environment.
SCOPE_XPATH <- paste0(
  "ancestor::expr[FUNCTION or OP-LAMBDA or ",
  "expr[1]/SYMBOL_FUNCTION_CALL[text() = 'local']][1]"
)

# The value a bare symbol holds where it is read, when an assignment before it
# says so, or NULL. lax asks `got_evd <- requireNamespace("evd", quietly = TRUE)`
# once and then tests `if (got_evd)`, and only the assignment says that is a guard.
#
# Only an assignment in the same scope counts: one inside another function body
# sets a variable of that function, which the read never sees, and one outside the
# function the read is in may be changed before the function is called. And only
# one that always runs before the read: when the last assignment sits in an `if`
# branch or a loop body that the read is not in, the variable may still hold what
# it held before, so nothing is known. An `if` or `while` condition and a `for`
# sequence run whenever the statement does, so an assignment there, as in
# `if (!(ok <- requireNamespace("x"))) ...`, always runs. An assignment always
# precedes the symbol it feeds, so `ok <- ok && f()` reads the assignment before
# it and the lookup cannot loop.
assigned_value <- function(node) {
  name <- xml2::xml_text(xml2::xml_find_first(node, "SYMBOL"))
  if (grepl("'", name, fixed = TRUE)) {
    return(NULL)
  }
  assignments <- xml2::xml_find_all(
    node,
    paste0(
      "preceding::", ASSIGN_NODE, "[LEFT_ASSIGN or EQ_ASSIGN]",
      "[*[1]/SYMBOL[text() = '", name, "']]"
    )
  )
  scope <- xml2::xml_find_first(node, SCOPE_XPATH)
  same_scope <- vapply(
    assignments,
    function(a) identical(xml2::xml_find_first(a, SCOPE_XPATH), scope),
    logical(1)
  )
  assignments <- assignments[same_scope]
  if (length(assignments) == 0L) {
    return(NULL)
  }
  last <- assignments[[length(assignments)]]
  # Each branch or loop body the assignment sits in must hold the read too. A
  # branch or body follows the closing parenthesis of its condition, the `for`
  # sequence, or `repeat`.
  part <- paste0(
    "ancestor-or-self::*[parent::expr[IF or FOR or WHILE or REPEAT]]",
    "[preceding-sibling::OP-RIGHT-PAREN or preceding-sibling::forcond or ",
    "preceding-sibling::REPEAT]"
  )
  around_read <- xml2::xml_find_all(node, part)
  for (branch in xml2::xml_find_all(last, part)) {
    if (!any(vapply(around_read, identical, logical(1), branch))) {
      return(NULL)
    }
  }
  xml2::xml_find_first(last, "*[not(self::COMMENT)][3]")
}

# Whether a call runs only while a guard holds: it sits in the branch of an `if`
# that the condition confines to it -- the then branch of `if (interactive())`, or
# the else branch of `if (!interactive())`. Reading every enclosing `if` is what
# lets roxygen's `@examplesIf` guard a whole example, and what stops a guard around
# one call excusing another. `a && b` evaluates `b` only when `a` is true, and
# `a || b` only when `a` is false, so `requireNamespace("x") && x::f()` guards the
# call as surely as an `if` does.
guarded_by <- function(call, holds) {
  branches <- xml2::xml_find_all(call, "ancestor::*[parent::expr[IF]]")
  for (branch in branches) {
    position <- xml2::xml_find_num(
      branch,
      paste0("count(preceding-sibling::", ASSIGN_NODE, ")")
    )
    if (position == 0) {
      next # the call is in the condition itself
    }
    condition <- xml2::xml_find_first(branch, paste0("parent::expr/", ASSIGN_NODE, "[1]"))
    polarity <- guard_polarity(condition, holds)
    if ((position == 1 && isTRUE(polarity)) || (position == 2 && isFALSE(polarity))) {
      return(TRUE)
    }
  }
  operator <- "preceding-sibling::*[not(self::COMMENT)][1]"
  operands <- xml2::xml_find_all(
    call,
    paste0("ancestor::*[", operator, "[self::AND2 or self::OR2]]")
  )
  for (operand in operands) {
    op <- xml2::xml_name(xml2::xml_find_first(operand, operator))
    left <- xml2::xml_find_first(
      operand,
      "preceding-sibling::*[not(self::COMMENT)][2]"
    )
    polarity <- guard_polarity(left, holds)
    if ((op == "AND2" && isTRUE(polarity)) || (op == "OR2" && isFALSE(polarity))) {
      return(TRUE)
    }
  }
  FALSE
}

# Whether a node sits in the condition of an `if`, where it is the test rather
# than the code the test protects.
in_if_condition <- function(node) {
  branches <- xml2::xml_find_all(node, "ancestor::*[parent::expr[IF]]")
  for (branch in branches) {
    position <- xml2::xml_find_num(
      branch,
      paste0("count(preceding-sibling::", ASSIGN_NODE, ")")
    )
    if (position == 0) {
      return(TRUE)
    }
  }
  FALSE
}

# `interactive()` or `rlang::is_interactive()`, which hold only in a session with
# someone at the keyboard.
is_interactive_call <- function(node) {
  parts <- call_parts(node)
  !is.null(parts) &&
    parts$fn %in% c("interactive", "is_interactive") &&
    length(parts$args) == 0L
}

# Whether a call runs only in an interactive session.
interactive_guarded <- function(call) guarded_by(call, is_interactive_call)

# Environment variables that R CMD check leaves unset: pkgdown sets IN_PKGDOWN
# while it builds a site, and devtools and testthat set NOT_CRAN, which CRAN never
# does.
CHECK_UNSET_VARS <- c("IN_PKGDOWN", "NOT_CRAN")

# The value a `Sys.getenv("VAR")` call returns under R CMD check, when VAR is one
# of CHECK_UNSET_VARS: its `unset` fallback, "" unless one is given. NA when the
# call reads another variable or the fallback is not a literal. The arguments are
# matched as R matches them, so `Sys.getenv(unset = "", "NOT_CRAN")` reads
# NOT_CRAN.
check_unset_value <- function(node) {
  parts <- if (is.null(node)) NULL else call_parts(node)
  if (is.null(parts) || parts$fn != "Sys.getenv") {
    return(NA_character_)
  }
  args <- matched_args(parts, c("x", "unset", "names"))
  if (is.null(args$x) || !string_literal(args$x) %in% CHECK_UNSET_VARS) {
    return(NA_character_)
  }
  if (is.null(args$unset)) "" else string_literal(args$unset)
}

# The value `as.logical(Sys.getenv("VAR"))` has under R CMD check, TRUE, FALSE or
# NA, when VAR is one of CHECK_UNSET_VARS, or NULL for any other term. It is NA
# unless the `unset` fallback is a logical word such as "false".
check_unset_logical <- function(node) {
  parts <- call_parts(node)
  if (is.null(parts) || parts$fn != "as.logical") {
    return(NULL)
  }
  unset <- check_unset_value(matched_args(parts, "x")$x)
  if (is.na(unset)) NULL else as.logical(unset)
}

# The value of a string literal, or NA for anything else.
string_literal <- function(node) {
  kids <- code_children(node)
  if (length(kids) == 1L && xml2::xml_name(kids) == "STR_CONST") {
    unquote_name(xml2::xml_text(kids))
  } else {
    NA_character_
  }
}

# Whether a term is false under R CMD check because it tests one of
# CHECK_UNSET_VARS for a value the variable does not have while unset:
# `identical(Sys.getenv("IN_PKGDOWN"), "true")`, `Sys.getenv("NOT_CRAN") == "true"`,
# `Sys.getenv("IN_PKGDOWN") != ""`, `nzchar(Sys.getenv("IN_PKGDOWN"))` or
# `isTRUE(as.logical(Sys.getenv("NOT_CRAN")))`. A bare
# `as.logical(Sys.getenv("NOT_CRAN"))` is NA there, and `if (NA)` stops the
# example with an error rather than skipping the branch, so it is a guard only
# when its fallback makes it FALSE.
is_check_unset_test <- function(node) {
  # Whether `a` reads a variable of CHECK_UNSET_VARS and the literal `b` is, or is
  # not when `same` is FALSE, the value it reads under R CMD check.
  compares <- function(a, b, same) {
    unset <- check_unset_value(a)
    value <- string_literal(b)
    !is.na(unset) && !is.na(value) && (value == unset) == same
  }
  kids <- code_children(node)
  tags <- xml2::xml_name(kids)
  if (length(tags) == 3L && tags[[1L]] == "expr" && tags[[2L]] %in% c("EQ", "NE")) {
    same <- tags[[2L]] == "NE"
    return(
      compares(kids[[1L]], kids[[3L]], same) || compares(kids[[3L]], kids[[1L]], same)
    )
  }
  parts <- call_parts(node)
  if (is.null(parts)) {
    return(FALSE)
  }
  if (parts$fn == "identical") {
    args <- matched_args(parts, c("x", "y"))
    return(
      !is.null(args$x) && !is.null(args$y) &&
        (compares(args$x, args$y, FALSE) || compares(args$y, args$x, FALSE))
    )
  }
  if (parts$fn == "nzchar") {
    unset <- check_unset_value(matched_args(parts, c("x", "keepNA"))$x)
    return(!is.na(unset) && !nzchar(unset))
  }
  if (parts$fn == "isTRUE" && length(parts$args) == 1L) {
    value <- check_unset_logical(parts$args[[1L]])
    return(!is.null(value) && !isTRUE(value))
  }
  isFALSE(check_unset_logical(node))
}

# A term that is false whenever R CMD check runs the example: an interactive
# session, or a variable only pkgdown or a developer's own check sets. Code behind
# it never runs under CRAN's checks.
is_check_off_guard <- function(node) {
  is_interactive_call(node) || is_check_unset_test(node)
}

# Whether a node sits inside one of the hidden blocks named by `tags`, read from
# the marker call rd_example_marked() wraps each block in. Any enclosing block
# counts, so a \donttest{} inside a \dontrun{} is still never run.
in_hidden_block <- function(node, tags = names(HIDDEN_EXAMPLE_MARKERS)) {
  xpath <- paste0(
    "ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[",
    paste0("text() = '", HIDDEN_EXAMPLE_MARKERS[tags], "'", collapse = " or "),
    "]]"
  )
  length(xml2::xml_find_all(node, xpath)) > 0L
}

# An \examples{} section as parsed R, with each hidden block marked, or NULL when
# even the repaired code will not parse. The code outside the hidden blocks is what
# R CMD check runs, so when that will not parse the example fails the check on its
# own, and there is nothing left for another check to judge.
rd_example_xml <- function(examples) {
  xml <- parse_text_xml(rd_example_marked(examples))
  if (is.null(xml)) {
    xml <- parse_text_xml(rd_example_marked(examples, repair = TRUE))
  }
  xml
}

# Every unguarded interactive call inside a hidden block, as list(fn, tag). A
# call outside every hidden block is left to R CMD check, which runs it.
hidden_interactive_calls <- function(xml) {
  calls <- xml2::xml_find_all(
    xml,
    paste0("//SYMBOL_FUNCTION_CALL[", NOT_MEMBER_ACCESS, "]")
  )
  names <- xml2::xml_text(calls)
  calls <- calls[
    names %in% INTERACTIVE_CALLS | grepl(INTERACTIVE_LAUNCHER_RE, names)
  ]
  # A statement at top level, or inside a `{` block that is not a function body,
  # has its value printed.
  printed <- paste0(
    "parent::expr/parent::expr[parent::exprlist or ",
    "parent::expr[OP-LEFT-BRACE][not(parent::expr[FUNCTION or OP-LAMBDA])]]"
  )
  marker <- paste0(
    "ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[",
    paste0("text() = '", HIDDEN_EXAMPLE_MARKERS, "'", collapse = " or "),
    "]][1]/expr[1]/SYMBOL_FUNCTION_CALL"
  )
  out <- list()
  for (call in calls) {
    fn <- xml2::xml_text(call)
    if (
      fn %in% INTERACTIVE_WHEN_PRINTED &&
        length(xml2::xml_find_all(call, printed)) == 0L
    ) {
      next
    }
    if (interactive_guarded(call)) {
      next
    }
    block <- xml2::xml_find_first(call, marker)
    if (inherits(block, "xml_missing")) {
      next
    }
    tag <- names(HIDDEN_EXAMPLE_MARKERS)[
      match(xml2::xml_text(block), HIDDEN_EXAMPLE_MARKERS)
    ]
    out[[length(out) + 1L]] <- list(fn = fn, tag = tag)
  }
  out
}

#' Diagnose Interactive Examples Hidden in `\\dontrun{}` or `\\donttest{}`
#'
#' Flags an interactive call, such as a shiny app, a viewer or a prompt, that an
#' example hides in `\\dontrun{}` or `\\donttest{}` instead of guarding with
#' `if (interactive())`.
#'
#' In `\\dontrun{}`, CRAN asks for the guard instead, so a reader can see that the
#' function needs a session, not only that it does not run. In `\\donttest{}` the
#' call is a failure waiting to happen: `R CMD check --as-cran` runs that code,
#' where a prompt errors and an app waits for input until the check times out.
#'
#' The example is read as parsed R, so a function named in a comment or a string
#' is not a call, and only a guard that actually encloses the call excuses it,
#' including roxygen's `@examplesIf interactive()`. An app that `shinyApp()`
#' builds is reported only where it is printed, which is what runs it; kept in a
#' variable or handed to another function, it starts nothing.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Structuring of Examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples),
#' and the rejection reads "Functions which are supposed to only run interactively
#' (e.g. shiny) should be wrapped in if(interactive()). Please replace \\dontrun{}
#' with if(interactive()){} if possible". `R CMD check --as-cran` has run
#' `\\donttest{}` examples since R 4.0.0. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_example_structure()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_example_interactive(pkg, verbose = FALSE)$passed
lab_example_interactive <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  rd_files <- list_rd_files(path)
  if (length(rd_files) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Interactive example check"
    ))
  }

  issues <- character(0)
  for (file in rd_files) {
    rd <- tryCatch(tools::parse_Rd(file), error = function(e) NULL)
    if (is.null(rd)) {
      next
    }
    examples <- extract_rd_section(rd, "\\examples")
    if (is.null(examples)) {
      next
    }
    xml <- rd_example_xml(examples)
    found <- if (!is.null(xml)) {
      hidden_interactive_calls(xml)
    } else {
      # The code outside the hidden blocks will not parse either, so no guard
      # around a block can be read. Read each block on its own.
      unlist(
        lapply(rd_hidden_blocks(examples), function(block) {
          block_xml <- parse_text_xml(rd_example_marked(block, repair = TRUE))
          if (is.null(block_xml)) list() else hidden_interactive_calls(block_xml)
        }),
        recursive = FALSE
      )
    }
    for (hit in found) {
      issues <- c(
        issues,
        if (identical(hit$tag, "\\dontrun")) {
          paste0(basename(file), ": ", hit$fn, "() is hidden in \\dontrun{}")
        } else {
          paste0(
            basename(file), ": ", hit$fn,
            "() in \\donttest{} runs under R CMD check --as-cran"
          )
        }
      )
    }
  }
  issues <- unique(issues)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Interactive examples use {.code if (interactive())}",
    "Interactive examples not guarded by {.code if (interactive())}",
    "Treatment: Guard the call with {.code if (interactive()) {{ ... }}}. CRAN asks for that in place of {.code \\dontrun{{}}}, and {.code R CMD check --as-cran} runs {.code \\donttest{{}}} code, where an interactive call errors or waits for input"
  )
  checktor_check_result(passed, issues, "Interactive example check")
}

#' Diagnose `:::` in Examples
#'
#' Flags a `pkg:::fn()` call in an example. The triple colon reaches an unexported
#' object, whose behaviour the author is free to change, so CRAN asks for one colon
#' or for the object to be exported.
#'
#' @section Source:
#' CRAN sends this back verbatim as "Using foo:::f instead of foo::f allows access
#' to unexported objects ... Please omit one colon", listing the `.Rd` files it
#' appears in. See `vignette("check-sources", package = "checktor")` for how every
#' check maps to its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_unexported_example_ns()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_example_internal_ns(pkg, verbose = FALSE)$passed
lab_example_internal_ns <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  parsed <- read_example_xml(path, kinds = c("example", "vignette"))
  if (length(parsed) == 0L) {
    return(checktor_check_result(TRUE, character(0), "Example ::: check"))
  }

  issues <- example_lints(parsed, "//NS_GET_INT", label = "uses :::")

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No {.code :::} in examples or vignettes",
    "{.code :::} used in examples or vignettes",
    "Treatment: Use {.code ::} on an exported object, or export the object the example needs"
  )
  checktor_check_result(passed, issues, "Example ::: check")
}

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
    # A named argument is what makes options() or par() a write rather than a read.
    setters <- xml2::xml_find_all(
      src$xml,
      paste0(
        "//SYMBOL_FUNCTION_CALL[text() = 'options' or text() = 'par']",
        "/parent::expr/parent::expr[SYMBOL_SUB]",
        " | //SYMBOL_FUNCTION_CALL[text() = 'setwd']/parent::expr/parent::expr"
      )
    )
    if (length(setters) == 0L) {
      next
    }
    # A restore anywhere in the same file is enough: the old value is captured and
    # handed back, which is what the reviewer asks for.
    restored <- length(xml2::xml_find_all(
      src$xml,
      paste0(
        "//expr[LEFT_ASSIGN or EQ_ASSIGN]",
        "[.//SYMBOL_FUNCTION_CALL[",
        "  text() = 'options' or text() = 'par' or text() = 'getwd'",
        "]]"
      )
    )) > 0L
    if (restored) {
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

# An example as the R code Rd2ex would write for it, with each \dontrun{} and
# \donttest{} body wrapped in its marker call. Rd `%` comments are dropped, as R
# drops them. The newline before `})` keeps a comment on the body's last line
# from swallowing the close.
#
# A hidden block may hold something that is not R -- output, JavaScript, a
# `<your key>` placeholder -- which stops the whole example parsing. With
# `repair = TRUE` each block keeps only the code in it that parses, so the rest of
# the example, and any guard around the block, can still be read.
rd_example_marked <- function(node, repair = FALSE) {
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
  body <- paste(
    vapply(
      node,
      rd_example_marked,
      character(1),
      repair = repair,
      USE.NAMES = FALSE
    ),
    collapse = ""
  )
  if (!is.null(tag) && tag %in% names(HIDDEN_EXAMPLE_MARKERS)) {
    if (repair) {
      body <- paste(parseable_pieces(body), collapse = "\n")
    }
    return(paste0(HIDDEN_EXAMPLE_MARKERS[[tag]], "({", body, "\n})"))
  }
  body
}

# The parts of `text` that parse, for code that will not parse whole. A chunk grows
# a line at a time while the parser says more input could complete it, and a line
# nothing can complete is dropped. The parser's message is translated, so this
# reads only the `<text>:line:col:` position in front of it, and the
# INCOMPLETE_STRING token name, which are not.
parseable_pieces <- function(text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  pieces <- character(0)
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
        pieces <- c(pieces, chunk)
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
  pieces
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

# What an `if` condition says about interactive(): TRUE when it can hold only in
# an interactive session, FALSE when only outside one, NA when it says neither.
# `interactive()`, `rlang::is_interactive()`, `isTRUE(interactive())`, `!` and
# `&&` are read; anything else, such as `CI == "" || interactive()`, which holds
# under R CMD check, is no guard.
interactive_polarity <- function(node) {
  kids <- xml2::xml_children(node)
  tags <- xml2::xml_name(kids)
  if (identical(tags, c("OP-LEFT-PAREN", "expr", "OP-RIGHT-PAREN"))) {
    return(interactive_polarity(kids[[2L]]))
  }
  if (identical(tags, c("OP-EXCLAMATION", "expr"))) {
    return(!interactive_polarity(kids[[2L]]))
  }
  if (length(tags) == 3L && tags[[2L]] %in% c("AND2", "AND")) {
    sides <- c(interactive_polarity(kids[[1L]]), interactive_polarity(kids[[3L]]))
    if (any(sides %in% TRUE)) {
      return(TRUE)
    }
    if (any(sides %in% FALSE)) {
      return(FALSE)
    }
    return(NA)
  }
  if (length(tags) >= 3L && tags[[1L]] == "expr" && tags[[2L]] == "OP-LEFT-PAREN") {
    fn <- xml2::xml_find_first(
      kids[[1L]],
      paste0("SYMBOL_FUNCTION_CALL[", NOT_MEMBER_ACCESS, "]")
    )
    if (inherits(fn, "xml_missing")) {
      return(NA)
    }
    fn <- xml2::xml_text(fn)
    args <- kids[tags == "expr"][-1L]
    if (fn %in% c("interactive", "is_interactive") && length(args) == 0L) {
      return(TRUE)
    }
    if (fn %in% c("isTRUE", "isFALSE") && length(args) == 1L) {
      polarity <- interactive_polarity(args[[1L]])
      return(if (fn == "isTRUE") polarity else !polarity)
    }
  }
  NA
}

# Whether a call runs only in an interactive session: it sits in the branch of an
# `if` that its condition confines to one -- the then branch of
# `if (interactive())`, or the else branch of `if (!interactive())`. Reading every
# enclosing `if` is what lets `@examplesIf interactive()` guard a whole example,
# and what stops a guard around one call excusing another.
interactive_guarded <- function(call) {
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
    polarity <- interactive_polarity(condition)
    if ((position == 1 && isTRUE(polarity)) || (position == 2 && isFALSE(polarity))) {
      return(TRUE)
    }
  }
  FALSE
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
    xml <- parse_text_xml(rd_example_marked(examples))
    if (is.null(xml)) {
      xml <- parse_text_xml(rd_example_marked(examples, repair = TRUE))
    }
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

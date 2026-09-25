# Checks on citations built from a bibliography in .Rd files.
#
# R 4.6.0 added Rd macros that build citations and reference lists from
# bibentries: \bibcitet{} and \bibcitep{} cite, \bibshow{} lists, \bibinfo{}
# annotates. They are \Sexpr macros run when the package is built, reading the
# package's own bibliography from REFERENCES.rds, REFERENCES.R or REFERENCES.bib
# in the package root or inst/, R's bibliography, and for a `pkg::key` the
# bibliography of that installed package. A key none of those holds is dropped
# from the page, with a warning only at build time.
#
# The files are read without running anything: REFERENCES.R is code, so its keys
# are read off its parse tree, and a .bib file's off its entry headers.

# The citing and listing macros, as system.Rd defines them.
BIB_CITE_MACROS <- c("\\bibcitep", "\\bibcitet")
BIB_MACROS <- c(BIB_CITE_MACROS, "\\bibshow", "\\bibinfo")

# The bibliography files R looks for, in the order it takes them.
REFERENCES_FILES <- c("REFERENCES.rds", "REFERENCES.R", "REFERENCES.bib")

#' Diagnose Citations Missing From the Bibliography
#'
#' Reads the `\bibcitet{}`, `\bibcitep{}` and `\bibshow{}` macros R 4.6.0 added to
#' `.Rd` files and reports what `R CMD check` would: a key that no bibliography
#' holds, which R drops from the page, and a key cited in a file whose
#' `\bibshow{}` never lists it. A `REFERENCES` file at the top level of the package
#' is reported too, since `R CMD check --as-cran` notes it as a non-standard file.
#'
#' A key is looked up as R looks it up: in the package's first `REFERENCES.rds`,
#' `REFERENCES.R` or `REFERENCES.bib`, in the root and then `inst/`, and in R's own
#' bibliography. A `pkg::key` is looked up in that package's bibliography when the
#' package is in `Depends`, `Imports` or `Suggests` and installed here. Nothing is
#' run to read the files: a key `REFERENCES.R` does not give as a string is not
#' guessed at, and no key is reported missing from a bibliography that could not
#' be read.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Bibliographic-citations-and-references),
#' under "Bibliographic citations and references", describes the macros and says
#' the bibliography is kept in `inst/`. `R CMD check` in R 4.6 warns "Could not
#' find bibentries for the following keys" and notes "Bibentries cited but not
#' shown in Rd file", and `--as-cran` notes a "Non-standard file/directory found
#' at top level". See `vignette("check-sources", package = "checktor")` for how
#' every check maps to its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`. It is
#'   skipped when R's own bibliography, which R 4.6.0 added, is not there to look
#'   a key up in.
#' @seealso [checktor()], [lab_rd_bibliography_files()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/rd_bibliography_bad.Rd",
#'                                  show_content = FALSE)
#' lab_rd_bibliography(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_rd_bibliography <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  label <- check_label("rd_bibliography")
  uses <- rd_bibliography_uses(path)

  issues <- character(0)
  refs <- references_file(path)
  if (!is.null(refs) && dirname(refs$rel) == "." && !refs$ignored) {
    issues <- c(
      issues,
      paste0(refs$rel, ": a non-standard file at the top level; move it to inst/")
    )
  }

  if (length(uses) > 0L) {
    r_keys <- r_bibliography_keys()
    if (is.null(r_keys)) {
      return(checktor_skipped_result(
        label,
        "R's bibliography, added in R 4.6.0, is not available to look keys up in"
      ))
    }
    local <- if (is.null(refs)) character(0) else refs$keys
    if (!is.null(local)) {
      local <- c(local, r_keys)
    }
    deps <- declared_dependencies(path)
    for (use in uses) {
      missing <- missing_bib_keys(use$keys, local, deps)
      if (length(missing) > 0L) {
        issues <- c(
          issues,
          paste0(use$file, ":", use$line, ": no bibentry for '", missing, "'")
        )
      }
    }
    for (file in unique(vapply(uses, `[[`, "", "file"))) {
      unshown <- cited_not_shown(Filter(function(u) u$file == file, uses))
      if (length(unshown) > 0L) {
        issues <- c(
          issues,
          paste0(
            file, ": cited but not shown: ",
            paste0("'", unshown, "'", collapse = ", ")
          )
        )
      }
    }
  }

  report_check(
    issues,
    verbose,
    label,
    "Every citation is in the bibliography and listed",
    "Citations R cannot find or does not list",
    treatment = paste("Treatment:", treatments$rd_bibliography$treatment)
  )
}

#' Diagnose a Bibliography R Cannot Read or Install
#'
#' For a package that cites with R 4.6.0's `\bibcitet{}`, `\bibcitep{}` or
#' `\bibshow{}` macros, reports a `REFERENCES.bib` whose package, `bibtex`, is not
#' in `Depends`, `Imports` or `Suggests`, and a `REFERENCES` file that is not
#' installed because it is outside `inst/` or excluded by `.Rbuildignore`.
#'
#' R reads the bibliography when it builds the package, wherever it is, so the
#' package's own pages are fine. But a `.bib` file is read with
#' `bibtex::read.bib()`, so a build on a machine that installed only the declared
#' dependencies, as r-universe and `pak` do, has no way to read it. And R installs
#' only what is in `inst/`, while another package's `\bibcitet{pkg::key}` looks
#' for the bibliography in the installed package.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Bibliographic-citations-and-references)
#' makes the bibliography available as `inst/REFERENCES.R` or
#' `inst/REFERENCES.bib`, the latter "needs bibtex to be installed". No check
#' enforces either, so this is `robustness` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_rd_bibliography
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_rd_bibliography()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("documentation_examples/rd_bibliography_bad.Rd",
#'                                  show_content = FALSE)
#' # Give the page a REFERENCES.bib, without 'bibtex' in Suggests to read it
#' dir.create(file.path(pkg, "inst"))
#' writeLines("@book{smith2020, author = {Ann Smith}, title = {Smoothing}, year = {2020}}",
#'            file.path(pkg, "inst", "REFERENCES.bib"))
#' lab_rd_bibliography_files(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_rd_bibliography_files <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  label <- check_label("rd_bibliography_files")
  refs <- references_file(path)
  issues <- character(0)
  # Rdpack keeps inst/REFERENCES.bib as well, read with its own tools, so the
  # file alone says nothing about R's macros.
  if (!is.null(refs) && length(rd_bibliography_uses(path)) > 0L) {
    if (endsWith(refs$rel, ".bib") && !"bibtex" %in% declared_dependencies(path)) {
      issues <- c(
        issues,
        paste0(
          refs$rel,
          ": reading it needs 'bibtex', which is not in Imports or Suggests"
        )
      )
    }
    # One at the top level that is built is reported by lab_rd_bibliography(), as
    # the non-standard file R CMD check notes.
    if (refs$ignored) {
      issues <- c(
        issues,
        paste0(
          refs$rel,
          ": not installed, so pkg::key citations cannot reach it; keep it in inst/"
        )
      )
    }
  }

  report_check(
    issues,
    verbose,
    label,
    "The bibliography can be read and is installed",
    "The bibliography cannot be read everywhere, or is not installed",
    treatment = paste("Treatment:", treatments$rd_bibliography_files$treatment)
  )
}

# Each use of a citing or listing macro in the package's .Rd files, as
# list(file, line, macro, keys) in the order they appear. Keys are split as R
# splits them: a comma-separated list, or the middle of `before|key|after`.
rd_bibliography_uses <- function(path) {
  macros <- bib_rd_macros()
  out <- list()
  for (file in list_rd_files(path)) {
    rd <- tryCatch(
      suppressWarnings(tools::parse_Rd(file, macros = macros)),
      error = function(e) NULL
    )
    if (is.null(rd)) {
      next
    }
    for (node in bib_macro_nodes(rd)) {
      macro <- attr(node, "macro")
      arg <- trimws(node[[2L]])
      keys <- if (macro %in% BIB_CITE_MACROS) bib_cite_keys(arg) else bib_list_keys(arg)
      out[[length(out) + 1L]] <- list(
        file = basename(file),
        line = rd_node_line(node),
        macro = macro,
        keys = keys
      )
    }
  }
  out
}

# The macro nodes in a parsed .Rd file, in document order. parse_Rd() keeps a
# user macro as a USERMACRO node whose first element is its definition and whose
# second is its argument, followed by its expansion.
bib_macro_nodes <- function(node) {
  if (identical(attr(node, "Rd_tag"), "USERMACRO")) {
    macro <- attr(node, "macro")
    if (!is.null(macro) && macro %in% setdiff(BIB_MACROS, "\\bibinfo")) {
      return(list(node))
    }
    return(list())
  }
  if (!is.list(node)) {
    return(list())
  }
  unlist(lapply(node, bib_macro_nodes), recursive = FALSE)
}

# The macros to parse .Rd files with: R's own, and on an R older than 4.6.0,
# where system.Rd does not define them, stand-ins for the bibliography macros so
# they parse as the same USERMACRO nodes.
bib_rd_macros <- function() {
  system_rd <- file.path(R.home("share"), "Rd", "macros", "system.Rd")
  macros <- tools::loadRdMacros(system_rd)
  if (all(BIB_MACROS %in% ls(macros, all.names = TRUE))) {
    return(macros)
  }
  defs <- tempfile(fileext = ".Rd")
  on.exit(unlink(defs), add = TRUE)
  writeLines(
    c(
      "\\newcommand{\\bibcitep}{#1}",
      "\\newcommand{\\bibcitet}{#1}",
      "\\newcommand{\\bibshow}{#1}",
      "\\newcommand{\\bibinfo}{#1}"
    ),
    defs
  )
  tools::loadRdMacros(defs, macros = macros)
}

# The keys a \bibcitet{} or \bibcitep{} argument names, as tools:::Rd_expr_bibcite
# reads them.
bib_cite_keys <- function(x) {
  if (!grepl("|", x, fixed = TRUE)) {
    return(bib_list_keys(x))
  }
  parts <- strsplit(paste0(x, "\001"), "|", fixed = TRUE)[[1L]]
  if (length(parts) != 3L) {
    return(character(0))
  }
  trimws(parts[[2L]])
}

# The keys a comma-separated list names, as \bibshow{} takes them.
bib_list_keys <- function(x) {
  keys <- trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
  keys[nzchar(keys)]
}

# Keys R will not find. `local` is every key the package itself can cite, or NULL
# when its bibliography could not be read, and then no local key is reported. A
# `pkg::key` is judged only for a declared dependency that is installed here.
missing_bib_keys <- function(keys, local, deps) {
  keys <- setdiff(keys, "*")
  missing <- character(0)
  for (key in unique(keys)) {
    if (!grepl("::", key, fixed = TRUE)) {
      if (!is.null(local) && !key %in% local) {
        missing <- c(missing, key)
      }
      next
    }
    pkg <- sub("::.*", "", key)
    dir <- if (pkg %in% deps) installed_package_dir(pkg) else ""
    if (!nzchar(dir)) {
      next
    }
    # An installed package with no bibliography has no keys to give.
    found <- references_file(dir, dirs = ".")
    keys_there <- if (is.null(found)) character(0) else found$keys
    if (!is.null(keys_there) && !sub(".*::", "", key) %in% keys_there) {
      missing <- c(missing, key)
    }
  }
  missing
}

# Keys cited in one .Rd file that none of its \bibshow{} calls lists, as
# tools:::.check_Rd_bibentries_cited_not_shown works it out. `*` lists everything
# cited so far, and an empty \bibshow{} starts the count again.
cited_not_shown <- function(uses) {
  cache <- cited <- shown <- character(0)
  for (use in uses) {
    if (use$macro != "\\bibshow") {
      cited <- unique(c(cited, use$keys))
      cache <- unique(c(cache, use$keys))
    } else if (length(use$keys) == 0L) {
      cited <- character(0)
    } else {
      given <- use$keys
      if (any(given == "*")) {
        given <- c(given[given != "*"], cache)
      }
      shown <- unique(c(shown, given))
    }
  }
  setdiff(cited, shown)
}

# The bibliography file R reads for a package: the first of REFERENCES_FILES in
# the root, then in inst/. list(rel, keys, ignored), with `keys` NULL when the
# file could not be read for them, or NULL when there is no such file.
references_file <- function(path, dirs = c(".", "inst")) {
  ignore <- build_ignore_matcher(path)
  for (dir in dirs) {
    for (name in REFERENCES_FILES) {
      rel <- if (dir == ".") name else file.path(dir, name)
      file <- file.path(path, rel)
      if (file.exists(file) && !dir.exists(file)) {
        return(list(
          rel = rel,
          keys = references_keys(file),
          ignored = unname(ignore(rel))
        ))
      }
    }
  }
  NULL
}

# The keys a bibliography file holds, or NULL when they cannot be read without
# running anything.
references_keys <- function(file) {
  tryCatch(
    switch(
      tools::file_ext(file),
      rds = bibentry_keys(readRDS(file)),
      R = references_r_keys(file),
      bib = bib_file_keys(file)
    ),
    error = function(e) NULL
  )
}

bibentry_keys <- function(bib) {
  if (!inherits(bib, "bibentry")) {
    return(NULL)
  }
  keys <- lapply(unclass(bib), attr, "key")
  as.character(unlist(keys, use.names = FALSE))
}

# The `key =` of every bibentry() call in a REFERENCES.R, read off its parse
# tree. NULL if any call gives its key as anything but a string, since the file
# then holds keys that cannot be read without running it.
references_r_keys <- function(file) {
  xml <- parse_text_xml(paste(safe_read_lines(file), collapse = "\n"))
  if (is.null(xml)) {
    return(NULL)
  }
  calls <- xml2::xml_find_all(
    xml,
    "//SYMBOL_FUNCTION_CALL[text() = 'bibentry']/parent::expr/parent::expr"
  )
  keys <- character(0)
  for (call in calls) {
    value <- xml2::xml_find_first(
      call,
      "SYMBOL_SUB[text() = 'key']/following-sibling::expr[1]"
    )
    if (inherits(value, "xml_missing")) {
      next
    }
    str <- xml2::xml_find_first(value, "self::expr[count(*) = 1]/STR_CONST")
    if (inherits(str, "xml_missing")) {
      return(NULL)
    }
    keys <- c(keys, unquote_name(xml2::xml_text(str)))
  }
  keys
}

# The keys of a BibTeX file, from its `@type{key,` entry headers. @string,
# @preamble and @comment are not entries.
bib_file_keys <- function(file) {
  text <- paste(safe_read_lines(file), collapse = "\n")
  m <- regmatches(
    text,
    gregexpr("@[[:space:]]*[A-Za-z]+[[:space:]]*[{(][[:space:]]*[^,[:space:]]+", text)
  )[[1L]]
  type <- tolower(sub("^@[[:space:]]*([A-Za-z]+).*$", "\\1", m))
  keys <- sub("^@[[:space:]]*[A-Za-z]+[[:space:]]*[{(][[:space:]]*", "", m)
  keys[!type %in% c("string", "preamble", "comment")]
}

# The keys of R's own bibliography, which R 4.6.0 added, or NULL on an R without
# it.
r_bibliography_keys <- function() {
  file <- file.path(R.home("share"), "bibliographies", "R.rds")
  if (!file.exists(file)) {
    return(NULL)
  }
  tryCatch(bibentry_keys(readRDS(file)), error = function(e) NULL)
}

# Where a package is installed, or "" when it is not.
installed_package_dir <- function(name) {
  system.file(package = name)
}

# The packages a DESCRIPTION depends on, imports or suggests.
declared_dependencies <- function(path) {
  desc <- description_or_null(path)
  if (is.null(desc)) {
    return(character(0))
  }
  unlist(
    lapply(c("Depends", "Imports", "Suggests"), function(f) parse_package_list(desc[[f]])),
    use.names = FALSE
  )
}

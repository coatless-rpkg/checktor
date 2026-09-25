#' Diagnose DESCRIPTION File Issues
#'
#' Runs diagnostics against the package DESCRIPTION file. Fields are parsed
#' with [base::read.dcf()] so that multi-line fields like `Description` and
#' `Title` are inspected in full, not just their first physical line.
#'
#' @param path Character. Path to the R package directory. Default: `"."`.
#' @param verbose Logical. Whether to print diagnostic output. Default: `TRUE`.
#'
#' @return
#' List containing one named element per check. Each element is a list with at
#' least `passed`, `issues`, and `message` (see [checktor_check_result()]).
#' When the `DESCRIPTION` is missing or R cannot read it, `description_file`
#' fails, and every check that reads the parsed fields, registered ones
#' included, is reported as skipped with the reason "DESCRIPTION could not be
#' read", since it has nothing to examine.
#'
#' @seealso
#' [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' pkg_path <- example_diagnose_scenario("description_examples/bad_description.txt",
#'                                       show_content = FALSE)
#' results <- diagnose_description_issues(pkg_path, verbose = FALSE)
#' issues(results)     # description-field problems, if any
diagnose_description_issues <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  if (verbose) {
    cli::cli_h2("DESCRIPTION File Health Check")
  }

  desc_file <- file.path(path, "DESCRIPTION")
  desc <- if (file.exists(desc_file)) {
    tryCatch(read_description(desc_file), error = function(e) NULL)
  }

  # The DESCRIPTION sub-checks operate on the parsed `desc` (and `path` for
  # license cross-checks), not on the package path directly. Build a small
  # adapter list so we can still use run_checks() for the tryCatch/passed
  # bookkeeping.
  checks <- list(
    # Whether R can read the file at all. It re-reads the file rather than taking
    # `desc`, because the question is about the file, not about the fields.
    description_file = function(p, v) lab_description_file(p, v),
    description_fields = function(p, v) lab_description_fields(p, v, desc),
    description_placeholders = function(p, v) {
      lab_description_placeholders(p, v, desc)
    },
    software_names = function(p, v) {
      lab_software_names(p, v, desc)
    },
    language_names = function(p, v) lab_language_names(p, v, desc),
    # `format_names` is deliberately NOT here. JSON, HTML, SQL and the other
    # formats are written bare by most packages CRAN accepts, so a bare one breaks
    # no rule it enforces (#16). It stays available on request.
    acronyms = function(p, v) lab_acronyms(p, v, desc),
    license = function(p, v) lab_license(p, v, desc),
    license_file_unneeded = function(p, v) {
      lab_license_file_unneeded(p, v, desc)
    },
    title_case = function(p, v) lab_title_case(p, v, desc),
    title_length = function(p, v) lab_title_length(p, v, desc),
    title_package_name = function(p, v) lab_title_package_name(p, v, desc),
    # `title_starts_with_article` is deliberately NOT here. It is a mis-transplant
    # of CRAN's real rule, whose source is
    #     if (grepl("^(The|This|A|In this|In the) package", descr)) ...
    # That rule applies to the DESCRIPTION field, not the Title, and requires the
    # literal noun "package" after the article. checktor kept the article
    # alternation, dropped the "package" anchor, and re-pointed it at the Title,
    # turning a narrow anti-boilerplate rule into a blanket ban on ordinary English.
    # jsonlite ("A Simple and Robust JSON Parser and Generator for R") and curl
    # ("A Modern and Flexible Web Client for R") are both on CRAN with such titles.
    # `description_starts_with` already enforces the real rule, in the right field.
    title_redundant_phrases = function(p, v) {
      lab_title_redundant_phrases(p, v, desc)
    },
    # `description_function_quotes` is deliberately NOT here. It asserted that
    # single quotes are RESERVED for software names, so a quoted function name was a
    # violation. Writing R Extensions actually says single quotes are for non-English
    # usage, INCLUDING the names of other packages and external software: an
    # inclusive list, not an exclusive one. A function name is non-English usage and
    # is legitimately single-quoted. Nothing in WRE or the CRAN policy forbids
    # `'digest()'`, and digest itself ships exactly that.
    authors = function(p, v) lab_authors(p, v, desc),
    identifier_format = function(p, v) lab_identifier_format(p, v, desc),
    # `cph_role` is deliberately NOT here. ?person says authors who are natural
    # persons are copyright holders by default and need no cph role, so a package
    # written by people is not missing anything. It stays available on request.
    references = function(p, v) lab_references(p, v, desc),
    date_format = function(p, v) lab_date_format(p, v, desc),
    encoding_utf8 = function(p, v) lab_encoding_utf8(p, v, desc),
    version_format = function(p, v) lab_version_format(p, v, desc),
    spelling = function(p, v) lab_spelling(p, v, desc),
    description_length = function(p, v) lab_description_length(p, v, desc),
    description_starts_with = function(p, v) {
      lab_description_starts_with(p, v, desc)
    },
    description_quoted_quotes = function(p, v) {
      lab_description_quoted_quotes(p, v, desc)
    },
    license_year = function(p, v) lab_license_year(p, v)
  )

  registered <- registered_checks_for("description", desc = desc)

  # A DESCRIPTION R cannot read used to end this category early with no checks in
  # it. Nothing counts a category, only its checks, so checktor() called such a
  # package healthy although R cannot build or install it. `description_file`
  # reports it and counts like any other check. Every check that reads the fields
  # could not run, so each is reported as skipped under its own name, registered
  # checks included, and a clean result elsewhere never hides one. license_year
  # reads LICENSE alone and runs as usual.
  if (is.null(desc)) {
    skip_as <- function(message) {
      force(message)
      function(p, v) {
        checktor_skipped_result(message, "DESCRIPTION could not be read")
      }
    }
    for (nm in names(DESCRIPTION_FIELD_CHECKS)) {
      checks[[nm]] <- skip_as(DESCRIPTION_FIELD_CHECKS[[nm]])
    }
    registered <- lapply(stats::setNames(nm = names(registered)), skip_as)
  }
  run_checks(c(checks, registered), path, verbose)
}

# The panel's checks that read the parsed DESCRIPTION, with the message each one
# reports. When R cannot read the file they are returned skipped under these
# messages, so they print as they would have. A test holds them to the messages
# the checks themselves return.
DESCRIPTION_FIELD_CHECKS <- c(
  description_fields = "DESCRIPTION fields check",
  description_placeholders = "DESCRIPTION placeholders check",
  software_names = "Software names check",
  language_names = "Language names check",
  acronyms = "Acronyms check",
  license = "License check",
  license_file_unneeded = "License file pointer check",
  title_case = "Title case check",
  title_length = "Title length check",
  title_package_name = "Title package-name check",
  title_redundant_phrases = "Title redundant-phrases check",
  authors = "Authors@R field check",
  identifier_format = "Author identifier check",
  references = "References check",
  date_format = "Date field check",
  encoding_utf8 = "Encoding field check",
  version_format = "Version field check",
  spelling = "Spelling check",
  description_length = "Description length check",
  description_starts_with = "Description opening check",
  description_quoted_quotes = "Description double-quotes check"
)

# Returns a named list of DESCRIPTION fields, with multi-line fields collapsed.
# Using read.dcf folds continuation lines into a single string per field.
#
# It refuses what R's own reader, tools:::.read_description(), refuses, so a file
# checktor reads is one R CMD build and INSTALL will read too. The errors name
# the file, because a user calling a lab_*() function directly sees them as is.
read_description <- function(desc_file) {
  # One handler: tryCatch() nests several, so an error raised in the first would
  # be caught again by the second.
  raw <- tryCatch(read_dcf_quietly(desc_file), error = function(e) {
    what <- if (inherits(e, "checktor_unopenable")) {
      "DESCRIPTION "
    } else {
      "DESCRIPTION does not parse: "
    }
    stop(what, conditionMessage(e), call. = FALSE)
  })
  if (nrow(raw) == 0L) {
    stop("DESCRIPTION has no records", call. = FALSE)
  }
  # read.dcf() takes a blank line as the end of a record and reads on, so the
  # fields after it become a second record. R stops on that file; keeping the
  # first record would quietly drop every field after the blank line.
  if (nrow(raw) > 1L) {
    stop(
      "DESCRIPTION contains a blank line, which splits it into more than one record",
      call. = FALSE
    )
  }
  as.list(raw[1L, ])
}

#' Diagnose a DESCRIPTION File R Cannot Read
#'
#' Flags a `DESCRIPTION` that is missing or that R cannot read: a line that is
#' neither a `Field: value` pair nor an indented continuation, or a blank line
#' that splits the file in two. `R CMD build` and `R CMD INSTALL` both stop on
#' such a file, so the package cannot be built or installed. A `DESCRIPTION`
#' R cannot open at all fails with the reason, a directory in its place or a
#' file without read permission, which is found from the file system and so
#' reads the same in any language. Every other `DESCRIPTION` check reads the
#' parsed fields, so while this one fails they are reported as skipped.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", specifies the format of a Debian Control File:
#' "Fields start with an ASCII name immediately followed by a colon" and
#' "Continuation lines ... start with a space or tab". R reads it with
#' [base::read.dcf()] and refuses a file that yields more than one record. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Present for signature parity with the other DESCRIPTION checks;
#'   this check asks whether R can read the `DESCRIPTION` file itself, so it
#'   reads the file and ignores `desc`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario(
#'   "description_examples/unparseable_description.txt",
#'   show_content = FALSE
#' )
#' lab_description_file(pkg, verbose = FALSE)$issues
lab_description_file <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc_file <- file.path(path, "DESCRIPTION")
  issues <- if (!file.exists(desc_file)) {
    "DESCRIPTION file not found"
  } else {
    tryCatch(
      {
        read_description(desc_file)
        character(0)
      },
      error = function(e) conditionMessage(e)
    )
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "{.file DESCRIPTION} parses",
    "R cannot read {.file DESCRIPTION}",
    "Treatment: Make DESCRIPTION a file R can open, with every line a 'Field: value' pair or a continuation indented by a space or tab, and no blank line between fields"
  )
  checktor_check_result(passed, issues, "DESCRIPTION file check")
}

# The DESCRIPTION fields R knows, copied from
# tools:::.get_standard_DESCRIPTION_fields() (R 4.6.1) rather than called
# through `:::`. A test holds the copy to R.
STANDARD_DESCRIPTION_FIELDS <- c(
  "Package", "Version", "Priority", "Depends", "Imports", "LinkingTo",
  "Suggests", "Enhances", "License", "License_is_FOSS",
  "License_restricts_use", "OS_type", "Archs", "MD5sum",
  "NeedsCompilation", "Additional_repositories", "Author", "Authors@R",
  "Biarch", "BugReports", "BuildKeepEmpty", "BuildManual",
  "BuildResaveData", "BuildVignettes", "Built", "ByteCompile",
  "Classification/ACM", "Classification/ACM-2012", "Classification/JEL",
  "Classification/MSC", "Classification/MSC-2010", "Collate",
  "Collate.unix", "Collate.windows", "Contact", "Copyright", "Date",
  "Description", "Encoding", "KeepSource", "Language", "LazyData",
  "LazyDataCompression", "LazyLoad", "MailingList", "Maintainer", "Note",
  "Packaged", "RdMacros", "StagedInstall", "SysDataCompression",
  "SystemRequirements", "Title", "Type", "URL", "UseLTO",
  "VignetteBuilder", "ZipData", "Repository", "Path", "Date/Publication",
  "LastChangedDate", "LastChangedRevision", "Revision", "RcmdrModels",
  "RcppModules", "Roxygen", "Acknowledgements", "Acknowledgments",
  "biocViews"
)

# The field-name prefixes R's incoming check lets through, as it writes them.
DESCRIPTION_FIELD_PREFIXES <- c(
  "X-CRAN", "X-schema.org", "Repository/R-Forge", "VCS/", "Config/"
)

#' Diagnose DESCRIPTION Fields R Does Not Know
#'
#' Flags a `DESCRIPTION` field that is not one of the fields R knows, which is
#' how CRAN's incoming check reads it. The usual one is `Remotes`, which
#' `devtools` and `pak` read but CRAN does not, since CRAN installs
#' dependencies from CRAN and Bioconductor alone. The others are typos such as
#' `Bugreports`, `Import`, `Suggest` or `URLs`, which R ignores, so the field
#' meant is silently missing; the finding names the field that was probably
#' meant.
#'
#' The fields R allows beyond its own list are allowed here too: any
#' `Config/` field, such as `Config/testthat/edition`, and fields starting
#' `X-CRAN`, `X-schema.org`, `Repository/R-Forge` or `VCS/`, and a standard
#' field name followed by `Note`, such as `RoxygenNote`.
#'
#' @section Source:
#' The
#' [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' run by `R CMD check --as-cran` NOTEs "Unknown, possibly misspelled, fields in
#' DESCRIPTION". The
#' [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' says "The strong dependencies ... should be available from CRAN or the
#' Bioconductor software repository", which is why a `Remotes` field has no
#' place in a submission. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario(
#'   "description_examples/description_fields_bad.txt",
#'   show_content = FALSE
#' )
#' lab_description_fields(pkg, verbose = FALSE)$issues
lab_description_fields <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  fields <- names(desc)
  prefix <- paste0("^(", paste(DESCRIPTION_FIELD_PREFIXES, collapse = "|"), ")")
  unknown <- fields[
    !fields %in% STANDARD_DESCRIPTION_FIELDS &
      !grepl(prefix, fields) &
      !fields %in% paste0(STANDARD_DESCRIPTION_FIELDS, "Note")
  ]
  issues <- vapply(
    unknown,
    function(field) {
      what <- paste0(field, ": not a DESCRIPTION field R knows")
      if (identical(field, "Remotes")) {
        return(paste0(
          what, "; CRAN installs dependencies from CRAN and Bioconductor only, ",
          "so remove it before submitting"
        ))
      }
      # A near miss is a typo: R ignores the field, so the one meant is missing.
      d <- utils::adist(tolower(field), tolower(STANDARD_DESCRIPTION_FIELDS))[1L, ]
      best <- which.min(d)
      if (d[best] <= 2L && d[best] < nchar(field) / 3) {
        what <- paste0(what, "; did you mean ", STANDARD_DESCRIPTION_FIELDS[best], "?")
      }
      what
    },
    "",
    USE.NAMES = FALSE
  )
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Every DESCRIPTION field is one R knows",
    "DESCRIPTION fields R does not know",
    paste0(
      "Treatment: Fix a misspelt field name, and remove Remotes and any other ",
      "field R does not know, or move it under Config/"
    )
  )
  checktor_check_result(passed, issues, "DESCRIPTION fields check")
}

# The template text usethis and package.skeleton() leave in a DESCRIPTION, as
# R's incoming check tests for it: a field and a test on its value. Title and
# Description are compared in lower case, Author and Maintainer as written.
DESCRIPTION_PLACEHOLDERS <- list(
  Title = function(x) startsWith(tolower(x), "what the package does"),
  Description = function(x) {
    startsWith(tolower(x), "what the package does") ||
      startsWith(tolower(x), "more about what it does")
  },
  Author = function(x) x == "Who wrote it",
  Maintainer = function(x) {
    startsWith(x, "Who to complain to") || startsWith(x, "The package maintainer")
  }
)

#' Diagnose Template Text Left in DESCRIPTION
#'
#' Flags a `Title`, `Description`, `Author` or `Maintainer` that still holds the
#' text a package template wrote: the `usethis` template's "What the Package
#' Does (One Line, Title Case)" and "What the package does (one paragraph).",
#' and `package.skeleton()`'s "What the Package Does (Short Line)", "More about
#' what it does (maybe more than one line).", "Who wrote it" and "Who to
#' complain to". It applies R's own tests, so it flags what CRAN flags. A
#' template `Authors@R` is [lab_authors()]'s to report.
#'
#' @section Source:
#' The
#' [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' run by `R CMD check --as-cran` NOTEs "DESCRIPTION fields with placeholder
#' content". [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file)
#' asks for a `Title` and `Description` that describe the package. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario(
#'   "description_examples/description_placeholders_bad.txt",
#'   show_content = FALSE
#' )
#' lab_description_placeholders(pkg, verbose = FALSE)$issues
lab_description_placeholders <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  issues <- character(0)
  for (field in names(DESCRIPTION_PLACEHOLDERS)) {
    value <- dcf_field(desc, field)
    if (is.null(value) || is.na(value)) {
      next
    }
    value <- trimws(gsub("[\n\t]", " ", value))
    if (isTRUE(DESCRIPTION_PLACEHOLDERS[[field]](value))) {
      issues <- c(issues, paste0(field, " is template text: ", value))
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No template text left in DESCRIPTION",
    "DESCRIPTION still holds template text",
    "Treatment: Replace the template text with the package's own Title, Description and authors"
  )
  checktor_check_result(passed, issues, "DESCRIPTION placeholders check")
}

# Resolve the DESCRIPTION for a check that may be called either directly by a
# user (who has a path) or from diagnose_description_issues() (which has already
# parsed it once). Mirrors the `parsed = NULL` convention the code checks use.
#
# A `desc` comes back as the named list read_description() returns, which is
# what the checks read. `desc` is documented as what read.dcf() returns, a
# one-row matrix whose field names are column names, so desc[["Title"]] on it is
# a subscript error; so is a missing field on a named vector. As a list, a
# missing field is NULL.
resolve_description <- function(path, desc) {
  if (is.matrix(desc)) {
    desc <- if (nrow(desc) > 0L) desc[1L, ] else list()
  }
  if (!is.null(desc)) {
    return(as.list(desc))
  }
  desc_file <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_file)) {
    cli::cli_abort("No {.file DESCRIPTION} found at {.path {path}}")
  }
  read_description(desc_file)
}

# The calls R's own reader allows in Authors@R from R 4.6.0 on
# (utils:::.read_authors_at_R_field). R CMD build stops on any other as a
# "Malformed Authors@R field".
AUTHORS_AT_R_CALLS <- c(
  "person", "as.person", "c", "list", "paste", "paste0", "("
)

# The calls in a parsed Authors@R that R's reader refuses, in the order they
# appear. The walk mirrors tools:::.find_calls(recursive = TRUE) and
# tools:::.call_names(): a call is refused when its function part does not
# deparse to one of AUTHORS_AT_R_CALLS, wherever it sits, so a namespaced
# utils::person(), a parenthesised (c) and an operator such as `-` are all
# caught by the same rule. Only the parse tree is read; nothing in it runs. Each
# call is named by its function part with the arguments elided, as in
# "utils::person(...)", and a refused function part is not walked again, since
# its name already shows all of it.
authors_at_r_refused_calls <- function(exprs) {
  refused <- character(0)
  # Elements are passed on by index, e[[i]], never bound to a loop variable: an
  # empty argument, as in person("A", "B", , "a@b.org"), is R's missing-argument
  # marker, which R refuses to read back from a variable.
  walk <- function(e) {
    if (is.pairlist(e)) {
      # A function's formals, whose defaults are calls too.
      e <- as.list(e)
      for (i in seq_along(e)) {
        walk(e[[i]])
      }
      return(invisible())
    }
    if (!is.call(e)) {
      return(invisible())
    }
    fn <- e[[1L]]
    name <- deparse1(fn)
    args <- as.list(e)[-1L]
    if (!name %in% AUTHORS_AT_R_CALLS) {
      label <- if (is.symbol(fn) && name %in% c("::", ":::")) {
        # A namespaced name that is passed rather than called.
        deparse1(e)
      } else {
        if (is.symbol(fn) && !identical(make.names(name), name)) {
          name <- paste0("`", name, "`")
        }
        paste0(name, if (length(args) > 0L) "(...)" else "()")
      }
      refused <<- c(refused, label)
    }
    for (i in seq_along(args)) {
      walk(args[[i]])
    }
    invisible()
  }
  # The walk recurses once per nesting level, and a field such as
  # `1 + 1 + ... + 1` nests one call per term, deep enough to exhaust R's stack.
  # R refuses such a field anyway, so report it rather than crash.
  tryCatch(
    for (i in seq_along(exprs)) {
      walk(exprs[[i]])
    },
    error = function(e) {
      refused <<- c(refused, "a call nested too deeply to read")
    }
  )
  unique(refused)
}

# Parse the Authors@R field into a person object using only public R. Returns
# list(persons, error, refused): `persons` is a "person" object (or NULL if the
# field is absent or unreadable), `error` is a message string when the field is
# present but cannot be read, and `refused` names each call R's own reader
# refuses (authors_at_r_refused_calls()). A malformed field surfaces as a
# reported issue, never a crash. Shared by the authors, identifier and cph
# checks so they read Authors@R the same way.
parse_authors_at_r <- function(desc) {
  aar <- desc[["Authors@R"]]
  if (is.null(aar) || is.na(aar) || !nzchar(aar)) {
    return(list(persons = NULL, error = NULL, refused = character(0)))
  }
  exprs <- tryCatch(
    parse(text = aar, keep.source = FALSE),
    error = function(e) e
  )
  if (inherits(exprs, "error")) {
    return(list(
      persons = NULL,
      error = conditionMessage(exprs),
      refused = character(0)
    ))
  }
  refused <- authors_at_r_refused_calls(exprs)
  # Authors@R is a raw R expression, and checktor lints other people's packages
  # without otherwise running their code. A plain eval() would execute whatever
  # the field contains (`Authors@R: system("...")`), so evaluate it in a locked
  # environment that exposes only the functions a well-formed field needs, with
  # emptyenv() as parent. Anything else fails to resolve and is reported as an
  # unparseable field rather than being run. The list is AUTHORS_AT_R_CALLS.
  safe_env <- new.env(parent = emptyenv())
  safe_env$person <- utils::person
  safe_env$as.person <- utils::as.person
  safe_env$c <- base::c
  safe_env$list <- base::list
  safe_env$paste <- base::paste
  safe_env$paste0 <- base::paste0
  safe_env[["("]] <- base::`(`
  # R refuses `utils::person(...)`, and `refused` says so, but the field is
  # still read so the checks of roles and identifiers see what it declares.
  # `::` and `:::` resolve those two names and nothing else. They look only at
  # the names as written, never evaluating either side, so a computed name such
  # as `::`(paste0("ba", "se"), f) is refused too.
  namespace_get <- function(op) {
    force(op)
    function(pkg, name) {
      pkg <- substitute(pkg)
      name <- substitute(name)
      as_name <- function(x) {
        if (is.symbol(x) || (is.character(x) && length(x) == 1L)) {
          as.character(x)
        } else {
          NA_character_
        }
      }
      pkg <- as_name(pkg)
      name <- as_name(name)
      if (!identical(pkg, "utils") || !name %in% c("person", "as.person")) {
        what <- if (is.na(pkg) || is.na(name)) {
          "a computed name"
        } else {
          paste0(pkg, op, name)
        }
        stop(
          "only utils::person and utils::as.person may be called with a ",
          "namespace, not ",
          what,
          call. = FALSE
        )
      }
      get(name, envir = safe_env, inherits = FALSE)
    }
  }
  safe_env[["::"]] <- namespace_get("::")
  safe_env[[":::"]] <- namespace_get(":::")
  unreadable <- function(error) {
    list(persons = NULL, error = error, refused = refused)
  }
  parsed <- tryCatch(
    suppressWarnings(eval(exprs, envir = safe_env)),
    error = function(e) e
  )
  if (inherits(parsed, "error")) {
    return(unreadable(conditionMessage(parsed)))
  }
  if (!inherits(parsed, "person")) {
    return(unreadable("Authors@R does not evaluate to a person() object"))
  }
  # c() on a person and anything else, a list(person()) say, still returns a
  # "person", with the stray value as an entry. R cannot read the authors from
  # that ("subscript out of bounds"), and reading roles from it crashed here
  # too.
  fields <- c("given", "family", "role", "email", "comment")
  well_formed <- vapply(
    unclass(parsed),
    function(e) {
      is.list(e) &&
        !inherits(e, "person") &&
        !is.null(names(e)) &&
        all(names(e) %in% fields)
    },
    logical(1)
  )
  if (!all(well_formed)) {
    return(unreadable(paste0(
      "entry ",
      which(!well_formed)[[1L]],
      " is not a person, so R cannot read the authors from it"
    )))
  }
  list(persons = parsed, error = NULL, refused = refused)
}

# ---- Quoted names: what counts as bare --------------------------------------

# The spans of a Title or Description that are not bare prose. The first three are
# the spans CRAN's incoming spell check skips, as tools:::.check_package_CRAN_incoming
# hands them to aspell: a single-quoted span, a function call written foo() or
# pkg::foo(), and the target of <https://...>, <doi:...> or <arXiv:...> markup.
# They depart from CRAN's patterns twice. An apostrophe before two digits that end
# the word, as in '90s or '21, elides a year and opens no quote, which would
# otherwise run to the next apostrophe and hide the words between; a quoted name
# that starts with a digit ('4ti2', '3+3/PC') is still quoted. And the package in
# a call may contain a dot (shiny.semantic::semanticPage()), where CRAN's takes
# only letters and digits.
#
# The last three are checktor's. CRAN's quote pattern wants a blank or
# punctuation after the closing quote, so a quoted name that takes a plural or
# possessive s ('data.table's, 'ggplot2's) fails it although the name is quoted.
# Double quotes enclose a quotation, such as the title of a book or article, and a
# name inside one is part of the quotation; a name alone in double quotes is
# lab_description_quoted_quotes()'s to report. And a name in a bare web address is
# part of the address, not a mention.
QUOTING_IGNORED_SPANS <- c(
  quoted = "(?<=[ \t[:punct:]])'(?![0-9]{2}s?(?![[:alnum:]]))[^']*'(?=[ \t[:punct:]])",
  call = "(?<=[ \t[:punct:]])([[:alnum:].]+::)?[[:alnum:]_.]*\\(\\)(?=[ \t[:punct:]])",
  markup = "(?<=[<])(https?://|DOI:|doi:|arXiv:)[^>]+(?=[>])",
  quoted_s = "(?<=[ \t[:punct:]])'(?![0-9]{2}s?(?![[:alnum:]]))[^']*'(?=s(?![[:alnum:]]))",
  double_quoted = "(?<=[ \t[:punct:]])\"[^\"]*\"(?=[ \t[:punct:]])",
  url = "(https?|ftp)://[^[:space:]<>]+"
)

# A field with every span above blanked to spaces, leaving the prose a
# reader sees unquoted. The quoting checks search this, so a term inside a quoted
# longer name ('R Markdown', 'JSON-stat', 'shiny.semantic') is not bare, and each
# remaining occurrence is judged on its own. Blanking rather than deleting keeps
# the words either side of a span apart, as aspell does.
#
# CRAN's patterns need a blank or punctuation either side of a quote. aspell gets
# one by blanking the "Field:" tag and appending a blank to every line, so the
# field is padded here. read.dcf() also joins a continuation line with a newline,
# which the patterns do not count, so every run of whitespace becomes one blank
# first; otherwise a quote that opens a continuation line would not be a quote.
# A missing or empty field has no prose, and comes back empty rather than padded,
# so an NA is never read as the word "NA".
blank_ignored_spans <- function(text) {
  empty <- is.na(text) | !nzchar(text)
  text <- paste0(" ", gsub("[[:space:]]+", " ", text), " ", recycle0 = TRUE)
  for (re in QUOTING_IGNORED_SPANS) {
    hits <- gregexpr(re, text, perl = TRUE)
    regmatches(text, hits) <- lapply(
      regmatches(text, hits),
      function(s) strrep(" ", nchar(s))
    )
  }
  text[empty] <- ""
  text
}

# Whether `name` still occurs in text returned by blank_ignored_spans(). A name
# can carry regex metacharacters (C++, C#, data.table), so it is escaped, and it
# must not match inside a larger token: Java in JavaScript, SQL in PostgreSQL. A
# dot joins a token when a word character sits on its other side, so the shiny in
# shiny.semantic is part of another package's name, while a full stop ending the
# sentence still ends the name.
has_bare_name <- function(blanked, name) {
  pattern <- paste0(
    "(?<![\\w+#])(?<!\\w\\.)",
    escape_regex(name),
    "(?![\\w+#]|\\.\\w)"
  )
  grepl(pattern, blanked, perl = TRUE)
}

# The quoting checks' shared loop: one finding per field and name that still
# occurs bare once the ignored spans are blanked, in vocabulary order. Searching
# the blanked text judges each occurrence on its own. Asking whether a literal
# 'shiny' appeared anywhere let one quoted mention excuse every bare one, and
# still reported the shiny inside a correctly quoted 'shiny.semantic'.
bare_name_issues <- function(desc, names, finding) {
  issues <- character(0)
  for (field in c("Title", "Description")) {
    text <- dcf_field(desc, field)
    if (is.null(text) || is.na(text) || !nzchar(text)) {
      next
    }
    unquoted <- blank_ignored_spans(text)
    for (name in names) {
      if (has_bare_name(unquoted, name)) {
        issues <- c(issues, paste0(field, ": ", name, " ", finding))
      }
    }
  }
  issues
}

#' Diagnose Unquoted Software Names in DESCRIPTION
#'
#' Flags a package or external-software name in `Title`/`Description` that is not in single quotes, as Writing R Extensions requires.
#'
#' Each occurrence is judged on its own, so one quoted mention does not excuse a
#' bare one elsewhere. A name is not bare inside a single-quoted span such as
#' `'shiny.semantic'`, a `<https://...>` or `<doi:...>`, or a function call such
#' as `purrr::map()`, which are the spans CRAN's own incoming spell check skips.
#' Nor is it bare in a plain web address, or in a double-quoted quotation such as
#' the title of a book. A name alone in double quotes, in either field, is
#' reported by [lab_description_quoted_quotes()] instead.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", asks you to "Refer to other packages and
#' external software in single quotes". See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_software_names(pkg, verbose = FALSE)$passed
lab_software_names <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  # R PACKAGE and software-PRODUCT names only. Writing R Extensions asks for "other
  # packages and external software" in single quotes, and CRAN enforces it for
  # package names, so an unquoted `ggplot2` or `shiny` is flagged here at policy.
  #
  # PROGRAMMING LANGUAGES (Python, Java) live in their own policy check,
  # `lab_language_names()` -- a language name and a package name are different
  # kinds of thing, so they read as separate concerns -- and format and markup
  # names (JSON, HTML, SQL) in `lab_format_names()`, which runs on request. ("R"
  # itself is never flagged anywhere, in either form: no authority names it, and
  # both a bare R and a quoted 'R' clear CRAN, so neither is worth nagging about.)
  #
  # `WebAssembly` stays here rather than with the languages: it is a specific format
  # (a W3C standard, not a language you write a package "in"), consistently quoted
  # in the R WebAssembly ecosystem, and CRAN asks for it. Its abbreviation `WASM`
  # and the products `webR`/`Shinylive` are recognised when quoted but not demanded,
  # since bare abbreviations in parentheses are conventional. A package can add its
  # own names via `Config/checktor/software_names`.
  software_names <- check_vocab(
    checktor_config(path),
    "software_names",
    c(
      "ggplot2",
      "dplyr",
      "tidyr",
      "purrr",
      "tibble",
      "shiny",
      "plotly",
      "data.table",
      "tidyverse",
      "WebAssembly"
    )
  )
  issues <- bare_name_issues(desc, software_names, "should be in single quotes")

  passed <- length(issues) == 0
  emit_issue_summary(
    issues,
    verbose,
    "Software names appear properly formatted",
    "Potential software name formatting issues",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Software names check")
}

#' Diagnose Programming-Language Names in DESCRIPTION
#'
#' Flags a bare programming-language or statistical-computing name -- `Python`,
#' `Java`, `JavaScript`, `Rust`, `MATLAB`, `SAS`, `Stata` and more -- in `Title`
#' or `Description` that CRAN asks to see single-quoted. This is the language
#' counterpart to [lab_software_names()]: both are policy-tier
#' quoting checks, kept separate because a language name and a package name are
#' different kinds of thing. `R` itself is never flagged in either form. No
#' authority names it, and a bare `R` and a quoted `'R'` both clear CRAN, so
#' checktor takes no position on which you write. Single-letter or common-word
#' names (`C`, `Go`, `Swift`) are left out because they cannot be told from
#' ordinary prose.
#'
#' Data, markup and query formats (`JSON`, `HTML`, `YAML`, `SQL`, `Markdown`,
#' `LaTeX` and the like) and the languages CRAN packages write either way (`C++`,
#' `Fortran`, `Tcl`) are not flagged here. A census of CRAN in September 2026
#' found that packages accepted at new-package review in the previous 18 months
#' wrote them bare 62% of the time, against 28% for the languages this check
#' covers, so a bare one is not a policy finding. [lab_format_names()] reports them when you
#' ask.
#'
#' A package can extend the list through `Config/checktor/language_names` in its own
#' DESCRIPTION.
#'
#' Each occurrence is judged on its own, as in [lab_software_names()]: a term
#' inside a quoted longer name such as `'MATLAB Runtime'` or `'AWS Python SDK'` is
#' quoted, and so is one in a web address, a `<doi:...>` or a double-quoted book
#' title.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", asks for single quotes around other software;
#' checktor applies the same to programming-language and markup names. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_software_names()], [lab_format_names()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_language_names(pkg, verbose = FALSE)$passed
lab_language_names <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  language_names <- check_vocab(
    checktor_config(path),
    "language_names",
    c(
      # general-purpose languages
      "Python", "Java", "JavaScript", "TypeScript", "C#",
      "Perl", "PHP", "Ruby", "Rust", "Julia", "Scala",
      "Kotlin", "Haskell", "Lua",
      # statistical / numerical computing environments
      "MATLAB", "SAS", "Stata", "SPSS", "Octave", "Mathematica"
    )
  )
  # Single-letter names (C, D) and common English words (Go, Swift) are left out:
  # at policy severity their false positives would outweigh the catch. A package
  # that wants them can add them via Config/checktor/language_names.
  #
  # Formats and the languages CRAN writes both ways (JSON, HTML, SQL, C++, Tcl, ...)
  # live in lab_format_names(), on request: most accepted packages write them
  # bare, so a bare one here would fail a clean package for nothing CRAN enforces.
  #
  # The same matcher as software_names: a term inside a quoted longer name
  # ('AWS Python SDK', 'MATLAB Runtime') is quoted, and one quoted 'Python' no
  # longer excuses a bare Python elsewhere in the field.
  issues <- bare_name_issues(desc, language_names, "should be in single quotes")

  passed <- length(issues) == 0
  emit_issue_summary(
    issues,
    verbose,
    "Programming-language names appear properly formatted",
    "Potential programming-language name formatting issues",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Language names check")
}

#' Diagnose Bare Format and Markup Names in DESCRIPTION
#'
#' Flags a data, markup, typesetting or query format name -- `JSON`, `HTML`,
#' `XML`, `CSS`, `YAML`, `TOML`, `Markdown`, `LaTeX`, `TeX` or `SQL` -- or one of
#' the languages CRAN packages write either way (`C++`, `Fortran`, `Tcl`) that
#' appears in `Title` or `Description` without single quotes. It runs only when
#' you call it, for a maintainer who wants the quoting consistent. CRAN accepts
#' these names bare, so a finding here never counts against a clean result.
#'
#' Occurrences are judged as in [lab_software_names()]: a name inside a quoted
#' longer name such as `'R Markdown'` or `'JSON-stat'` is quoted, and so is one in
#' a web address or a double-quoted span. A format name alone in double quotes,
#' such as `"JSON"`, is therefore reported by no check, by design: double quotes
#' are the wrong kind for a name, but CRAN accepts the name with no quotes at all,
#' so [lab_description_quoted_quotes()] leaves it alone too. A package can extend
#' the list through `Config/checktor/format_names` in its own DESCRIPTION.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file)
#' asks for single quotes around "other packages and external software", and a
#' format is not software. A census of CRAN in September 2026 found that packages
#' accepted at new-package review in the previous 18 months wrote these names bare
#' 62% of the time, against 28% for the languages [lab_language_names()] covers, so
#' this is a matter of style and sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_language_names()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/format_names_bad.txt",
#'                                  show_content = FALSE)
#' lab_format_names(pkg, verbose = FALSE)$issues
lab_format_names <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  # Split out of language_names (#16). These are formats and specifications rather
  # than software, or languages whose names CRAN packages write quoted and bare
  # about equally, and a census of recently accepted packages found most of them
  # bare. C, Go and the other names that read as ordinary words stay out here too.
  format_names <- check_vocab(
    checktor_config(path),
    "format_names",
    c(
      # markup, typesetting and data formats
      "HTML", "CSS", "XML", "JSON", "YAML", "TOML", "Markdown", "LaTeX", "TeX",
      # query language
      "SQL",
      # languages written both ways on CRAN
      "C++", "Fortran", "Tcl"
    )
  )
  issues <- bare_name_issues(desc, format_names, "is not in single quotes")

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Format and markup names are single-quoted",
    "Format and markup names written without single quotes",
    "Treatment: Optional. CRAN accepts these names bare; quote them only to keep the quoting consistent throughout the Title and Description",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Format names check")
}

#' Diagnose Unexplained Acronyms in DESCRIPTION
#'
#' Flags an acronym in `Description` that is never spelled out. A parenthetical gloss in either order counts as explained.
#'
#' A name in single quotes, straight or typographic, is not read as an acronym,
#' so `'YAML'` or `'MATLAB'` written as [lab_language_names()] and
#' [lab_format_names()] ask is not reported here. Nor is anything inside a web
#' address, a `<doi:...>`, a function call or a quotation in double quotes,
#' straight or typographic, such as the title of an article.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Explaining Acronyms](https://contributor.r-project.org/cran-cookbook/description_issues.html#explaining-acronyms).
#' Reviewers ask for an acronym to be spelled out once, but nothing enforces it,
#' which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_acronyms(pkg, verbose = FALSE)$passed
lab_acronyms <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  text <- desc[["Description"]]
  if (is.null(text) || is.na(text) || !nzchar(text)) {
    return(checktor_check_result(TRUE, character(0), "Acronyms check"))
  }

  # Candidates come from the prose a reader sees unquoted, with the same spans
  # blanked that the quoting checks skip: single-quoted names, web addresses,
  # DOIs and function calls. language_names and format_names ask for 'MATLAB' and
  # 'YAML' in single quotes, so reading a quoted name as an unexplained acronym
  # had checktor contradict itself whichever way the user wrote it.
  #
  # Typographic quotes (U+2018/U+2019 and U+201C/U+201D) are skipped too, here
  # only. The quoting checks keep to CRAN's ASCII pattern, but an acronym in curly
  # quotes has been quoted as surely as 'GLMM' or "GLMM", and the gloss detection
  # below already reads a curly closing quote. A curly quote follows the rules of
  # the straight one: it opens after a blank or punctuation and not at an elided
  # year (\u201890s), and it closes where a quote ends the word or, for a single
  # quote, takes a plural or possessive s, so the apostrophe in package\u2019s
  # closes nothing. Word processors may curl one side only, so a straight quote
  # can close a curly one (\u2018CFO').
  typographic <- c(
    single = paste0(
      "(?<=[ \t[:punct:]])\u2018(?![0-9]{2}s?(?![[:alnum:]]))",
      "[^\u2018\u2019]*?['\u2019](?=[ \t[:punct:]]|s(?![[:alnum:]]))"
    ),
    double = "(?<=[ \t[:punct:]])\u201c[^\u201c\u201d]*?[\"\u201d](?=[ \t[:punct:]])"
  )
  prose <- blank_ignored_spans(text)
  for (re in typographic) {
    prose <- gsub(re, " ", prose, perl = TRUE)
  }
  acronyms <- regmatches(prose, gregexpr("\\b[A-Z]{2,6}\\b", prose))[[1]]
  # "CMD" is here because it is not an acronym anyone expands, it is part of the
  # literal command name `R CMD check`, which turns up in any Description that
  # talks about the standard toolchain.
  common_abbrevs <- check_vocab(
    checktor_config(path),
    "acronyms",
    c(
      "API",
      "SQL",
      "HTML",
      "CSS",
      "PDF",
      "XML",
      "JSON",
      "YAML",
      "TOML",
      "URL",
      "HTTP",
      "HTTPS",
      "FTP",
      "GUI",
      "CLI",
      "CRAN",
      "ID",
      "OS",
      "TLS",
      "SSL",
      "UTF",
      "ASCII",
      "CMD"
    )
  )
  candidates <- setdiff(unique(acronyms), common_abbrevs)

  # An acronym is not "unexplained" when the Description spells it out with the
  # conventional parenthetical gloss, in either order:
  #   "principal component analysis (PCA)"  or  "PCA (principal component ...)".
  # Whitespace is collapsed first so a line-wrapped gloss is still detected.
  # The `word (ACRONYM)` pattern is anchored to a preceding word char so a bare
  # "(PCA)" with no expansion in front of it is still flagged. A closing quote may
  # sit between the two, because the expansion is often a software name and
  # `software_names` requires those to be quoted -- "'WebAssembly' (WASM)" is a
  # gloss, and reading it as an unexplained acronym would have checktor contradict
  # its own policy check.
  flat <- gsub("\\s+", " ", text)
  explained <- vapply(
    candidates,
    function(a) {
      expansion_then_acronym <- grepl(
        paste0("\\w['\u2019\"]?\\s*\\(", a, "\\)"),
        flat,
        perl = TRUE
      )
      acronym_then_expansion <- grepl(
        paste0("\\b", a, "\\b\\s*\\("),
        flat,
        perl = TRUE
      )
      expansion_then_acronym || acronym_then_expansion
    },
    logical(1)
  )
  unexplained <- candidates[!explained]

  passed <- length(unexplained) == 0
  if (verbose) {
    if (passed) {
      cli::cli_alert_success("No unexplained acronyms found")
    } else {
      cli::cli_alert_warning(
        "Potential unexplained acronyms: {.val {paste(unexplained, collapse = ', ')}}"
      )
      cli::cli_text("{.emph Treatment: Consider explaining these acronyms}")
    }
  }
  checktor_check_result(passed, unexplained, "Acronyms check")
}

#' Diagnose the Authors@R Field
#'
#' Flags a missing `Authors@R`, and an unfilled `usethis` template such as `person("First", "Last", ...)`, which is a hard CRAN rejection that `R CMD check` says nothing about.
#'
#' The field is evaluated without running any code it contains: only
#' `person()`, `as.person()`, `c()`, `list()`, `paste()`, `paste0()` and `(`
#' resolve, the calls R's own reader allows from R 4.6.0 on. Every other call
#' in the field is reported, since `R CMD build` refuses it as a malformed
#' `Authors@R` field. That includes a namespaced `utils::person()` and a
#' function in parentheses, as in `(c)(...)`, which are still read so the
#' other checks see their roles.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' treats a placeholder or malformed `Authors@R`, including a missing
#' maintainer, as a rejection. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_authors(pkg, verbose = FALSE)$passed
lab_authors <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  # Two things are checked here, and only one of them overlaps with R.
  #
  # (a) A MISSING Authors@R. R CMD check does raise a CRAN-incoming NOTE for this,
  #     but it is only a NOTE. checktor treats it as a failure, which is the
  #     stricter and more useful signal before a submission, so it stays.
  #
  # (b) An unfilled usethis template, e.g.
  #       person("First", "Last", , "you@example.com", role = c("aut", "cre"))
  #     R CMD check says NOTHING about this: the field is present, so it passes.
  #     A CRAN reviewer then rejects it. This is a genuine gap, and it is the one
  #     that mattered in practice -- pcaR2 shipped exactly this and checktor's
  #     presence-only check waved it through.
  issues <- character(0)

  has_authors_r <- !is.null(desc[["Authors@R"]]) && nzchar(desc[["Authors@R"]])
  if (!has_authors_r) {
    issues <- c(issues, "Missing Authors@R field")
  }

  placeholders <- c(
    "First",
    "Last",
    "First Last",
    "Your Name",
    "YOUR NAME",
    "you@example.com",
    "your@email.com",
    "first.last@example.com"
  )
  # One issue per field, listing the placeholders found. The same template leaks
  # into Authors@R, Author and Maintainer at once, so reporting every (field,
  # placeholder) pair would turn a single mistake into eight findings.
  for (field in c("Authors@R", "Author", "Maintainer")) {
    text <- desc[[field]]
    if (is.null(text) || !nzchar(text)) {
      next
    }
    hit <- placeholders[vapply(
      placeholders,
      function(ph) {
        grepl(paste0("[\"']", ph, "[\"']"), text) ||
          grepl(
            paste0("\\b", gsub("([.@])", "\\\\\\1", ph), "\\b"),
            text,
            perl = TRUE
          )
      },
      logical(1)
    )]
    if (length(hit) > 0L) {
      issues <- c(
        issues,
        paste0(
          field,
          ": unfilled template placeholder (",
          paste(sprintf("\"%s\"", hit), collapse = ", "),
          ")"
        )
      )
    }
  }

  # (c) Structural validity, mirroring CRAN's own Authors@R validator
  #     (tools:::.check_package_description_authors_at_R_field, strict mode). A
  #     present-but-broken field passes R CMD check's presence test yet is a
  #     reviewer rejection: a person with no name, a person with no role, or no
  #     maintainer (cre) at all. Parsed with public R via parse_authors_at_r().
  pa <- parse_authors_at_r(desc)
  # From R 4.6.0 on, R's own reader allows only person(), as.person(), c(),
  # list(), paste(), paste0() and `(` in the field, each called by its bare
  # name, and R CMD build stops on anything else as a "Malformed Authors@R
  # field". Every call it would refuse is named in one issue, whether the
  # parser could still read the field (utils::person(), (c)(...)) or not.
  refused <- unique(pa$refused)
  if (length(refused) > 0L) {
    n <- length(refused)
    named <- if (n == 1L) {
      refused
    } else {
      paste(paste(refused[-n], collapse = ", "), "and", refused[[n]])
    }
    issues <- c(
      issues,
      paste0(
        "Authors@R calls ",
        named,
        ", which R CMD build refuses from R 4.6.0 on as a malformed field: ",
        "call only person(), as.person(), c(), list(), paste() and paste0(), ",
        "by their bare names"
      )
    )
  }
  if (!is.null(pa$error)) {
    issues <- c(issues, paste0("Authors@R does not parse: ", pa$error))
  } else if (!is.null(pa$persons)) {
    persons <- pa$persons
    idx <- seq_along(persons)
    if (
      any(vapply(
        idx,
        function(i) {
          is.null(persons[i]$given) && is.null(persons[i]$family)
        },
        logical(1)
      ))
    ) {
      issues <- c(issues, "Authors@R has a person entry with no name")
    }
    if (any(vapply(idx, function(i) is.null(persons[i]$role), logical(1)))) {
      issues <- c(issues, "Authors@R has a person entry with no role")
    }
    roles <- unlist(lapply(idx, function(i) persons[i]$role))
    if (!("cre" %in% roles)) {
      issues <- c(
        issues,
        "Authors@R declares no maintainer (a person with role \"cre\")"
      )
    }
  }

  issues <- unique(issues)

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "{.code Authors@R} present and filled in",
    "Problems in the author fields",
    "Treatment: Add Authors@R, replace any usethis template placeholder with the real name and email, and give every person a name and role with one maintainer (cre)"
  )
  checktor_check_result(passed, issues, "Authors@R field check")
}

# CRAN's incoming rules for links in the Description, copied from
# tools:::.check_package_CRAN_incoming (R 4.6.1) rather than called through
# `:::`. R joins the alternatives of a rule with "|" and applies them, case
# sensitive or not as given here, to each line of strwrap(Description). A test
# holds `r_patterns` to R's own source. `label` opens the finding, and R's own
# message is the one its NOTE prints.
DESCRIPTION_REFERENCE_RULES <- list(
  bad_urls = list(
    r_patterns = "(^|[^</\"])https?://",
    ignore_case = FALSE,
    label = "URL not enclosed in angle brackets (<...>)",
    r_message = "Please enclose URLs in angle brackets (<...>)."
  ),
  bad_dois = list(
    r_patterns = c("https?:.*doi.org/", "(^|[^<])doi:", "<doi[^:]", "<10[.]"),
    ignore_case = TRUE,
    label = "DOI not written as <doi:prefix/suffix>",
    r_message = "Please write DOIs as <doi:prefix/suffix>."
  ),
  replace_by_doi = list(
    r_patterns = "<https?:.*/10\\.\\d{4,}/.*?>",
    ignore_case = TRUE,
    label = "Publisher link to a DOI, which CRAN asks to see as <doi:prefix/suffix>",
    r_message = paste(
      "Please use permanent DOI markup for linking to publications as in",
      "<doi:prefix/suffix>."
    )
  ),
  bad_arxiv = list(
    r_patterns = c(
      "<(arXiv|arxiv):(([[:alpha:].-]+/)?[[:digit:].]+)(v[[:digit:]]+)?([[:space:]]*\\[[^]]+\\])?>",
      "https?://arxiv.org",
      "(^|[^<])arxiv:",
      "<arxiv[^:]"
    ),
    ignore_case = TRUE,
    label = "arXiv reference, which CRAN asks to see as its arXiv DOI",
    r_message = paste(
      "Please refer to arXiv e-prints via their arXiv DOI",
      "<doi:10.48550/arXiv.YYMM.NNNNN>."
    )
  )
)

# The whitespace-delimited text around each match of `pattern` in `lines`, so a
# finding quotes the reference itself rather than the whole wrapped line.
# Trailing sentence punctuation is dropped.
reference_spans <- function(lines, pattern, ignore_case = FALSE) {
  spans <- character(0)
  for (line in lines) {
    m <- gregexpr(pattern, line, ignore.case = ignore_case)[[1L]]
    if (m[1L] < 1L) {
      next
    }
    tok <- gregexpr("[^[:space:]]+", line)[[1L]]
    tok_end <- tok + attr(tok, "match.length") - 1L
    for (i in seq_along(m)) {
      first <- m[i]
      last <- m[i] + attr(m, "match.length")[i] - 1L
      hit <- tok_end >= first & tok <= last
      if (any(hit)) {
        span <- substr(line, min(tok[hit]), max(tok_end[hit]))
        # The sentence's punctuation is not part of the reference.
        spans <- c(spans, sub("[.,;]+$", "", span))
      }
    }
  }
  unique(spans)
}

# The arXiv DOI for a span naming an arXiv e-print, as "<doi:10.48550/arXiv.ID>",
# or "" when no identifier can be read from it. A version suffix is dropped, as
# the DOI names the e-print rather than one version of it.
arxiv_doi_for <- function(span) {
  rx <- "(?i)arxiv(?:\\.org/(?:abs|pdf)/|:)((?:[a-z.-]+/)?[0-9]+(?:\\.[0-9]+)*)"
  m <- regmatches(span, regexec(rx, span, perl = TRUE))[[1L]]
  if (length(m) < 2L) {
    return("")
  }
  paste0("<doi:10.48550/arXiv.", sub("\\.$", "", m[2L]), ">")
}

#' Diagnose Reference Formatting in DESCRIPTION
#'
#' Flags the links in the `Description` that CRAN's incoming check NOTEs,
#' applying its own rules to the same wrapped lines R reads:
#'
#' * a URL not enclosed in angle brackets, which should read `<https://...>`;
#' * a DOI not written as `<doi:prefix/suffix>`, such as a `https://doi.org/`
#'   link, a bare `doi:`, `<doi` with no colon, or `<10.xxxx/...>`;
#' * a publisher link that embeds a DOI, such as
#'   `<https://onlinelibrary.wiley.com/doi/10.1002/...>`, reported only when no
#'   DOI is malformed, as R does;
#' * an arXiv id or link, such as `<arXiv:1509.03700>` or
#'   `<https://arxiv.org/abs/...>`, which should be the e-print's arXiv DOI,
#'   `<doi:10.48550/arXiv.1509.03700>`.
#'
#' It also flags a reference with no closing `>`, which CRAN's page does not
#' render as a link. Each rule is one finding, quoting every reference that
#' breaks it. A space after the colon, as in `<doi: 10.1000/xyz>`, is left
#' alone: R does not NOTE it and CRAN's page links it all the same.
#'
#' @section Source:
#' The [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' run by `R CMD check --as-cran` NOTEs each of the four forms, with "Please
#' enclose URLs in angle brackets (<...>).", "Please write DOIs as
#' <doi:prefix/suffix>.", "Please use permanent DOI markup for linking to
#' publications as in <doi:prefix/suffix>." and "Please refer to arXiv e-prints
#' via their arXiv DOI <doi:10.48550/arXiv.YYMM.NNNNN>.". The
#' [submission checklist](https://cran.r-project.org/web/packages/submission_checklist.html)
#' says "arXiv preprints should be referred to via their arXiv DOI", and the
#' Cookbook's [References](https://contributor.r-project.org/cran-cookbook/description_issues.html#references)
#' recipe asks for "angle brackets for auto-linking". `devtools::check()` turns the incoming check off, so these
#' usually surface first on win-builder or at CRAN. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/references_bad.txt",
#'                                  show_content = FALSE)
#' lab_references(pkg, verbose = FALSE)$issues
lab_references <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  text <- dcf_field(desc, "Description")
  issues <- character(0)
  if (!is.null(text) && !is.na(text) && nzchar(trimws(text))) {
    # As R reads it: one line, then wrapped. The width is fixed at the one R
    # uses in an 80-column session, so the result does not depend on the console.
    flat <- gsub("[\n\t]", " ", trimws(text))
    lines <- strwrap(flat, width = 72L)

    report <- function(rule, spans = NULL) {
      if (is.null(spans)) {
        spans <- reference_spans(
          lines,
          paste(rule$r_patterns, collapse = "|"),
          rule$ignore_case
        )
      }
      if (length(spans) == 0L) {
        return(character(0))
      }
      paste0(rule$label, ": ", paste(spans, collapse = ", "))
    }
    rules <- DESCRIPTION_REFERENCE_RULES
    issues <- c(issues, report(rules$bad_urls))
    dois <- report(rules$bad_dois)
    # R reports a publisher link only when no DOI is malformed (an else-branch).
    issues <- c(
      issues,
      if (length(dois)) dois else report(rules$replace_by_doi)
    )
    arxiv <- reference_spans(
      lines,
      paste(rules$bad_arxiv$r_patterns, collapse = "|"),
      TRUE
    )
    if (length(arxiv)) {
      fixes <- vapply(arxiv, arxiv_doi_for, "", USE.NAMES = FALSE)
      arxiv <- ifelse(nzchar(fixes), paste0(arxiv, " (write ", fixes, ")"), arxiv)
    }
    issues <- c(issues, report(rules$bad_arxiv, arxiv))

    # A space after the colon, as in <doi: 10.1000/xyz>, is not reported. The
    # Cookbook asks for none, but R does not NOTE it, CRAN's page renders it as a
    # working link (tools:::.DESCRIPTION_to_HTML allows the space), and 76 of the
    # packages CRAN published in the year to September 2026 carry one.
    #
    # An unclosed reference, with no '>' anywhere after the opening, is read from
    # the flat text so a reference split by the wrap is still whole. R does not
    # NOTE it, but CRAN's page renders a reference as a link only when it is
    # closed. A SICI DOI has angle brackets of its own, so the next '<' is no
    # sign the reference ended.
    open <- regmatches(
      flat,
      gregexpr("<(doi|https?|arxiv):[^>]*$", flat, ignore.case = TRUE)
    )[[1L]]
    if (length(open)) {
      issues <- c(
        issues,
        paste0(
          "Reference with no closing '>': ",
          sub("[.,;]+$", "", sub("[[:space:]].*", "", open))
        )
      )
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "References in Description are in CRAN's form",
    "References in Description are not in CRAN's form",
    paste0(
      "Treatment: Write links as <https://...>, DOIs as <doi:prefix/suffix> ",
      "and arXiv e-prints as <doi:10.48550/arXiv.ID>, each closed with '>'"
    )
  )
  checktor_check_result(passed, issues, "References check")
}

#' Diagnose the DESCRIPTION Date Field
#'
#' Flags a `Date` field that is not ISO 8601 `yyyy-mm-dd`, is over a month old, or lies in the future. Mirrors the CRAN incoming check; an absent `Date` field (the common, preferred case) passes.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says "the 'yyyy-mm-dd' format of the
#' ISO 8601 standard is strongly recommended"; the
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' also flags a stale or future date. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_date_format(pkg, verbose = FALSE)$passed
lab_date_format <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  date <- desc[["Date"]]
  issues <- character(0)
  if (!is.null(date) && !is.na(date) && nzchar(trimws(date))) {
    date <- trimws(date)
    dd <- as.Date(date, "%Y-%m-%d")
    if (is.na(dd)) {
      issues <- paste0("Date is not in ISO 8601 yyyy-mm-dd format: ", date)
    } else if (dd < Sys.Date() - 31) {
      issues <- paste0("Date is over a month old: ", date)
    } else if (dd > Sys.Date() + 7) {
      issues <- paste0("Date is in the future: ", date)
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "{.field Date} field is absent or current",
    "DESCRIPTION Date field problem",
    "Treatment: use ISO 8601 yyyy-mm-dd and keep it current, or drop the Date field",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Date field check")
}

#' Diagnose a DESCRIPTION Encoding Other Than UTF-8
#'
#' Flags an `Encoding` that is anything but exactly `UTF-8`, which is the test
#' CRAN's incoming check applies. `latin1` and `latin2` are still legal R, but
#' CRAN NOTEs them as deprecated, and the comparison is case-sensitive, so a
#' lower-case `utf-8` is NOTEd too. An absent `Encoding` passes.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says a non-ASCII DESCRIPTION "should contain an
#' 'Encoding' field"; the
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' run by `R CMD check --as-cran` NOTEs any value but `UTF-8` with "Package
#' encoding '...' is deprecated. Please change to UTF-8 for non-ASCII content."
#' See `vignette("check-sources", package = "checktor")` for how every check
#' maps to its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_encoding_utf8(pkg, verbose = FALSE)$passed
lab_encoding_utf8 <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  enc <- dcf_field(desc, "Encoding")
  issues <- character(0)
  # R's own test, from tools:::.check_package_CRAN_incoming:
  #     if (!is.na(enc <- meta["Encoding"]) && (enc != "UTF-8"))
  # An exact, case-sensitive comparison. latin1 and latin2 are portable in the
  # sense Writing R Extensions uses, but CRAN now calls them deprecated.
  if (!is.null(enc) && !is.na(enc) && !identical(trimws(enc), "UTF-8")) {
    enc <- trimws(enc)
    issues <- paste0(
      "Encoding is \"", enc, "\"; CRAN's incoming check says package ",
      "encoding '", enc, "' is deprecated and asks for UTF-8"
    )
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "{.field Encoding} is UTF-8 or unset",
    "Encoding other than UTF-8 declared",
    "Treatment: re-encode sources as UTF-8 and set Encoding: UTF-8",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Encoding field check")
}

#' Diagnose the DESCRIPTION Version Field
#'
#' Flags a `Version` with a leading-zero component or a suspiciously large one, mirroring CRAN's `version_with_leading_zeroes` and `version_with_large_components` incoming checks. A calendar-year component (e.g. a dated `2026.01` version) is exempt.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says a `Version` is "a sequence of at
#' least two ... non-negative integers"; the
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' flags a leading zero or an implausible value. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_version_format(pkg, verbose = FALSE)$passed
lab_version_format <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  ver <- desc[["Version"]]
  issues <- character(0)
  if (!is.null(ver) && !is.na(ver) && nzchar(trimws(ver))) {
    ver <- trimws(ver)
    if (grepl("(^|[.-])0[0-9]+", ver) && !grepl("^[0-9]{4}[.-][0-9]{2}", ver)) {
      issues <- c(
        issues,
        paste0("Version has a component with a leading zero: ", ver)
      )
    }
    comps <- tryCatch(unlist(package_version(ver)), error = function(e) NULL)
    if (is.null(comps)) {
      issues <- c(
        issues,
        paste0("Version is not a valid package version: ", ver)
      )
    } else {
      # A component is only "suspiciously large" if it is neither a plausible
      # calendar year (a dated version such as 2025.4) nor the .9000-series dev
      # suffix that usethis::use_dev_version() appends. checktor runs on packages
      # under development, so flagging a bare 0.1.0.9000 would be noise.
      this_year <- as.integer(format(Sys.Date(), "%Y"))
      is_year <- comps >= 1900 & comps <= this_year + 1L
      is_dev <- seq_along(comps) == length(comps) & comps >= 9000
      if (any(comps >= 1234 & !is_year & !is_dev)) {
        issues <- c(
          issues,
          paste0("Version has a suspiciously large component: ", ver)
        )
      }
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "{.field Version} is well formed",
    "DESCRIPTION Version field problem",
    "Treatment: use a numeric x.y.z version without leading zeroes"
  )
  checktor_check_result(passed, issues, "Version field check")
}

# Validate an ORCID iD: the canonical 16-digit form plus the ISO 7064 MOD 11-2
# checksum, mirroring tools:::.ORCID_iD_is_valid. Accepts a bare id or one
# wrapped in an orcid.org URL.
orcid_id_is_valid <- function(x) {
  rx <- "^<?((https?://|)orcid.org/)?([0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[X0-9])>?$"
  if (is.na(x) || !grepl(rx, x)) {
    return(FALSE)
  }
  core <- sub(rx, "\\3", x)
  d <- strsplit(gsub("-", "", core), "")[[1L]]
  total <- sum(as.numeric(d[-16L]) * 2^(15L:1L))
  res <- (12 - (total %% 11)) %% 11
  z <- if (res == 10) "X" else as.character(res)
  identical(z, d[16L])
}

# Validate a ROR ID by shape: nine characters after an optional ror.org/ prefix,
# mirroring tools:::.ROR_ID_variants_regexp.
ror_id_is_valid <- function(x) {
  !is.na(x) && grepl("^<?((https://|)ror.org/)?(.{9})>?$", x)
}

#' Diagnose Author Identifier Formatting
#'
#' Validates ORCID and ROR identifiers carried in `Authors@R` person `comment` fields, mirroring CRAN's `bad_ORCID_iDs` and `bad_ROR_IDs` incoming checks. ORCID iDs are checked against their checksum, ROR IDs against their shape.
#'
#' An `Authors@R` that cannot be read has no identifiers to judge, so the check
#' is reported as skipped and [lab_authors()] reports the field.
#'
#' @section Source:
#' The [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' run by `R CMD check --as-cran` NOTEs a malformed ORCID or ROR
#' identifier in `Authors@R`. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_identifier_format(pkg, verbose = FALSE)$passed
lab_identifier_format <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  pa <- parse_authors_at_r(desc)
  # A field R cannot read has no identifiers to judge. lab_authors() reports the
  # field itself, so this check says it did not run rather than passing it.
  if (!is.null(pa$error)) {
    return(checktor_skipped_result(
      "Author identifier check",
      "Authors@R could not be read"
    ))
  }
  issues <- character(0)
  if (!is.null(pa$persons)) {
    persons <- pa$persons
    for (i in seq_along(persons)) {
      cm <- persons[i]$comment
      if (is.null(cm) || length(cm) == 0L) {
        next
      }
      nms <- toupper(names(cm))
      for (j in seq_along(cm)) {
        id <- unname(cm[j])
        if (identical(nms[j], "ORCID") && !orcid_id_is_valid(id)) {
          issues <- c(issues, paste0("Invalid ORCID iD in Authors@R: ", id))
        } else if (identical(nms[j], "ROR") && !ror_id_is_valid(id)) {
          issues <- c(issues, paste0("Invalid ROR ID in Authors@R: ", id))
        }
      }
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Author identifiers are well formed",
    "Malformed author identifier",
    "Treatment: use a valid ORCID iD (0000-0000-0000-0000) or ROR ID"
  )
  checktor_check_result(passed, issues, "Author identifier check")
}

#' Diagnose Description Length
#'
#' Flags a `Description` of fewer than 10 words.
#'
#' @section Source:
#' The CRAN Cookbook covers this under
#' [Description Length](https://contributor.r-project.org/cran-cookbook/general_issues.html#description-length).
#' A one-line `Description` is thin and reviewers ask for more, a convention rather
#' than a rule, which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_description_length(pkg, verbose = FALSE)$passed
lab_description_length <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  text <- desc[["Description"]]
  if (is.null(text) || !nzchar(text)) {
    if (verbose) {
      cli::cli_alert_warning("No Description field found")
    }
    return(checktor_check_result(
      FALSE,
      character(0),
      "Description length check"
    ))
  }

  # read.dcf returns multi-line fields with embedded newlines; treat \n as space
  flat <- gsub("\\s+", " ", text)
  sentences <- length(strsplit(flat, "[.!?]+\\s+|[.!?]+$")[[1]])
  word_count <- length(strsplit(trimws(flat), "\\s+")[[1]])

  # Word count only. The old rule also demanded 2+ SENTENCES, which no authority
  # supports and which flagged renderthis for a perfectly complete 31-word
  # single-sentence Description. What is genuinely thin is a Description that
  # says almost nothing ("Does stuff."), and words measure that; punctuation
  # does not.
  passed <- word_count >= 10
  issues <- if (passed) {
    character(0)
  } else {
    paste0(
      "Description too short: ",
      word_count,
      " words"
    )
  }

  if (verbose) {
    if (passed) {
      cli::cli_alert_success("Description length appears adequate")
    } else {
      cli::cli_alert_warning(
        "Description may be too short: {.val {word_count}} words"
      )
      cli::cli_text(
        "{.emph Treatment: Say what the package does, in a sentence or two}"
      )
    }
  }
  checktor_check_result(
    passed,
    issues,
    "Description length check",
    sentences = sentences,
    words = word_count
  )
}

# Double quotes in the Title and Description should only enclose quotations.
#' Diagnose Double-Quoted Software Names
#'
#' Flags a software name in double quotes in `Title` or `Description`. Writing R Extensions reserves double quotes for quotations and requires single quotes for software names, so scare-quoted jargon is left alone. A lower-case span matches only a name written in lower case, such as `shiny`, so an English `"rust"` or a parameter `"r"` is not read as `Rust` or `R`.
#'
#' The names are those [lab_software_names()] and [lab_language_names()] ask to
#' see in single quotes, and a few more. Format names such as `JSON` or `HTML`,
#' which CRAN accepts bare, are not among them, so one in double quotes is not
#' reported; [lab_format_names()] reports them bare, on request.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", reserves double quotes for book
#' titles and similar; software names take single quotes. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_description_quoted_quotes(pkg, verbose = FALSE)$passed
lab_description_quoted_quotes <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  # Both fields. lab_software_names() and lab_language_names() read a
  # double-quoted span in either as a quotation, so a name alone in double quotes
  # in the Title is reported here or nowhere.
  quoted <- list()
  for (field in c("Title", "Description")) {
    text <- desc[[field]]
    if (is.null(text) || is.na(text) || !nzchar(text)) {
      next
    }
    quoted[[field]] <- regmatches(text, gregexpr("\"[^\"]*\"", text))[[1]]
  }
  if (length(unlist(quoted)) == 0L) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Description double-quotes check"
    ))
  }
  # Writing R Extensions, verbatim: "double quotes should be used for quotations
  # (including titles of books and articles), and single quotes for non-English
  # usage, including names of other packages and external software."
  #
  # So the rule is about SOFTWARE NAMES in double quotes. The old test flagged any
  # double-quoted phrase of three words or fewer, which caught ordinary scare-
  # quoted jargon such as the "labeled", "no choice" and "alternative-specific
  # designs" that appear on CRAN today. Those ARE the quotations double quotes are
  # reserved for. Only flag a double-quoted name we can actually recognise as
  # software.
  # The names a package adds to either quoting check count too, since those checks
  # leave a name alone in double quotes to this one.
  config <- checktor_config(path)
  extra_names <- c(config$software_names, config$language_names)
  issues <- character(0)
  for (field in names(quoted)) {
    for (q in quoted[[field]]) {
      body <- trimws(gsub("^\"|\"$", "", q))
      if (is_software_name(body, extra_names)) {
        issues <- c(
          issues,
          paste0(
            field,
            ": ",
            q,
            " is a software name in double quotes (Writing R Extensions ",
            "reserves double quotes for quotations; use single quotes for ",
            "software and package names)"
          )
        )
      }
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Title and Description double-quote usage looks OK",
    "Title or Description double-quotes a software name",
    "Treatment: Use single quotes for software and package names",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Description double-quotes check")
}

# Software and package names that Writing R Extensions requires to be in SINGLE
# quotes. Deliberately a closed list: guessing from shape would re-introduce the
# false positives on scare-quoted English that this check used to produce.
#
# It holds every name lab_software_names() and lab_language_names() look for by
# default. Those read a double-quoted span as a quotation, so a name alone in
# double quotes is reported here or nowhere. The names lab_format_names() covers
# (JSON, HTML, SQL, C++, ...) are not here: CRAN accepts them bare (#16), so double
# quotes around one are not a policy finding either.
SOFTWARE_NAMES <- c(
  "R",
  "Python",
  "Java",
  "C",
  "JavaScript",
  "TypeScript",
  "C#",
  "Perl",
  "PHP",
  "Ruby",
  "Rust",
  "Scala",
  "Kotlin",
  "Haskell",
  "Lua",
  "Octave",
  "Mathematica",
  "Excel",
  "Stata",
  "SAS",
  "SPSS",
  "MATLAB",
  "Julia",
  "Docker",
  "Git",
  "GitHub",
  "Quarto",
  "Pandoc",
  "shiny",
  "ggplot2",
  "dplyr",
  "tidyr",
  "purrr",
  "tibble",
  "plotly",
  "tidyverse",
  "knitr",
  "rmarkdown",
  "Rcpp",
  "data.table",
  "Stan",
  "JAGS",
  "BUGS",
  "TensorFlow",
  "PyTorch",
  "Keras",
  "WebAssembly",
  "WASM",
  "webR",
  "Shinylive"
)

# Case is ignored, so "Matlab" is MATLAB and "Shiny" is shiny, except in one
# direction: a name is a proper noun, and a span in lower case is an ordinary word
# or a symbol unless the name itself is written in lower case. An English "rust",
# BFF's hyperparameter "r" and R2WinBUGS's class "bugs" are not Rust, R and BUGS,
# and at policy tier reading them as such was a false finding.
is_software_name <- function(x, extra = character(0)) {
  if (!nzchar(x)) {
    return(FALSE)
  }
  names <- c(SOFTWARE_NAMES, extra)
  if (identical(x, tolower(x))) {
    names <- names[names == tolower(names)]
  }
  any(tolower(x) == tolower(names))
}

# Title should not start with "A ", "An ", or "The ".
#' Diagnose Title Starting With an Article
#'
#' Flags a `Title` beginning with `A`, `An`, or `The`.
#'
#' @section Source:
#' No rule. This was a mis-transplant of a real CRAN rule and is kept
#' callable but off by default. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_title_starts_with_article(pkg, verbose = FALSE)$passed
lab_title_starts_with_article <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  title <- desc[["Title"]]
  if (is.null(title) || !nzchar(title)) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Title starts-with-article check"
    ))
  }
  if (grepl("^(A|An|The)\\s+", title, perl = TRUE)) {
    issues <- "Title starts with an article (A/An/The)"
    passed <- FALSE
  } else {
    issues <- character(0)
    passed <- TRUE
  }
  emit_issue_summary(
    issues,
    verbose,
    "Title does not start with an article",
    "Title starts with an article",
    "Treatment: Drop the leading 'A'/'An'/'The'",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Title starts-with-article check")
}

# Title should not include redundant phrases like "for R", "A Toolkit for",
# "Tools for". CRAN explicitly flags these.
#' Diagnose Redundant Phrases in Title
#'
#' Flags a `Title` carrying a phrase CRAN asks you to drop, such as "for R".
#'
#' @section Source:
#' No formal rule. Phrases like "R package to" are redundant in a
#' `Title`, a convention which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_title_redundant_phrases(pkg, verbose = FALSE)$passed
lab_title_redundant_phrases <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  title <- desc[["Title"]]
  if (is.null(title) || !nzchar(title)) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Title redundant-phrases check"
    ))
  }
  patterns <- c(
    "\\bfor R\\b",
    "\\bA Toolkit for\\b",
    "\\bTools for\\b"
  )
  issues <- character(0)
  for (pat in patterns) {
    if (grepl(pat, title, perl = TRUE)) {
      issues <- c(
        issues,
        paste0(
          "Title contains redundant phrase: '",
          gsub("\\\\b", "", pat),
          "'"
        )
      )
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Title is free of redundant phrases",
    "Title contains redundant phrases that CRAN flags",
    "Treatment: Remove 'for R'/'A Toolkit for'/'Tools for'",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Title redundant-phrases check")
}

# Require a named copyright holder: a [cph] role in Authors@R, or a Copyright
# field.
#' Diagnose a Missing Copyright Holder
#'
#' Flags a package that names no copyright holder: no person in `Authors@R` has
#' the `cph` role and there is no `Copyright` field. It runs only when you call
#' it: authors who are natural persons hold copyright by default, so most
#' packages need neither. It is worth running when an organisation owns the
#' copyright, since that is the case the role exists for.
#'
#' The roles are read from the parsed `person()` object, never from the text of
#' the field, so an address such as `cph@example.com` is not a role. The field
#' is parsed without running any code it contains, as in [lab_authors()]. A
#' package with no `Authors@R` is read from its legacy `Author` field instead,
#' where only a role written in square brackets, as in `ACME Corporation
#' [cph]`, counts, in any case, and not one inside a parenthesised comment.
#'
#' @section Source:
#' [utils::person()] documents `"cph"` as the role for "all copyright holders",
#' adding that "authors which are 'natural persons' are by default copyright
#' holders and so do not need to be given this role". CRAN Repository Policy asks
#' only that copyright ownership be clear, which a `Copyright` field also
#' satisfies. See `vignette("check-sources", package = "checktor")` for how every
#' check maps to its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_cph_role(pkg, verbose = FALSE)$passed
lab_cph_role <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  # CRAN asks only that ownership be clear, and a Copyright field says so as
  # plainly as a cph role does. The help and the treatment both offered it,
  # while the check itself looked only at Authors@R and failed a package that
  # took the advice.
  copyright <- dcf_field(desc, "Copyright")
  has_copyright <- length(copyright) == 1L &&
    !is.na(copyright) &&
    nzchar(trimws(copyright))

  issues <- character(0)
  if (!has_copyright) {
    authors <- dcf_field(desc, "Authors@R")
    author <- dcf_field(desc, "Author")
    filled <- function(x) length(x) == 1L && !is.na(x) && nzchar(trimws(x))
    if (!filled(authors) && filled(author)) {
      # With no Authors@R, R reads the authors from the legacy Author field,
      # which writes each person's roles in square brackets:
      # "Ann Bee [aut, cre], ACME Corporation [cph]". Only a role in brackets
      # counts, so an address or a name containing "cph" does not.
      # A comment follows the roles in parentheses, "Ann Bee [aut] (ORCID)",
      # so drop the parenthesised spans, innermost first, before looking: a
      # bracket quoted in a comment is not a role. The code is matched in any
      # case, as a person writing the field by hand might type [CPH].
      text <- author
      repeat {
        stripped <- gsub("\\([^()]*\\)", "", text)
        if (identical(stripped, text)) {
          break
        }
        text <- stripped
      }
      brackets <- regmatches(text, gregexpr("\\[[^]]*\\]", text))[[1L]]
      roles <- trimws(unlist(strsplit(gsub("^\\[|\\]$", "", brackets), ",")))
      if (!("cph" %in% tolower(roles))) {
        issues <- "No [cph] role in Author and no Copyright field"
      }
    } else if (!filled(authors)) {
      issues <- "No Authors@R and no Copyright field"
    } else {
      # Read the roles from the parsed person() object. A grep for "cph" over
      # the raw field matched it anywhere, so an address like cph@example.com
      # or a comment naming the role passed a field that gives it to nobody.
      # The parser is the one lab_authors() uses, which never runs the field's
      # code.
      pa <- parse_authors_at_r(desc)
      if (!is.null(pa$error)) {
        issues <- paste0("Authors@R does not parse: ", pa$error)
      } else {
        persons <- pa$persons
        roles <- unlist(lapply(seq_along(persons), function(i) persons[i]$role))
        if (!("cph" %in% roles)) {
          issues <- "No [cph] role in Authors@R and no Copyright field"
        }
      }
    }
  }

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    paste(
      "A copyright holder is named in {.code Authors@R}, {.code Author} or",
      "{.code Copyright}"
    ),
    "No copyright holder is named",
    "Treatment: If an organisation owns the copyright, give it role 'cph' or name it in a Copyright field. Authors who are natural persons hold copyright already",
    level = "warning"
  )
  checktor_check_result(passed, issues, "cph role check")
}

# A Title longer than 65 characters risks being cut off in a package listing.
#' Diagnose Title Length
#'
#' Flags a `Title` longer than 65 characters.
#'
#' @section Source:
#' *Writing R Extensions* §1.1.1 notes that some package listings may truncate the
#' title to 65 characters. That is a display width rather than a limit, so a title
#' of exactly 65 characters still shows in full and only a longer one loses its
#' tail. Nothing rejects a long title, which is why this sits at `opinion` tier.
#' See `vignette("check-sources", package = "checktor")` for how every check maps
#' to its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_title_length(pkg, verbose = FALSE)$passed
lab_title_length <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  title <- desc[["Title"]]
  if (is.null(title) || !nzchar(title)) {
    return(checktor_check_result(TRUE, character(0), "Title length check"))
  }
  flat <- trimws(gsub("\\s+", " ", title))
  n <- nchar(flat)
  # 65 is the width a listing may truncate to, so 65 characters still show in
  # full and only a longer title loses its tail.
  issues <- if (n > 65L) {
    over <- n - 65L
    paste0(
      "Title is ", n, " characters, so a listing that truncates at 65 would cut ",
      "the last ", over, if (over == 1L) " character" else " characters"
    )
  } else {
    character(0)
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Title fits the 65 characters a listing may truncate to",
    "Title is longer than a listing may show",
    "Treatment: Bring the Title down to 65 characters so none of it is cut off",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Title length check", nchar = n)
}

#' Diagnose a Title That Repeats the Package Name
#'
#' Flags a `Title` that is just the package name, or that opens with the name
#' followed by a colon, as in `toypkg: Fit Simple Models`. Package listings
#' already show the name beside the `Title`, so it reads twice.
#'
#' R's incoming check also NOTEs a `Title` that opens with the name followed
#' by a space, but that form is left alone here: when the name is an ordinary
#' word, as in survival's "Survival Analysis", CRAN accepts it routinely, and
#' over a hundred packages on CRAN carry one. R drops the NOTE for an update
#' whose `Title` is unchanged since the version on CRAN, which checktor cannot
#' see offline, so an older package may pass CRAN with a finding here.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says of the `Title`: "Do not repeat the package
#' name: it is often used prefixed by the name." The
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' NOTEs "The Title field is just the package name: provide a real title." and
#' "The Title field starts with the package name.". See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario(
#'   "description_examples/title_package_name_bad.txt",
#'   show_content = FALSE
#' )
#' lab_title_package_name(pkg, verbose = FALSE)$issues
lab_title_package_name <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  title <- dcf_field(desc, "Title")
  pkg <- dcf_field(desc, "Package")
  issues <- character(0)
  if (
    !is.null(title) && !is.na(title) && !is.null(pkg) && !is.na(pkg) &&
      nzchar(trimws(pkg))
  ) {
    # As R reads them: the Title on one line, the name with its dots escaped.
    title <- trimws(gsub("[\n\t]", " ", title))
    pkg <- trimws(pkg)
    if (tolower(title) == tolower(pkg)) {
      issues <- "Title is just the package name: provide a real title"
    } else if (
      grepl(
        paste0("^", gsub(".", "[.]", pkg, fixed = TRUE), "[[:space:]]*:"),
        title,
        ignore.case = TRUE
      )
    ) {
      issues <- paste0(
        "Title starts with the package name: ", title,
        " (R drops this NOTE for an update whose Title is unchanged)"
      )
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "Title does not repeat the package name",
    "Title repeats the package name",
    "Treatment: Drop the package name from the Title, since listings show it already"
  )
  checktor_check_result(passed, issues, "Title package-name check")
}

# Function names must NOT be single-quoted in Title/Description (single quotes
# are reserved for software/package/API names). Heuristic: flag a single-quoted
# token of the form `'name(...)'` - a quoted call is a clear function name.
#' Diagnose Single-Quoted Function Names
#'
#' Flags a single-quoted function name in `Title`/`Description`. Single quotes are reserved for software names.
#'
#' @section Source:
#' No rule. This was an invented rule and is kept callable but off by
#' default. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_description_function_quotes(pkg, verbose = FALSE)$passed
lab_description_function_quotes <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  # 'fn()', 'fn(x)', 'pkg::fn()' - identifier (optionally pkg::) then parens.
  pat <- "'\\s*[A-Za-z.][A-Za-z0-9._]*(?:::[A-Za-z0-9._]+)?\\s*\\([^')]*\\)\\s*'"
  issues <- character(0)
  for (field in c("Title", "Description")) {
    text <- desc[[field]]
    if (is.null(text) || !nzchar(text)) {
      next
    }
    hits <- regmatches(text, gregexpr(pat, text, perl = TRUE))[[1L]]
    for (h in unique(hits)) {
      issues <- c(
        issues,
        paste0(field, ": function name ", trimws(h), " should not be quoted")
      )
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No single-quoted function names in Title/Description",
    "Function names are single-quoted (reserve quotes for software names)",
    "Treatment: Drop the single quotes around function names like 'fn()'",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Description function-quotes check")
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# `desc` is a named list from read_description() or resolve_description(), or a
# named character vector. `desc[["Nope"]]` on a vector is a subscript error, not
# NULL, so any code that may be handed one and reads a field it does not itself
# require must go through this.
dcf_field <- function(desc, field) {
  if (!field %in% names(desc)) {
    return(NULL)
  }
  desc[[field]]
}

# ---- Title / Description / License checks -------------------------------------

# Title case, delegated to R's own engine.
#
# The previous implementation walked the Title word by word with its own list of
# small words and stripped punctuation before comparing, which mangled real titles:
# "w/Preference" became "wPreference" and was reported as needing capitalisation,
# and a single-quoted package name like 'shiny' was flagged too.
#
# tools::toTitleCase() IS the function behind CRAN's own "Title field should be in
# title case" NOTE, and R's check restores single-quoted spans before comparing --
# which is precisely why R does not flag 'shiny' and we did. Use it, and restore
# the quoted spans the same way.
#' Diagnose Title Case in DESCRIPTION
#'
#' Flags a `Title` that is not in title case, delegating to [tools::toTitleCase()], which restores single-quoted spans so `'shiny'` keeps its own capitalisation.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says the `Title` "should use title case"; the
#' [`--as-cran`](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' incoming check flags one that does not. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_title_case(pkg, verbose = FALSE)$passed
lab_title_case <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  title <- desc[["Title"]]
  if (is.null(title) || !nzchar(title)) {
    return(checktor_check_result(TRUE, character(0), "Title case check"))
  }

  proposed <- tools::toTitleCase(title)
  # Software names in single quotes keep their own capitalisation ('shiny', not
  # 'Shiny'). R does this by putting the original quoted spans back afterwards.
  # Substitute literally: a package name can contain regex metacharacters, and
  # escaping them by hand is a bug farm.
  quoted <- regmatches(title, gregexpr("'[^']*'", title))[[1L]]
  for (q in quoted) {
    proposed <- sub(tools::toTitleCase(q), q, proposed, fixed = TRUE)
  }

  issues <- character(0)
  if (!identical(proposed, title)) {
    issues <- paste0(
      "Title is not in title case. R would write it as: ",
      proposed
    )
  }
  emit_issue_summary(
    issues,
    verbose,
    "Title is in title case",
    "Title is not in title case",
    "Treatment: Use the capitalisation tools::toTitleCase() proposes",
    level = "warning"
  )
  checktor_check_result(length(issues) == 0L, issues, "Title case check")
}

# License validity, delegated to tools::analyze_license() plus the "+ file LICENSE"
# rule. R CMD check does report these, but only once you run the full check; this
# is the same information in the pre-flight, and analyze_license() is R's own
# parser rather than a regex over the field.
#' Diagnose the License Field
#'
#' Flags a `License` that [tools::analyze_license()] cannot standardize, and a `+ file LICENSE` pointing at a file that does not exist.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' treats an invalid or unrecognised `License` field as a rejection. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_license(pkg, verbose = FALSE)$passed
lab_license <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  lic <- desc[["License"]]
  issues <- character(0)

  if (is.null(lic) || !nzchar(lic)) {
    issues <- "No License field in DESCRIPTION"
  } else {
    a <- tryCatch(tools::analyze_license(lic), error = function(e) NULL)
    if (!is.null(a) && !isTRUE(a$is_standardizable)) {
      issues <- c(
        issues,
        paste0(
          "License '",
          lic,
          "' is not a standardizable CRAN license"
        )
      )
    }
    # A template licence (MIT, BSD) carries no copyright holder of its own, so it
    # must point at a LICENSE file naming one.
    needs_file <- grepl("\\b(MIT|BSD_2_clause|BSD_3_clause)\\b", lic)
    points_at_file <- grepl("\\+\\s*file\\s+LICEN[CS]E", lic)
    if (needs_file && !points_at_file) {
      issues <- c(
        issues,
        paste0(
          "License '",
          lic,
          "' is a template and needs '+ file LICENSE'"
        )
      )
    }
    if (
      points_at_file &&
        !any(file.exists(file.path(path, c("LICENSE", "LICENCE"))))
    ) {
      issues <- c(
        issues,
        "License points at a LICENSE file that does not exist"
      )
    }
  }

  emit_issue_summary(
    issues,
    verbose,
    "License field looks valid",
    "License field problems",
    "Treatment: Use a standardizable license, and add '+ file LICENSE' for MIT/BSD"
  )
  checktor_check_result(length(issues) == 0L, issues, "License check")
}

# The licenses whose R template leaves the year and copyright holder to a
# LICENSE file, as named in tools:::.license_component_is_for_stub_and_ok()'s
# `fields_for_stubs` (R 4.6.1). For these '+ file LICENSE' is required, not
# redundant.
LICENSE_STUB_BASES <- c(
  "MIT License", "MIT",
  "BSD 2-clause License", "BSD_2_clause",
  "BSD 3-clause License", "BSD_3_clause"
)

#' Diagnose an Unneeded LICENSE File Pointer
#'
#' Flags `+ file LICENSE` added to a standard license R knows, such as
#' `GPL-3 + file LICENSE`, `LGPL-3 + file LICENSE` or
#' `Apache License 2.0 + file LICENSE`. MIT and the BSD licenses are templates
#' that need a `LICENSE` file naming the year and copyright holder, so they are
#' left alone, as is a bare `file LICENSE`. Each alternative of a dual license
#' such as `GPL-3 + file LICENSE | MIT + file LICENSE` is judged on its own.
#'
#' A `LICENSE` that adds attribution requirements or other restrictions is
#' the exception CRAN allows. Explain it in `cran-comments.md` and allow the
#' finding with `Config/checktor/allow: license_file_unneeded`.
#'
#' @section Source:
#' The CRAN Cookbook's
#' [LICENSE files](https://contributor.r-project.org/cran-cookbook/description_issues.html#license-files)
#' recipe gives the reviewers' text: "We do not need \"+ file LICENSE\" and the
#' file as these are part of R. This is only needed in case of attribution
#' requirements or other possible restrictions. Hence please omit it." R agrees
#' in two places. `R CMD check` NOTEs "License components with restrictions not
#' permitted" for a license that takes no extension, such as `GPL (>= 2)` or
#' Apache, and the
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' NOTEs "License components with restrictions and base license permitting
#' such" for one that does, such as `GPL-3`. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [lab_license()] for a license R cannot read; [checktor()], which
#'   runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario(
#'   "description_examples/license_file_unneeded_bad.txt",
#'   show_content = FALSE
#' )
#' lab_license_file_unneeded(pkg, verbose = FALSE)$issues
lab_license_file_unneeded <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  lic <- dcf_field(desc, "License")
  issues <- character(0)
  if (!is.null(lic) && !is.na(lic) && nzchar(trimws(lic))) {
    components <- trimws(strsplit(gsub("[\n\t]", " ", lic), "|", fixed = TRUE)[[1L]])
    pointer <- "[[:space:]]*\\+[[:space:]]*file[[:space:]]+LICEN[CS]E[[:space:]]*$"
    for (component in components[grepl(pointer, components)]) {
      base <- trimws(sub(pointer, "", component))
      if (!nzchar(base)) {
        next
      }
      # A base R cannot read is lab_license()'s to report.
      a <- tryCatch(tools::analyze_license(base), error = function(e) NULL)
      if (is.null(a) || !isTRUE(a$is_standardizable)) {
        next
      }
      if (base %in% LICENSE_STUB_BASES || a$standardization %in% LICENSE_STUB_BASES) {
        next
      }
      issues <- c(
        issues,
        paste0(
          component, ": ", base, " is a standard license R knows, so CRAN ",
          "needs neither '+ file LICENSE' nor the file"
        )
      )
    }
  }
  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No '+ file LICENSE' on a standard license",
    "'+ file LICENSE' on a standard license",
    paste0(
      "Treatment: CRAN asks: \"We do not need '+ file LICENSE' and the file as ",
      "these are part of R. Hence please omit it.\" Drop both, unless LICENSE ",
      "adds attribution requirements or other restrictions"
    )
  )
  checktor_check_result(passed, issues, "License file pointer check")
}

# What the Description must not start with. R's own CRAN-incoming check uses a
# broader pattern than we did, and additionally requires an initial capital, which
# we lacked entirely. Match it.
#' Diagnose the Description Opening
#'
#' Flags a `Description` opening with a phrase CRAN forbids ("This package..."), or one that does not begin with a capital letter.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says "It is good practice not to
#' start with the package name, 'This package' or similar"; the
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' flags it. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Optional pre-parsed `DESCRIPTION`, as returned by [base::read.dcf()].
#'   Defaults to reading it from `path`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_description_starts_with(pkg, verbose = FALSE)$passed
lab_description_starts_with <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  text <- desc[["Description"]]
  pkg <- dcf_field(desc, "Package")
  if (is.null(text) || !nzchar(text)) {
    return(checktor_check_result(
      TRUE,
      character(0),
      "Description opening check"
    ))
  }
  flat <- trimws(gsub("\\s+", " ", text))

  issues <- character(0)
  if (
    grepl(
      "^(The|This|A|An|In this|In the)\\s+package\\b",
      flat,
      ignore.case = TRUE
    )
  ) {
    issues <- c(
      issues,
      paste0(
        "Description should not start with \"",
        sub("\\s.*", "", flat),
        " package\"; describe what it does instead"
      )
    )
  }
  if (
    !is.null(pkg) && nzchar(pkg) && grepl(paste0("^['\"]?", pkg, "\\b"), flat)
  ) {
    issues <- c(issues, "Description should not start with the package name")
  }
  # R's descr_bad_initial rule: the Description must begin with a capital letter.
  if (grepl("^[a-z]", flat)) {
    issues <- c(issues, "Description should start with a capital letter")
  }

  emit_issue_summary(
    issues,
    verbose,
    "Description opening looks fine",
    "Description opening needs work",
    "Treatment: Start with a capital letter and say what the package does",
    level = "warning"
  )
  checktor_check_result(
    length(issues) == 0L,
    issues,
    "Description opening check"
  )
}

# The LICENSE file's own contents.
#
# The previous rule flagged any LICENSE whose latest year was not the current year.
# No authority supports that: a LICENSE reading `YEAR: 1999` passes
# R CMD check --as-cran in silence, and tools:::.check_package_license only checks
# that the fields EXIST. It fired on every package not touched this calendar year.
#
# What is real, and what nothing else checks, is an unfilled template. usethis
# writes `YEAR` and `COPYRIGHT HOLDER` for you, but a hand-written LICENSE often
# still carries `<YEAR>` / `<COPYRIGHT HOLDER>` placeholders, and CRAN policy does
# require copyright ownership to be clear and unambiguous.
#' Diagnose an Unfilled LICENSE Template
#'
#' Flags a `LICENSE` file still carrying template placeholders such as `<YEAR>` or `<COPYRIGHT HOLDER>`.
#'
#' @section Source:
#' The CRAN Cookbook covers the file itself under
#' [LICENSE files](https://contributor.r-project.org/cran-cookbook/description_issues.html#license-files).
#' An unfilled template, with `<YEAR>` or `<COPYRIGHT HOLDER>` left in, leaves a
#' placeholder, and no binding rule names it, which is why this sits at
#' `robustness` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_license_year(pkg, verbose = FALSE)$passed
lab_license_year <- function(path, verbose) {
  path <- find_package_root(path)
  license_file <- Filter(file.exists, file.path(path, c("LICENSE", "LICENCE")))
  if (length(license_file) == 0L) {
    return(checktor_check_result(TRUE, character(0), "License file check"))
  }
  content <- safe_read_lines(license_file[[1L]])
  if (length(content) == 0L) {
    return(checktor_check_result(
      FALSE,
      "LICENSE file is empty",
      "License file check"
    ))
  }
  flat <- paste(content, collapse = "\n")

  issues <- character(0)
  placeholders <- c(
    "<YEAR>",
    "<COPYRIGHT HOLDER>",
    "<copyright holders>",
    "YOUR NAME",
    "Your Name",
    "[year]",
    "[fullname]"
  )
  for (ph in placeholders) {
    if (grepl(ph, flat, fixed = TRUE)) {
      issues <- c(
        issues,
        paste0(
          "LICENSE has an unfilled template placeholder: ",
          ph
        )
      )
    }
  }
  # A DCF-style LICENSE (what usethis writes for MIT/BSD) must name a holder.
  if (grepl("^YEAR:", flat) && !grepl("COPYRIGHT HOLDER:\\s*\\S", flat)) {
    issues <- c(issues, "LICENSE has no COPYRIGHT HOLDER")
  }

  emit_issue_summary(
    issues,
    verbose,
    "LICENSE file is filled in",
    "LICENSE file has unfilled placeholders",
    "Treatment: Replace the template placeholders with the real year and holder"
  )
  checktor_check_result(length(issues) == 0L, issues, "License file check")
}

#' Diagnose Possibly Misspelled Words in DESCRIPTION
#'
#' Spell-checks the `Title` and `Description` fields with [utils::aspell()],
#' mirroring the aspell pass in CRAN's incoming check. It reports only words that
#' are not already accepted somewhere: a package `.aspell/` dictionary,
#' `inst/WORDLIST`, or a `Config/checktor/acronyms`, `software_names`,
#' `language_names` or `format_names` field.
#'
#' @details
#' The check needs a spell-check backend (`aspell` or `hunspell`) on the system.
#' Without one it is reported as skipped, the same way CRAN's incoming check
#' skips spelling when no backend is present, so a run on one machine may find
#' words a run on another does not. It is therefore an `opinion`-tier check.
#' When it does fire, [prescribe()] hands back a ready-to-paste `.aspell/`
#' snippet with the flagged words filled in.
#'
#' @section Source:
#' The [CRAN incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' runs `aspell` over the `Title` and `Description`; it needs a
#' spell-check backend and is noisy, so checktor keeps it at
#' `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param desc Present for signature parity with the other DESCRIPTION checks;
#'   spelling reads the `DESCRIPTION` file directly and ignores it.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`; the
#'   `issues` are the possibly-misspelled words.
#' @seealso [checktor()], [prescribe()].
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_spelling(pkg, verbose = FALSE)$passed
lab_spelling <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc_file <- file.path(path, "DESCRIPTION")
  # Backend-dependent, so its result can differ between machines. Users who want
  # a fully deterministic run (and the test suite) turn it off with
  # options(checktor.spelling = FALSE); it stays on by default.
  if (!isTRUE(getOption("checktor.spelling", TRUE))) {
    return(checktor_skipped_result(
      "Spelling check",
      "turned off with options(checktor.spelling = FALSE)"
    ))
  }
  program <- Sys.which("aspell")
  if (!nzchar(program)) {
    program <- Sys.which("hunspell")
  }
  # No backend or no DESCRIPTION: nothing was examined, so say so rather than
  # reporting a pass, exactly as CRAN's incoming check skips spelling without one.
  if (!nzchar(program)) {
    return(checktor_skipped_result(
      "Spelling check",
      "no aspell or hunspell backend installed"
    ))
  }
  if (!file.exists(desc_file)) {
    return(checktor_check_result(TRUE, character(0), "Spelling check"))
  }

  flagged <- tryCatch(
    utils::aspell(desc_file, filter = "dcf", program = program),
    error = function(e) NULL
  )
  words <- if (is.null(flagged) || nrow(flagged) == 0L) {
    character(0)
  } else {
    unique(as.character(flagged$Original))
  }
  issues <- sort(setdiff(words, spelling_accepted_words(path)))

  passed <- length(issues) == 0L
  emit_issue_summary(
    issues,
    verbose,
    "No possibly-misspelled words in {.file DESCRIPTION}",
    "Possibly misspelled words in {.file DESCRIPTION}",
    "Treatment: add correct terms to a .aspell dictionary; run prescribe() for the snippet",
    level = "warning"
  )
  checktor_check_result(passed, issues, "Spelling check")
}

# Words a package has already declared acceptable, gathered from every mechanism
# a maintainer might use: an aspell `.aspell/*.rds` dictionary, the spelling
# package's `inst/WORDLIST`, and every one of checktor's own `Config/checktor`
# vocabularies. Subtracting these keeps lab_spelling silenceable no matter which
# one the package reaches for.
spelling_accepted_words <- function(path) {
  words <- character(0)

  aspell_dir <- file.path(path, ".aspell")
  if (dir.exists(aspell_dir)) {
    for (f in list.files(aspell_dir, pattern = "\\.rds$", full.names = TRUE)) {
      w <- tryCatch(readRDS(f), error = function(e) NULL)
      if (is.character(w)) {
        words <- c(words, w)
      }
    }
  }

  wordlist <- file.path(path, "inst", "WORDLIST")
  if (file.exists(wordlist)) {
    words <- c(words, safe_read_lines(wordlist))
  }

  cfg <- checktor_config(path)
  words <- c(
    words,
    cfg$acronyms,
    cfg$software_names,
    cfg$language_names,
    cfg$format_names
  )

  unique(words[nzchar(words)])
}

# Authors@R, identifier and copyright-holder checks on DESCRIPTION.

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
#' pkg <- example_diagnose_scenario("description_examples/authors_bad.txt",
#'                                  show_content = FALSE)
#' lab_authors(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
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
#' pkg <- example_diagnose_scenario("description_examples/identifier_format_bad.txt",
#'                                  show_content = FALSE)
#' lab_identifier_format(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
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
#' pkg <- example_diagnose_scenario("description_examples/cph_role_bad.txt",
#'                                  show_content = FALSE)
#' lab_cph_role(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
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

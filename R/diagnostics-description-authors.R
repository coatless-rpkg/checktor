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
  aar <- desc_value(desc, "Authors@R")
  if (is.null(aar)) {
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

# The string constants of an Authors@R field, one per line, so a comment or a
# symbol is not read as a name. A field that does not parse is returned whole.
authors_r_strings <- function(text) {
  pd <- tryCatch(
    utils::getParseData(parse(text = text, keep.source = TRUE)),
    error = function(e) NULL
  )
  if (is.null(pd)) {
    return(text)
  }
  paste(pd$text[pd$token == "STR_CONST"], collapse = "\n")
}

#' Diagnose the Authors@R Field
#'
#' Flags a missing `Authors@R`, and an unfilled `usethis` or `package.skeleton()` template such as `person("First", "Last", ...)` or `person("Givenname", "Familyname", ...)`, which is a hard CRAN rejection that `R CMD check` says nothing about.
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
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/authors_bad.txt",
#'                                  show_content = FALSE)
#' lab_authors(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_authors <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  # Three things are checked here, and only the first overlaps with R.
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
  #     presence-only check waved it through. See author_placeholder_issues().
  #
  # (c) Structural validity, mirroring CRAN's own Authors@R validator
  #     (tools:::.check_package_description_authors_at_R_field, strict mode). A
  #     present-but-broken field passes R CMD check's presence test yet is a
  #     reviewer rejection: a call R's reader refuses, a person with no name, a
  #     person with no role, or no maintainer (cre) at all. Parsed with public R
  #     via parse_authors_at_r(); see refused_call_issue() and person_issues().
  missing <- if (is.null(desc_value(desc, "Authors@R"))) {
    "Missing Authors@R field"
  }
  pa <- parse_authors_at_r(desc)
  structure <- if (!is.null(pa$error)) {
    paste0("Authors@R does not parse: ", pa$error)
  } else {
    person_issues(pa$persons)
  }
  issues <- unique(c(
    missing,
    author_placeholder_issues(desc),
    refused_call_issue(pa$refused),
    structure
  ))

  report_check(
    issues,
    verbose,
    check_label("authors"),
    "{.code Authors@R} present and filled in",
    "Problems in the author fields",
    treatment = paste("Treatment:", treatments$authors$treatment)
  )
}

# The template names and addresses lab_authors() looks for in the author fields.
AUTHOR_PLACEHOLDERS <- c(
  "First",
  "Last",
  "First Last",
  "Your Name",
  "YOUR NAME",
  "you@example.com",
  "your@email.com",
  "first.last@example.com",
  # The Authors@R that utils::package.skeleton() writes (R 4.6.1), which R's
  # incoming check does not test: it looks only at the Author and Maintainer
  # fields older skeletons wrote.
  "Givenname",
  "Familyname",
  "Anotherone",
  "Ifany",
  "yourfault@somewhere.net"
)

# One issue per author field that still holds template placeholders, listing
# them. The same template leaks into Authors@R, Author and Maintainer at once,
# so reporting every (field, placeholder) pair would turn a single mistake into
# eight findings.
author_placeholder_issues <- function(desc) {
  issues <- character(0)
  for (field in c("Authors@R", "Author", "Maintainer")) {
    text <- desc_value(desc, field)
    if (is.null(text)) {
      next
    }
    # The older skeleton's "Who to complain to <yourfault@somewhere.net>" is
    # lab_description_placeholders()'s to report, as R's incoming check does.
    template <- DESCRIPTION_PLACEHOLDERS[[field]]
    if (!is.null(template) && isTRUE(template(text))) {
      next
    }
    # Only the strings of Authors@R are names and addresses. CGGP's field ends in
    # an R comment quoting that older Maintainer line.
    if (field == "Authors@R") {
      text <- authors_r_strings(text)
    }
    hit <- AUTHOR_PLACEHOLDERS[vapply(
      AUTHOR_PLACEHOLDERS,
      function(ph) {
        grepl(paste0("[\"']", ph, "[\"']"), text) ||
          grepl(paste0("\\b", escape_regex(ph), "\\b"), text, perl = TRUE)
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
  issues
}

# From R 4.6.0 on, R's own reader allows only person(), as.person(), c(),
# list(), paste(), paste0() and `(` in Authors@R, each called by its bare name,
# and R CMD build stops on anything else as a "Malformed Authors@R field". Every
# call it would refuse is named in one issue, whether parse_authors_at_r() could
# still read the field (utils::person(), (c)(...)) or not.
refused_call_issue <- function(refused) {
  refused <- unique(refused)
  n <- length(refused)
  if (n == 0L) {
    return(character(0))
  }
  named <- if (n == 1L) {
    refused
  } else {
    paste(paste(refused[-n], collapse = ", "), "and", refused[[n]])
  }
  paste0(
    "Authors@R calls ",
    named,
    ", which R CMD build refuses from R 4.6.0 on as a malformed field: ",
    "call only person(), as.person(), c(), list(), paste() and paste0(), ",
    "by their bare names"
  )
}

# One field of every entry in a person object, as a list with one element per
# person (NULL where the person does not give it), as `persons[i]$field` reads
# each. parse_authors_at_r() hands back only well-formed entries.
person_field <- function(persons, field) {
  lapply(unclass(persons), `[[`, field)
}

# What R's strict Authors@R validator refuses in a readable field: a person with
# no name, a person with no role, and no maintainer.
person_issues <- function(persons) {
  if (is.null(persons)) {
    return(character(0))
  }
  issues <- character(0)
  unnamed <- vapply(person_field(persons, "given"), is.null, logical(1)) &
    vapply(person_field(persons, "family"), is.null, logical(1))
  if (any(unnamed)) {
    issues <- c(issues, "Authors@R has a person entry with no name")
  }
  roles <- person_field(persons, "role")
  if (any(vapply(roles, is.null, logical(1)))) {
    issues <- c(issues, "Authors@R has a person entry with no role")
  }
  if (!("cre" %in% unlist(roles))) {
    issues <- c(
      issues,
      "Authors@R declares no maintainer (a person with role \"cre\")"
    )
  }
  issues
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
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
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
      check_label("identifier_format"),
      "Authors@R could not be read"
    ))
  }
  issues <- character(0)
  for (cm in person_field(pa$persons, "comment")) {
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
  report_check(
    issues,
    verbose,
    check_label("identifier_format"),
    "Author identifiers are well formed",
    "Malformed author identifier",
    treatment = paste("Treatment:", treatments$identifier_format$treatment)
  )
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
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
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
  issues <- character(0)
  if (is.null(desc_value(desc, "Copyright"))) {
    has_authors_r <- !is.null(desc_value(desc, "Authors@R"))
    author <- desc_value(desc, "Author")
    if (!has_authors_r && !is.null(author)) {
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
    } else if (!has_authors_r) {
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
        if (!("cph" %in% unlist(person_field(pa$persons, "role")))) {
          issues <- "No [cph] role in Authors@R and no Copyright field"
        }
      }
    }
  }

  report_check(
    issues,
    verbose,
    check_label("cph_role"),
    paste(
      "A copyright holder is named in {.code Authors@R}, {.code Author} or",
      "{.code Copyright}"
    ),
    "No copyright holder is named",
    treatment = paste("Treatment:", treatments$cph_role$treatment),
    level = "warning"
  )
}

# What a package exports, read from NAMESPACE and from roxygen's @export tags.

# Everything a package exports, read with R's OWN NAMESPACE parser.
#
# This used to be two hand-rolled regexes over the file, LINE BY LINE, and they
# were catastrophically wrong. A multi-line block, which is the form roxygen2 and
# most humans write:
#
#     export(AES,
#            digest,
#            ...)
#
# lost every name after the first line. Run against the `digest` package the old
# reader returned exactly ONE entry, the string "AES," (trailing comma included),
# where the truth is nine exports. So `digest::digest()`, the package's flagship
# function, was reported as UNEXPORTED. It also ignored exportPattern() entirely.
#
# That single defect silently poisoned every check that asks "is this exported?":
# unexported_example_ns, missing_examples, and roxygen_usage. Across 45 CRAN
# packages it accounted for 121 false findings.
#
# base::parseNamespaceFile() is the parser R itself uses to load a namespace. It
# wants (package, lib) and reads <lib>/<package>/NAMESPACE, which is exactly the
# shape of a source tree.
#
# Returns list(names, patterns), or NULL when the NAMESPACE cannot be parsed. NULL
# means "cannot tell", and every caller must then SKIP rather than guess: a check
# that cannot see the exports must not accuse anything of being unexported.
package_exports <- function(path) {
  full <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (!file.exists(file.path(full, "NAMESPACE"))) {
    return(NULL)
  }

  ns <- tryCatch(
    parseNamespaceFile(basename(full), dirname(full)),
    error = function(e) NULL
  )
  if (is.null(ns)) {
    return(NULL)
  }

  names <- as.character(ns$exports)

  # S3method(generic, class) registers `generic.class`. The optional third column
  # names a differently-named function backing the method.
  s3 <- ns$S3methods
  if (!is.null(s3) && nrow(s3) > 0L) {
    names <- c(names, paste(s3[, 1L], s3[, 2L], sep = "."))
    if (ncol(s3) >= 3L) {
      backing <- s3[, 3L]
      names <- c(names, backing[!is.na(backing)])
    }
  }

  # S4.
  names <- c(
    names,
    as.character(ns$exportClasses),
    as.character(ns$exportMethods)
  )

  list(names = unique(names), patterns = as.character(ns$exportPatterns))
}

# Is `nm` exported, given the result of package_exports()? exportPattern() takes
# regexes, so a name can be exported without ever being named.
name_is_exported <- function(nm, ex) {
  if (is.null(ex)) {
    return(TRUE)
  } # cannot tell: assume exported, never accuse
  if (nm %in% ex$names) {
    return(TRUE)
  }
  for (pat in ex$patterns) {
    if (grepl(pat, nm)) return(TRUE)
  }
  FALSE
}

# Names carrying an `@export` tag in a roxygen block, as a named character
# vector: names are the object names, values the file each was found in.
#
# This runs on the parse tree, not the source text. `COMMENT` is a real token in
# getParseData(), so roxygen blocks are located structurally, and the exported
# object is the target of the first top-level expression that FOLLOWS the block,
# read off the tree by assign_target_of(). That is what buys us `add <-` split
# across two lines, `x = 1`, and backticked or quoted names, none of which a
# "regex the next line" approach survives.
#
# Matching `@export` within the comment's own text IS a regex, and correctly so:
# roxygen tags have no finer tokenization than the COMMENT they sit in. The rule
# the AST rewrite enforces is "do not regex the raw source", not "never regex".
#
# Anything that does not resolve to a plain assigned name (S4 setMethod, the
# `"_PACKAGE"` sentinel) is skipped rather than guessed at: a false "you forgot
# to document()" is worse than a miss.
roxygen_exported_names <- function(parsed) {
  out <- character(0)
  for (entry in parsed) {
    if (is.null(entry$xml)) {
      next
    }
    file <- basename(entry$file)

    # A top-level `<-` is an `expr`, but a top-level `=` is wrapped in
    # `expr_or_assign_or_help` (`equal_assign` on older R), so matching only
    # `expr` would silently skip every `name = function(...)` in the package.
    top <- xml2::xml_find_all(
      entry$xml,
      "/exprlist/*[self::expr or self::expr_or_assign_or_help or self::equal_assign]"
    )
    if (length(top) == 0L) {
      next
    }
    top_line <- as.integer(xml2::xml_attr(top, "line1"))

    comments <- xml2::xml_find_all(entry$xml, "//COMMENT")
    for (cmt in comments) {
      text <- xml2::xml_text(cmt)
      # `@export` exactly. The negative lookahead is load-bearing: without it
      # `@exportS3Method` matches too.
      if (!grepl("^\\s*#'\\s*@export(?![A-Za-z0-9_])", text, perl = TRUE)) {
        next
      }

      # `@export` may name its objects outright, and may name SEVERAL:
      # jsonlite writes `#' @export fromJSON toJSON`. Storing that whole string as
      # one name invented a function called "fromJSON toJSON" and then reported it
      # as missing from NAMESPACE.
      explicit <- trimws(sub("^\\s*#'\\s*@export\\s*", "", text, perl = TRUE))
      if (nzchar(explicit)) {
        for (nm in strsplit(explicit, "[,[:space:]]+")[[1L]]) {
          if (nzchar(nm)) out[[nm]] <- file
        }
        next
      }

      # The object being exported is the target of the first top-level
      # expression starting after this comment line.
      line <- as.integer(xml2::xml_attr(cmt, "line2"))
      nxt <- which(top_line > line)
      if (length(nxt) == 0L) {
        next
      }
      name <- assign_target_of(top[[nxt[[1L]]]])
      if (!is.na(name)) out[[name]] <- file
    }
  }
  out
}

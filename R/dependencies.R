# Suggested packages and the guards that make using one in an example safe.

# Split a DESCRIPTION dependency field (Suggests/Imports/...) into bare package
# names, dropping version constraints and the special "R" entry.
parse_package_list <- function(field) {
  if (is.null(field) || !nzchar(field)) {
    return(character(0))
  }
  parts <- strsplit(field, ",", fixed = TRUE)[[1L]]
  parts <- trimws(sub("\\(.*\\)", "", parts))
  parts <- parts[nzchar(parts)]
  setdiff(parts, "R")
}

# Functions an example calls to ask whether a package is installed. cli's examples
# ask through its own has_packages(), so it is read the same way.
SUGGESTS_GUARDS <- c("requireNamespace", "require", "is_installed", "has_packages")

# R's base packages, which every R installation has. This is the list
# tools:::.get_standard_package_names()$base gives, written out because that
# function is internal.
BASE_PACKAGES <- c(
  "base", "tools", "utils", "grDevices", "graphics", "stats", "datasets",
  "methods", "grid", "splines", "stats4", "tcltk", "compiler", "parallel"
)

# R's recommended packages, which ship with R. CRAN's checks hide one only when
# the DESCRIPTION does not declare it (_R_CHECK_NO_RECOMMENDED_), so a recommended
# package in Suggests is there whenever the examples run. This is the list
# tools:::.get_standard_package_names()$recommended gives, written out because the
# installed set varies from machine to machine.
RECOMMENDED_PACKAGES <- c(
  "MASS", "lattice", "Matrix", "nlme", "survival", "boot", "cluster",
  "codetools", "foreign", "KernSmooth", "rpart", "class", "nnet", "spatial",
  "mgcv"
)

# The packages a DESCRIPTION suggests that a check machine may lack: its Suggests,
# less the base and recommended packages. character(0) when there is none or the
# DESCRIPTION cannot be read.
suggested_packages <- function(path) {
  desc <- description_or_null(path)
  if (is.null(desc)) {
    return(character(0))
  }
  setdiff(
    parse_package_list(desc[["Suggests"]]),
    c(BASE_PACKAGES, RECOMMENDED_PACKAGES)
  )
}

# A guard for guarded_by(): whether a term asks if `pkg` is installed, naming it as
# a string or, as require() also allows, as a bare name. A guard for any other
# package is no guard for this one. A literal FALSE is the branch that never runs,
# and a term that is false under R CMD check, such as `interactive()`, is a branch
# CRAN's noSuggests check never runs either.
suggests_guard <- function(pkg) {
  function(node) {
    if (is_false_constant(node) || is_check_off_guard(node)) {
      return(TRUE)
    }
    parts <- call_parts(node)
    if (is.null(parts) || !parts$fn %in% SUGGESTS_GUARDS) {
      return(FALSE)
    }
    named <- arg_strings(parts$args)
    if (parts$fn == "require" && length(parts$args) > 0L) {
      named <- c(named, xml2::xml_text(xml2::xml_find_all(parts$args[[1L]], "SYMBOL")))
    }
    pkg %in% named
  }
}

# The package a library() or require() call attaches, when its first argument
# names one outright, or NA.
attached_package <- function(fn) {
  first <- xml2::xml_find_first(
    fn,
    "parent::expr/following-sibling::expr[1]/*[self::SYMBOL or self::STR_CONST]"
  )
  if (inherits(first, "xml_missing")) NA_character_ else unquote_name(xml2::xml_text(first))
}

# The packages from `suggests` that parsed example code uses without a guard
# naming them, in the order `suggests` lists them. A use is `pkg::`, `pkg:::`,
# library() or require(); Writing R Extensions sanctions
# `if (require("pkgB", quietly = TRUE))`, so a require() an `if` tests is the guard
# rather than a use. `judged(use)` picks the uses that count.
unguarded_suggests <- function(xml, suggests, judged = function(use) TRUE) {
  qualified <- xml2::xml_find_all(xml, "//SYMBOL_PACKAGE")
  attaches <- xml2::xml_find_all(
    xml,
    paste0(
      "//SYMBOL_FUNCTION_CALL[text() = 'library' or text() = 'require'][",
      NOT_MEMBER_ACCESS,
      "]"
    )
  )
  attaches <- attaches[!vapply(attaches, in_if_condition, logical(1))]
  uses <- c(as.list(qualified), as.list(attaches))
  used <- c(
    xml2::xml_text(qualified),
    vapply(attaches, attached_package, character(1))
  )
  out <- character(0)
  for (pkg in intersect(suggests, used)) {
    guard <- suggests_guard(pkg)
    unguarded <- vapply(
      uses[used %in% pkg],
      function(use) judged(use) && !guarded_by(use, guard),
      logical(1)
    )
    if (any(unguarded)) {
      out <- c(out, pkg)
    }
  }
  out
}

# Reading the guards around a call in parsed R: which condition encloses it,
# what that condition says, and what a variable in it was assigned.

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
# `if (!(ok <- requireNamespace("x"))) ...`, always runs, unless it sits on the
# right of `&&` or `||`, which is evaluated only when the left side leaves the
# answer open, as in `if (a && (ok <- requireNamespace("x")))`. An assignment always
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
  # Each branch, loop body or right operand of `&&` or `||` the assignment sits
  # in must hold the read too. A branch or body follows the closing parenthesis
  # of its condition, the `for` sequence, or `repeat`.
  part <- paste0(
    "ancestor-or-self::*[(parent::expr[IF or FOR or WHILE or REPEAT] and ",
    "(preceding-sibling::OP-RIGHT-PAREN or preceding-sibling::forcond or ",
    "preceding-sibling::REPEAT)) or ",
    "preceding-sibling::*[not(self::COMMENT)][1][self::AND2 or self::OR2]]"
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

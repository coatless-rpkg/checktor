# Parse-tree helpers that decide when console output is the point of a function
# (print methods and their delegates, reporters).

# Names of functions whose output is only ever reachable through an S3 output
# method, i.e. print-method delegates.
#
# An S3 print method may hand its cat()ing off to a helper (some packages do this
# with a print_structure_section() and friends). The helper is not itself a method,
# so a name-based exemption cannot see it. But if EVERY caller of the helper is
# an S3 print/format/summary method, its output is reachable only via one, which
# is behaviourally identical to inlining it. Callers are resolved across all
# parsed files. A helper with no callers, or with even one non-method caller, is
# not a delegate.
s3_output_delegates <- function(parsed) {
  s4_named <- s4_registered_method_names(parsed)
  is_method <- function(nm) {
    is_output_method_name(nm) | nm == S4_SHOW_CALLER | nm %in% s4_named
  }

  defined <- character(0) # every top-level function name
  callers <- list() # callee -> character vector of caller names

  for (p in parsed_docs(parsed)) {
    fns <- xml2::xml_find_all(
      p$xml,
      sprintf("//expr[FUNCTION][%s]", DEF_NAME_XPATH)
    )
    for (fn in fns) {
      sym <- xml2::xml_find_first(fn, DEF_NAME_XPATH)
      if (inherits(sym, "xml_missing")) {
        next
      }
      nm <- unquote_name(xml2::xml_text(sym))
      defined <- c(defined, nm)
      callees <- unique(xml2::xml_text(
        xml2::xml_find_all(fn, ".//SYMBOL_FUNCTION_CALL")
      ))
      for (ce in callees) {
        callers[[ce]] <- c(callers[[ce]], nm)
      }
    }
  }

  # An S4 output method is an ANONYMOUS function handed to setMethod("show", ...),
  # so the loop above, which only walks NAMED top-level functions, never sees it.
  # DBI hands its cat()ing to show_connection(), whose only caller is exactly such
  # a method -- so without this, show_connection() has no callers at all, is not
  # recognised as a delegate, and gets reported.
  for (p in parsed_docs(parsed)) {
    for (body in xml2::xml_find_all(p$xml, s4_output_method_xpath())) {
      callees <- unique(xml2::xml_text(
        xml2::xml_find_all(body, ".//SYMBOL_FUNCTION_CALL")
      ))
      for (ce in callees) {
        callers[[ce]] <- c(callers[[ce]], S4_SHOW_CALLER)
      }
    }
  }

  defined <- unique(defined)
  if (length(defined) == 0L) {
    return(character(0))
  }

  local_defs <- setdiff(defined, defined[is_method(defined)])
  keep <- vapply(
    local_defs,
    function(nm) {
      cs <- callers[[nm]]
      length(cs) > 0L && all(is_method(cs))
    },
    logical(1)
  )
  local_defs[keep]
}

# Names of functions REGISTERED as an S4 output method by name, rather than
# written inline. DBI does this throughout:
#
#     setMethod("show", "DBIConnection", show_DBIConnection)
#
# The method is `show_DBIConnection`, a perfectly ordinary named function, so an
# XPath looking for an anonymous `function` inside the setMethod call finds
# nothing at all. Yet that function IS the show method, and cat() inside it is as
# legitimate as cat() inside print.default().
s4_registered_method_names <- function(parsed) {
  xpath <- sprintf(
    "//expr[expr[1]/SYMBOL_FUNCTION_CALL[%s]][expr[2]/STR_CONST[%s]]/expr[last()]/SYMBOL",
    xp_text_in(S4_METHOD_SETTERS),
    xp_str_const_in(S4_OUTPUT_GENERICS)
  )
  unique(xpath_per_file(parsed, xpath, function(file, nodes) {
    xml2::xml_text(nodes)
  }))
}

# Every function whose job is producing console output: S3 methods by name prefix,
# plus S4 methods registered by name. cat() inside any of them is the idiom, not a
# leak.
output_method_names <- function(parsed) {
  defined <- xpath_per_file(
    parsed,
    "//expr[FUNCTION]/parent::*/expr[1]/SYMBOL | //expr[FUNCTION]/parent::*/expr[1]/STR_CONST",
    function(file, nodes) unquote_name(xml2::xml_text(nodes))
  )
  s3 <- unique(defined[is_output_method_name(defined)])
  unique(c(s3, s4_registered_method_names(parsed)))
}

# The generics whose S3 methods exist to produce console output. CRAN's rule ends
# "(except for print, summary, interactive functions)", and format() is print()'s
# workhorse.
OUTPUT_METHOD_PREFIXES <- c("print", "format", "summary")

# Is `nm` the name of an S3 output method, such as `print.foo`?
is_output_method_name <- function(nm) {
  grepl(
    paste0("^(", paste(OUTPUT_METHOD_PREFIXES, collapse = "|"), ")\\."),
    nm
  )
}

# A sentinel caller name for "an S4 output method". It cannot collide with a real
# R function name, because a real one cannot contain a space.
S4_SHOW_CALLER <- "<S4 output method>"

# The generics whose S4 methods exist to PRODUCE console output. CRAN's rule ends
# with the literal parenthetical "(except for print, summary, interactive
# functions)", and `show` is simply what S4 calls `print`: it is the method R
# invokes to display an object at the prompt. cat() is the required idiom inside
# one, exactly as it is inside print.default().
S4_OUTPUT_GENERICS <- c("show", "print", "format", "summary")

# The calls that register an S4 method.
S4_METHOD_SETTERS <- c("setMethod", "setReplaceMethod")

# XPath selecting the function body of any setMethod("show", ...) and friends.
# The method function is an argument of the setMethod call, so from the function
# expr the call is `parent::expr` and the generic is that call's second expr.
# `axis` is where to look: `//` finds every such method, and `ancestor::` asks
# whether a node sits inside one.
s4_output_method_xpath <- function(axis = "//") {
  sprintf(
    "%sexpr[FUNCTION][parent::expr[expr[1]/SYMBOL_FUNCTION_CALL[%s]][expr[2][STR_CONST[%s] or SYMBOL[%s]]]]",
    axis,
    xp_text_in(S4_METHOD_SETTERS),
    xp_str_const_in(S4_OUTPUT_GENERICS),
    xp_text_in(S4_OUTPUT_GENERICS)
  )
}

# Is `node`'s innermost enclosing function a console REPORTER, i.e. one whose
# purpose is the output it prints?
#
# THE RULE, AND WHY IT IS THIS NARROW.
#
# The CRAN Repository Policy contains no rule about console output at all. Writing
# R Extensions forbids stdout/stderr writes only from COMPILED code. What is real
# is the CRAN reviewer request, issued constantly:
#
#   "You write information messages to the console that cannot easily be
#    suppressed. Please use message()/warning(), or if (verbose) cat()."
#
# The operative words are "information messages" and "cannot easily be suppressed".
# The harm is to a caller who wanted a VALUE and got noise alongside it. A function
# with no visible return value was called for its side effect: the output is the
# entire observable contract, and there is nothing for the noise to interfere with.
# print.default() is such a function. So is cli::cat_line(). So is every show
# method ever written.
#
# So: flag output only from a function that ALSO hands something back.
#
# This is deliberately the smallest defensible rule. An earlier version added a
# second condition -- a "dead binding", a local computed and then discarded, on the
# theory that `result <- compute(x); cat("Done!\n")` is a leftover notice rather
# than a report. It is, and we no longer flag it. That is a knowing miss. It was
# bought with a false-positive rate we could not defend, on a rule that is a
# reviewer convention rather than policy text, and precision is the only thing this
# package sells.
is_console_reporter <- function(node) {
  # Top-level code is not our call.
  body <- enclosing_function_body(node)
  !is.null(body) && stmt_is_side_effect_only(body)
}

# Calls whose value is never the point.
SIDE_EFFECT_CALLS <- c(
  "invisible",
  "cat",
  "print",
  "message",
  "packageStartupMessage",
  "writeLines",
  "warning",
  "stop",
  "show", # S4's print
  "str",
  "summary",
  "abort",
  "inform",
  "warn", # rlang's condition signallers
  "invokeRestart",
  "signalCondition", # control flow: never returns a value
  "tryInvokeRestart",
  "flush.console"
)

stmt_is_side_effect_only <- function(expr, depth = 0L) {
  if (depth > 6L) {
    return(FALSE)
  } # deeply nested if/else; give up rather than loop

  # A loop and a bare NULL both evaluate to invisible NULL.
  if (length(xml2::xml_find_all(expr, "./FOR | ./WHILE | ./REPEAT")) > 0L) {
    return(TRUE)
  }
  if (length(xml2::xml_find_all(expr, "./NULL_CONST")) > 0L) {
    return(TRUE)
  }

  # An `if` evaluates to whichever BRANCH is taken, so it is side-effect-only when
  # every branch is. Looking at `./expr[1]` here reads the CONDITION instead, which
  # is how knitr's normal_print(), a pure dispatcher whose two branches are
  # `methods::show(x)` and `print(x)`, was reported as leaking output.
  # A one-armed `if` evaluates to invisible NULL when false, so only the branches
  # that exist need checking.
  if (length(xml2::xml_find_all(expr, "./IF")) > 0L) {
    branches <- xml2::xml_find_all(expr, "./expr[position() > 1]")
    if (length(branches) == 0L) {
      return(TRUE)
    }
    return(all(vapply(
      branches,
      stmt_is_side_effect_only,
      logical(1),
      depth = depth + 1L
    )))
  }

  # A braced block evaluates to its last statement.
  if (length(xml2::xml_find_all(expr, "./OP-LEFT-BRACE")) > 0L) {
    last <- xml2::xml_find_first(expr, sprintf("./%s[last()]", ASSIGN_NODE))
    if (inherits(last, "xml_missing")) {
      return(TRUE)
    } # `{}` evaluates to NULL
    return(stmt_is_side_effect_only(last, depth + 1L))
  }

  # The callee of `f(...)` and of `pkg::f(...)` alike.
  fn <- xml2::xml_text(
    xml2::xml_find_first(expr, "./expr[1]/SYMBOL_FUNCTION_CALL")
  )
  if (is.na(fn)) {
    return(FALSE)
  }
  if (fn %in% SIDE_EFFECT_CALLS) {
    return(TRUE)
  }
  if (startsWith(fn, "cli_")) {
    return(TRUE)
  }

  # `return(invisible(x))` is still a side effect; look through the return().
  if (identical(fn, "return")) {
    inner <- xml2::xml_find_first(expr, "./expr[2]")
    if (inherits(inner, "xml_missing")) {
      return(TRUE)
    } # bare return()
    return(stmt_is_side_effect_only(inner, depth + 1L))
  }
  FALSE
}

# Is this `print()` writing a FILE rather than the console?
#
# officer defines print.rpptx(x, target, ...) and print.docx likewise, so
# `print(doc, output_file)` is how you SAVE a document. It produces no console
# output at all. A console print takes the object alone.
#
# The tell is a second positional argument that names a destination. `print(x,
# digits = 3)` is console output and passes a NAMED argument, so it is untouched.
is_file_writing_print <- function(node) {
  call <- xml2::xml_find_first(node, "parent::expr/parent::expr")
  if (inherits(call, "xml_missing")) {
    return(FALSE)
  }
  # Positional args only: a named arg arrives as SYMBOL_SUB/EQ_SUB, not an expr.
  args <- xml2::xml_find_all(call, "./expr[position() > 1]")
  if (length(args) < 2L) {
    return(FALSE)
  }

  dest <- args[[2L]]
  sym <- xml2::xml_text(xml2::xml_find_first(dest, "./SYMBOL"))
  if (
    !is.na(sym) &&
      grepl("file|path|target|output|dest|con$|dir", sym, ignore.case = TRUE)
  ) {
    return(TRUE)
  }
  # A literal path handed to print() is a write too.
  !is.na(xml2::xml_text(xml2::xml_find_first(dest, "./STR_CONST")))
}

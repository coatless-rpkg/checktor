# Parse-tree helpers that find where a write call sends its output.

# ---- write-destination analysis ---------------------------------------------

# Which argument of a write function names the destination. The position differs
# per function, and assuming "the second argument" (as an earlier version did)
# reads the CONTENT argument of file.create() as its path.
# Every call that sends output to a destination, mapped to the position that
# destination sits in. NA means the destination is only ever named, as in
# `save(x, file = "out.rda")`. This is the single list the write-related checks
# share, so one of them cannot quietly know about a function the others do not.
WRITE_DEST_ARG <- list(
  # base and utils
  write.csv = 2L,
  write.csv2 = 2L,
  write.table = 2L,
  writeLines = 2L,
  writeBin = 2L,
  saveRDS = 2L,
  write = 2L,
  cat = NA_integer_,
  save = NA_integer_, # `save(x, y, file = "...")`: named only
  save.image = 1L,
  capture.output = NA_integer_, # `capture.output(x, file = "...")`
  file.create = 1L,
  dir.create = 1L,
  file.copy = 2L,
  file.rename = 2L,
  file.append = 1L,
  download.file = 2L,
  sink = 1L,
  # readr
  write_csv = 2L,
  write_csv2 = 2L,
  write_tsv = 2L,
  write_delim = 2L,
  write_excel_csv = 2L,
  write_rds = 2L,
  write_lines = 2L,
  write_file = 2L,
  # data.table, and the spreadsheet writers
  fwrite = 2L,
  write_xlsx = 2L,
  write.xlsx = 2L,
  saveWorkbook = 2L,
  # other serialisers
  write_json = 2L,
  write_yaml = 2L,
  write_parquet = 2L,
  write_feather = 2L,
  # graphics devices
  png = 1L,
  pdf = 1L,
  jpeg = 1L,
  tiff = 1L,
  bmp = 1L,
  svg = 1L,
  postscript = 1L,
  cairo_pdf = 1L,
  ggsave = 1L
)

# The functions the write checks look for. Derived from the map above so the two
# can never disagree about what counts as a write.
WRITE_FUNCTIONS <- names(WRITE_DEST_ARG)

# The formal a destination in second place follows: the data being written, or
# the source being copied. R binds named arguments first and fills the remaining
# formals in order, so `saveRDS(object = x, "out.rds")` sends "out.rds" to
# `file`. Naming this formal moves the destination up to the first unnamed
# argument; naming anything else, such as `sep =` or `row.names =`, leaves it
# where it was. write.csv() takes `...` and hands them to write.table().
WRITE_DATA_FORMAL <- c(
  write.csv = "x",
  write.csv2 = "x",
  write.table = "x",
  writeLines = "text",
  writeBin = "object",
  saveRDS = "object",
  write = "x",
  file.copy = "from",
  file.rename = "from",
  download.file = "url",
  write_csv = "x",
  write_csv2 = "x",
  write_tsv = "x",
  write_delim = "x",
  write_excel_csv = "x",
  write_rds = "x",
  write_lines = "x",
  write_file = "x",
  fwrite = "x",
  write_xlsx = "x",
  write.xlsx = "x",
  saveWorkbook = "wb",
  write_json = "x",
  write_yaml = "x",
  write_parquet = "x",
  write_feather = "x"
)

# Names a destination can travel under.
DEST_ARG_NAMES <- c(
  "file",
  "con",
  "path",
  "filename",
  "target",
  "destfile",
  "to", # file.copy(from, to) and file.rename(from, to)
  "sink" # arrow's write_parquet(x, sink = ...)
)

# magrittr's pipes that hand their left-hand side to the call on their right as
# its first argument. `%$%` exposes the names inside its left-hand side instead.
MAGRITTR_PIPES <- c("%>%", "%T>%", "%<>%", "%!>%")

# The expression piped into `call`, or NULL when `call` is not the right-hand
# side of `|>` or a magrittr pipe.
piped_value <- function(call) {
  op <- xml2::xml_find_first(
    call,
    sprintf(
      "preceding-sibling::*[1][self::PIPE or self::SPECIAL[%s]]",
      xp_text_in(MAGRITTR_PIPES)
    )
  )
  if (inherits(op, "xml_missing")) {
    return(NULL)
  }
  lhs <- xml2::xml_find_first(op, "preceding-sibling::expr[1]")
  if (inherits(lhs, "xml_missing")) NULL else lhs
}

# Is `arg` the pipe's placeholder? The native pipe's is `_`, which R accepts only
# as a named argument; magrittr's is a bare `.` argument. Either one tells the
# pipe where its left-hand side goes, and that it does not go first. A `.` inside
# an argument, as in `file.path(., "x")`, is not one.
is_pipe_placeholder <- function(arg) {
  xml2::xml_find_lgl(
    arg,
    "boolean(self::expr[count(*) = 1][PLACEHOLDER or SYMBOL[text() = '.']])"
  )
}

# The expression node a write call sends its output TO, or NULL.
#
# Arguments are matched the way R matches them. A named destination wins
# wherever it sits. Otherwise the destination is found among the UNNAMED
# arguments, since a named `sep =` takes no position, and a call on the right of
# a pipe takes the piped value as its first argument unless a placeholder puts it
# somewhere else.
write_destination <- function(node) {
  fn <- xml2::xml_text(node)
  call <- xml2::xml_find_first(node, "parent::expr/parent::expr")
  if (inherits(call, "xml_missing")) {
    return(NULL)
  }
  # A method shares a writer's name, not its arguments: htmltools' `tags$svg()`
  # builds a tag, and `adata$write()` is anndata's.
  member <- sprintf("not(self::*[%s])", NOT_MEMBER_ACCESS)
  if (xml2::xml_find_lgl(node, member)) {
    return(NULL)
  }
  piped <- piped_value(call)
  # A placeholder argument stands for the piped value.
  resolve <- function(arg) {
    if (!is.null(piped) && is_pipe_placeholder(arg)) piped else arg
  }

  named <- xml2::xml_find_first(
    call,
    sprintf(
      "./SYMBOL_SUB[%s]/following-sibling::expr[1]",
      xp_text_in(DEST_ARG_NAMES)
    )
  )
  if (!inherits(named, "xml_missing")) {
    return(resolve(named))
  }

  pos <- WRITE_DEST_ARG[[fn]]
  if (is.null(pos) || is.na(pos)) {
    return(NULL)
  }
  arg_names <- xml2::xml_text(xml2::xml_find_all(call, "./SYMBOL_SUB"))
  if (pos > 1L && WRITE_DATA_FORMAL[fn] %in% arg_names) {
    pos <- pos - 1L
  }

  if (!is.null(piped)) {
    args <- xml2::xml_find_all(call, "./expr[position() > 1]")
    placed <- any(vapply(args, is_pipe_placeholder, logical(1)))
    if (!placed) {
      if (pos == 1L) {
        return(piped)
      }
      pos <- pos - 1L
    }
  }

  # The call's expr children after the function name, less the named values.
  unnamed <- xml2::xml_find_all(
    call,
    "./expr[position() > 1][not(preceding-sibling::*[1][self::EQ_SUB])]"
  )
  if (pos > length(unnamed)) NULL else resolve(unnamed[[pos]])
}

# Is `dest` a path we can PROVE lands in the user's filespace?
#
# CRAN's rule is about writing to the user's filespace WITHOUT PERMISSION. A
# destination the caller handed in, or one computed at run time, is not something
# we can prove anything about, and flagging every `writeLines(x, out_file)` is
# the noise this package exists to avoid. Only a literal can be proven.
#
# `formals_with_unsafe_default` closes the obvious hole: a destination that IS a
# symbol, but a symbol that DEFAULTS to a literal home or absolute path, writes
# there whenever the caller omits it.
dest_is_unsafe_literal <- function(dest, formals_unsafe = character(0)) {
  if (is.null(dest)) {
    return(FALSE)
  }

  # tempfile()/tempdir() anywhere in the destination makes it safe by definition.
  if (
    length(xml2::xml_find_all(
      dest,
      ".//SYMBOL_FUNCTION_CALL[text() = 'tempfile' or text() = 'tempdir']"
    )) >
      0L
  ) {
    return(FALSE)
  }

  # Only the ROOT of a path decides where it lands. In
  # `file.path(temp_pkg, "NEWS.md")` the literal is just the basename, and the
  # root is a variable, so the write goes wherever temp_pkg points. Looking for a
  # string literal ANYWHERE in the destination flagged exactly this, in checktor's
  # own example_diagnose_scenario().
  root <- dest_root(dest)
  if (is.null(root)) {
    return(FALSE)
  }

  sym <- xml2::xml_text(xml2::xml_find_first(root, "./SYMBOL"))
  if (!is.na(sym)) {
    # Caller-supplied or computed: unprovable, unless it defaults somewhere bad.
    return(sym %in% formals_unsafe)
  }

  # A literal root is the one destination we can prove. An absolute or `~` root
  # writes to the user's filespace; a bare relative root writes to the working
  # directory, which CRAN forbids just the same.
  !is.na(xml2::xml_text(xml2::xml_find_first(root, "./STR_CONST")))
}

# The leading component of a path expression. `file.path(a, b)` is rooted at `a`,
# and `paste0(dir, "/x")` at `dir`; a bare symbol or literal is its own root.
dest_root <- function(node, depth = 0L) {
  if (is.null(node) || depth > 5L) {
    return(node)
  }
  callee <- xml2::xml_find_first(node, "./expr[1]/SYMBOL_FUNCTION_CALL")
  if (inherits(callee, "xml_missing")) {
    return(node)
  } # not a call: this IS the root
  first_arg <- xml2::xml_find_first(node, "./expr[2]")
  if (inherits(first_arg, "xml_missing")) {
    return(node)
  }
  dest_root(first_arg, depth + 1L)
}

# Formals of the innermost enclosing function whose DEFAULT expression matches
# `pred`, an XPath predicate evaluated on the default's expr node.
formals_with_default <- function(node, pred) {
  fn <- xml2::xml_find_first(node, "ancestor::expr[FUNCTION][1]")
  if (inherits(fn, "xml_missing")) {
    return(character(0))
  }
  hits <- xml2::xml_find_all(
    fn,
    sprintf(
      paste0(
        "./SYMBOL_FORMALS[following-sibling::*[1][self::EQ_FORMALS]]",
        "[following-sibling::*[2][self::expr][%s]]"
      ),
      pred
    )
  )
  xml2::xml_text(hits)
}

# Formals whose DEFAULT is a literal home or absolute path:
# `function(path = "~/data.csv")` writes to $HOME when called with no arguments.
formals_with_unsafe_default <- function(node) {
  formals_with_default(
    node,
    sprintf("STR_CONST[%s]", xp_str_starts(c("~", "/")))
  )
}

# A cache that lasts one checktor() run.
#
# Several checks read the same sources: a dozen walk every .Rd file, three
# categories parse R/, and five checks parse the code in examples and vignettes.
# Each used to parse its own copy, so a package's help pages were parsed a dozen
# times over and parse_Rd() was nearly half the run. Within a run the sources do
# not change, so the first parse is kept and handed to every later reader.
#
# The cache is on only while checktor() or a diagnose_*() category function is
# running. It starts empty and is emptied when that call exits, however it exits,
# so nothing carries over to the next run, where a file may have changed. A lab_*()
# check called on its own parses afresh, exactly as before.
.run_cache <- new.env(parent = emptyenv())

# Turn the cache on for the rest of the calling function, and empty it when that
# function exits. A nested call (checktor() running diagnose_code_issues()) finds
# it on already and leaves the teardown to the outer one.
local_run_cache <- function(envir = parent.frame()) {
  if (isTRUE(.run_cache$active)) {
    return(invisible(FALSE))
  }
  clear_run_cache()
  .run_cache$values <- new.env(parent = emptyenv())
  .run_cache$active <- TRUE
  do.call(
    base::on.exit,
    list(quote(clear_run_cache()), add = TRUE),
    envir = envir
  )
  invisible(TRUE)
}

clear_run_cache <- function() {
  rm(list = ls(.run_cache, all.names = TRUE), envir = .run_cache)
  invisible()
}

# The value of `compute()` under `key`, computed once per run. Outside a run it
# is computed every time. The warnings it raised and the error it ended with are
# kept with it and raised again on every read, so a caller that suppresses them,
# catches the error or lets them through sees exactly what a fresh parse would
# have given it.
run_cached <- function(key, compute) {
  if (!isTRUE(.run_cache$active)) {
    return(compute())
  }
  entry <- .run_cache$values[[key]]
  if (is.null(entry)) {
    warnings <- list()
    entry <- tryCatch(
      withCallingHandlers(
        list(value = compute(), error = NULL),
        warning = function(w) {
          warnings[[length(warnings) + 1L]] <<- w
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) list(value = NULL, error = e)
    )
    entry$warnings <- warnings
    assign(key, entry, envir = .run_cache$values)
  }
  for (w in entry$warnings) {
    warning(w)
  }
  if (!is.null(entry$error)) {
    stop(entry$error)
  }
  entry$value
}

# tools::parse_Rd() on one help page, parsed once per run. Every check that walks
# the .Rd files reads them through this.
read_rd <- function(file) {
  run_cached(paste0("rd:", file), function() parse_rd_file(file))
}

# The parse itself, apart so a test can count how often it happens.
parse_rd_file <- function(file) {
  tools::parse_Rd(file)
}

# The package's DESCRIPTION as read.dcf() returns it, read once per run, or NULL
# when the file is missing or R cannot read it. This is the raw record matrix:
# unlike read_description() it does not refuse a file with a blank line, so a
# reader that only wants a field or two sees what read.dcf() sees.
description_dcf <- function(path) {
  run_cached(paste0("dcf:", path), function() {
    desc_file <- file.path(path, "DESCRIPTION")
    if (!file.exists(desc_file)) {
      return(NULL)
    }
    tryCatch(read_dcf_quietly(desc_file), error = function(e) NULL)
  })
}

# One field of the package's DESCRIPTION, as a string, or NA when the file is
# missing, unreadable or has no such field. Read through description_dcf(), so
# every field a run asks for costs one read of the file between them.
description_value <- function(path, field) {
  dcf <- description_dcf(path)
  if (is.null(dcf) || nrow(dcf) == 0L || !field %in% colnames(dcf)) {
    return(NA_character_)
  }
  unname(dcf[1L, field])
}

# The package's DESCRIPTION as read_description() returns it, a named list of
# fields, read once per run; NULL when it is missing or read_description() refuses
# it. For a helper that reads a field or two for context and has nothing to report
# when the file is bad, since lab_description_file() reports that.
description_or_null <- function(path) {
  run_cached(paste0("description:", path), function() {
    tryCatch(
      read_description(file.path(path, "DESCRIPTION")),
      error = function(e) NULL
    )
  })
}

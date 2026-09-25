# Helpers for running the package's own help-page examples.

# The parsed help pages, keyed by file name ("lab_tf_usage.Rd"). From the source
# tree when there is one, so devtools::test() sees man/ as it is now rather than
# whatever copy of checktor is installed; from the installed package under
# R CMD check, where the tests run against that.
package_rd_db <- function() {
  root <- test_path("..", "..")
  if (file.exists(file.path(root, "DESCRIPTION")) && dir.exists(file.path(root, "man"))) {
    tools::Rd_db(dir = root)
  } else {
    tools::Rd_db("checktor")
  }
}

# Runs the examples of one help page and returns every result that `fn` gave
# while they ran, in call order. `fn` is replaced in the examples' environment by
# a wrapper that records what the real function returns, so the test sees the
# result the example demonstrates however the example chooses to show it.
# \dontrun{} code is not run, as in R CMD check.
run_rd_example <- function(rd, fn) {
  code <- withr::local_tempfile(fileext = ".R")
  tools::Rd2ex(rd, code, commentDontrun = TRUE, commentDonttest = FALSE)
  if (!file.exists(code)) {
    return(list())
  }
  seen <- list()
  real <- getExportedValue("checktor", fn)
  env <- new.env(parent = globalenv())
  assign(
    fn,
    function(...) {
      res <- real(...)
      seen[[length(seen) + 1L]] <<- res
      res
    },
    envir = env
  )
  utils::capture.output(sys.source(code, envir = env))
  seen
}

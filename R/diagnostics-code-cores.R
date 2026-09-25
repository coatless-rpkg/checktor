# Code checks for the number of cores package code asks for.

# Parallelism calls without an explicit per-call core bound. Looks for
# mclapply/parLapply/makeCluster/detectCores whose enclosing call has no
# `mc.cores =` named argument.
#' Diagnose Parallel Core Usage
#'
#' Flags a worker count that can exceed CRAN's two-core limit. Understands parallel, snow, foreach, future, furrr, mirai, RcppParallel, data.table, and BiocParallel.
#'
#' @section Source:
#' The [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
#' states that "If running a package uses multiple threads/cores it must never
#' use more than two simultaneously". See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to the package directory. Default: `"."`.
#' @param verbose Logical. Print diagnostic output. Default: `TRUE`.
#' @param parsed Optional pre-parsed source, as returned internally by the
#'   orchestrator. Defaults to parsing `path` afresh.
#'
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], which runs this and every other check.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/core_usage_bad.R",
#'                                  show_content = FALSE)
#' lab_core_usage(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_core_usage <- function(path = ".", verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("core_usage")))
  }

  # CRAN's rule is: "If running a package uses multiple threads/cores it must
  # never use more than two simultaneously." The prohibition is on USING more
  # than two, not on calling detectCores().
  #
  # The old rule required an `mc.cores` named argument on the call itself. But
  # `mc.cores` is an argument of mclapply()/pvec() ONLY: detectCores() takes no
  # arguments at all, makeCluster() takes `spec`, parLapply() takes a cluster. So
  # detectCores() could never satisfy it and was flagged 100% of the time, while
  # `makeCluster(2L)` -- explicitly CRAN-compliant -- was flagged too.
  #
  # What actually matters is the WORKER COUNT handed to each framework, measured
  # under `_R_CHECK_LIMIT_CORES_=TRUE` (the CRAN check environment):
  #
  #     parallel::detectCores()        -> 12   ignores the CRAN limit
  #     parallelly::availableCores()   ->  2   auto-caps
  #     future::availableCores()       ->  2   auto-caps
  #
  # So a worker count is risky when it is a literal above 2, or is derived from
  # detectCores(). It is safe when it comes from availableCores(), is capped at 2,
  # or sits in a function that guards on the CRAN environment variables.
  unbounded <- function(cl) {
    w <- worker_count_expr(cl, PARALLEL_WORKER_ARG[[xml2::xml_text(cl)]])
    # No explicit count: the framework defaults are all safe.
    !is.null(w) && worker_count_is_risky(w) && !has_cran_core_guard(cl)
  }
  issues <- xpath_filter(
    parsed,
    sprintf("//SYMBOL_FUNCTION_CALL[%s]", xp_text_in(names(PARALLEL_WORKER_ARG))),
    unbounded,
    function(file, nodes) fn_hits(file, nodes, " worker count is unbounded")
  )

  report_check(
    issues,
    verbose,
    check_label("core_usage"),
    "Core usage is bounded for CRAN",
    "Worker count may exceed the two cores CRAN allows",
    paste("Treatment:", treatments$core_usage$treatment),
    max_show = 3L
  )
}

# Worker-count argument per parallel framework. A name means a named argument;
# `1L` means the first positional argument.
PARALLEL_WORKER_ARG <- list(
  # parallel / snow
  mclapply = "mc.cores",
  mcmapply = "mc.cores",
  pvec = "mc.cores",
  makeCluster = 1L,
  makePSOCKcluster = 1L,
  makeForkCluster = 1L,
  # foreach backends
  registerDoParallel = "cores",
  registerDoMC = "cores",
  registerDoSNOW = 1L,
  # future / furrr (furrr inherits the plan, so plan() is the control point)
  plan = "workers",
  # mirai
  daemons = 1L,
  # RcppParallel
  setThreadOptions = "numThreads",
  # data.table
  setDTthreads = 1L,
  # BiocParallel
  MulticoreParam = "workers",
  SnowParam = "workers"
)

# The expression supplying the worker count for a call, or NULL when none is
# given (the framework defaults are all CRAN-safe).
worker_count_expr <- function(call_node, arg) {
  if (is.character(arg)) {
    e <- xml2::xml_find_first(
      call_node,
      sprintf(
        "parent::expr/parent::expr/SYMBOL_SUB[text() = '%s']/following-sibling::expr[1]",
        arg
      )
    )
  } else {
    # First positional argument. A named argument's value is also an <expr>
    # sibling, so require that it not be preceded by an EQ_SUB.
    e <- xml2::xml_find_first(
      call_node,
      "parent::expr/following-sibling::expr[1][not(preceding-sibling::*[1][self::EQ_SUB])]"
    )
  }
  if (inherits(e, "xml_missing")) NULL else e
}

# A worker count is risky when it is a numeric literal above 2, or is derived
# from detectCores(). availableCores() already caps itself at 2 under the CRAN
# check environment, so it is safe.
worker_count_is_risky <- function(w) {
  if (
    length(xml2::xml_find_all(
      w,
      ".//SYMBOL_FUNCTION_CALL[text() = 'availableCores']"
    ))
  ) {
    return(FALSE)
  }
  if (
    length(xml2::xml_find_all(
      w,
      ".//SYMBOL_FUNCTION_CALL[text() = 'detectCores']"
    ))
  ) {
    return(TRUE)
  }
  nums <- xml2::xml_find_all(w, "descendant-or-self::NUM_CONST")
  if (
    length(nums) == 1L &&
      length(xml2::xml_find_all(w, ".//SYMBOL_FUNCTION_CALL")) == 0L
  ) {
    n <- suppressWarnings(as.numeric(sub("L$", "", xml2::xml_text(nums))))
    return(!is.na(n) && n > 2)
  }
  FALSE # a bare variable: not resolvable statically, so do not guess
}

# TRUE when the enclosing function caps cores for CRAN, i.e. it mentions
# _R_CHECK_LIMIT_CORES_ or NOT_CRAN. This is the guard packages implement to cap
# cores under CRAN, and it is byte-for-byte R's own parallel:::.check_ncores predicate.
has_cran_core_guard <- function(call_node) {
  hits <- xml2::xml_find_all(
    call_node,
    paste0(
      "ancestor::expr[FUNCTION]//STR_CONST[",
      "  contains(text(), '_R_CHECK_LIMIT_CORES_') or contains(text(), 'NOT_CRAN')",
      "]"
    )
  )
  length(hits) > 0L
}

#' Diagnose Unguarded `detectCores()`
#'
#' Flags a `parallel::detectCores()` call whose result is used without an `NA`
#' guard.
#'
#' `?detectCores` says so in as many words: *"An integer, `NA` if the answer is
#' unknown"*, and R's own advice is to avoid it, *"First because it may return
#' `NA`"*. `NA` then propagates silently through the arithmetic packages usually
#' do next, and the failure surfaces far from its cause:
#'
#' ```r
#' n <- parallel::detectCores() - 1   # NA - 1 is NA
#' if (cores > n) cores <- n          # Error: missing value where TRUE/FALSE needed
#' ```
#'
#' This is a robustness defect rather than a policy one, and it is distinct from
#' the `core_usage` check, which asks how many cores you *use*. A package can cap
#' itself at two cores perfectly and still crash on the machine where
#' `detectCores()` returns `NA`.
#'
#' A call is treated as guarded when its enclosing function tests for `NA`
#' (`is.na()`), passes `na.rm = TRUE`, or supplies a fallback with `%||%`. The
#' durable fix is `parallelly::availableCores()`, which never returns `NA` and
#' also honours the CRAN core limit.
#'
#' @inheritParams lab_tf_usage
#' @section Source:
#' No formal rule. `?detectCores` states it returns "`NA` if the answer is
#' unknown", and the arithmetic that usually follows then crashes, which is why
#' this sits at `robustness` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/detect_cores_bad.R",
#'                                  show_content = FALSE)
#' lab_detect_cores_robustness(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_detect_cores_robustness <- function(
  path = ".",
  verbose = TRUE,
  parsed = NULL
) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("detect_cores_robustness")))
  }

  # Guarded when the enclosing function tests for NA, strips it, or defaults it.
  guarded <- paste0(
    "ancestor::expr[FUNCTION][1][",
    "  .//SYMBOL_FUNCTION_CALL[text() = 'is.na']",
    "  or .//SYMBOL_SUB[text() = 'na.rm']",
    "  or .//SPECIAL[text() = '%||%']",
    "]"
  )
  xpath <- sprintf(
    "//SYMBOL_FUNCTION_CALL[text() = 'detectCores'][not(%s)]",
    guarded
  )
  issues <- xpath_per_file(parsed, xpath, function(file, nodes) {
    line_hits(file, nodes, " (detectCores() may return NA)")
  })

  report_check(
    issues,
    verbose,
    check_label("detect_cores_robustness"),
    "{.code detectCores()} results are NA-guarded",
    "{.code detectCores()} result used without an {.code NA} guard",
    paste("Treatment:", treatments$detect_cores_robustness$treatment),
    level = "warning"
  )
}

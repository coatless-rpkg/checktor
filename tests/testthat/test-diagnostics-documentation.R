# ---- value tags --------------------------------------------------------------

test_that("diagnose_value_tags flags missing \\value{} in function topics", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\usage{fn(x)}",
        "\\description{No value tag here}"
      )
    )
  )
  res <- diagnose_value_tags(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(res$missing, "fn.Rd")
})

test_that("diagnose_value_tags accepts well-documented topics", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\usage{fn(x)}",
        "\\value{A character vector.}"
      )
    )
  )
  expect_true(diagnose_value_tags(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_value_tags skips data, class, package, and re-export topics", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "mydata.Rd" = c(
        "\\name{mydata}",
        "\\docType{data}",
        "\\title{mydata}",
        "\\format{A data frame}",
        "\\usage{data(mydata)}"
      ),
      "myclass.Rd" = c(
        "\\name{MyClass-class}",
        "\\docType{class}",
        "\\title{MyClass}"
      ),
      "pkg.Rd" = c(
        "\\name{pkg-package}",
        "\\alias{pkg-package}",
        "\\title{pkg}"
      ),
      "reexp.Rd" = c(
        "\\name{reexports}",
        "\\title{Objects exported from other packages}",
        "\\description{These are re-exports from other packages.}"
      )
    )
  )
  expect_true(diagnose_value_tags(pkg, verbose = FALSE)$passed)
})

# ---- example structure -------------------------------------------------------

test_that("diagnose_example_structure flags unjustified \\dontrun{}", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\value{1}",
        "\\examples{",
        "\\dontrun{",
        "  x <- 1 + 1",
        "}",
        "}"
      )
    )
  )
  res <- diagnose_example_structure(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("diagnose_example_structure accepts \\dontrun{} with a justifying keyword", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\value{1}",
        "\\examples{",
        "\\dontrun{",
        "  # Requires API token",
        "  authenticate(api_key = 'secret')",
        "}",
        "}"
      )
    )
  )
  expect_true(diagnose_example_structure(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_example_structure extracts only the \\examples{} block", {
  # Verifies the balanced-brace extractor doesn't bleed into other sections.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\value{1}",
        "\\examples{",
        "  x <- 1", # no \\dontrun here
        "}",
        "\\seealso{",
        "  \\dontrun{not-an-example}", # outside \\examples - must NOT trigger
        "}"
      )
    )
  )
  expect_true(diagnose_example_structure(pkg, verbose = FALSE)$passed)
})

# ---- roxygen usage -----------------------------------------------------------

# ---- missing examples --------------------------------------------------------

test_that("diagnose_missing_examples flags an exported topic without \\examples", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\alias{fn}",
        "\\title{fn}",
        "\\usage{fn(x)}",
        "\\value{A value.}"
      )
    )
  )
  writeLines("export(fn)", file.path(pkg, "NAMESPACE"))
  res <- diagnose_missing_examples(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(res$missing, "fn.Rd")
})

test_that("diagnose_missing_examples accepts an exported topic with \\examples", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\alias{fn}",
        "\\title{fn}",
        "\\value{A value.}",
        "\\examples{",
        "fn(1)",
        "}"
      )
    )
  )
  writeLines("export(fn)", file.path(pkg, "NAMESPACE"))
  expect_true(diagnose_missing_examples(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_missing_examples skips unexported topics and missing NAMESPACE", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\alias{fn}",
        "\\title{fn}",
        "\\value{1}"
      )
    )
  )
  writeLines("export(other)", file.path(pkg, "NAMESPACE"))
  expect_true(diagnose_missing_examples(pkg, verbose = FALSE)$passed)

  pkg2 <- make_temp_dir()
  write_pkg(
    pkg2,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\alias{fn}",
        "\\title{fn}",
        "\\value{1}"
      )
    )
  ) # no NAMESPACE at all
  expect_true(diagnose_missing_examples(pkg2, verbose = FALSE)$passed)
})

# ---- Suggested packages in examples ------------------------------------------

test_that("diagnose_suggested_in_examples flags unguarded Suggested-package use", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = "Suggests: dplyr",
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\value{1}",
        "\\examples{",
        "library(dplyr)",
        "dplyr::filter(x)",
        "}"
      )
    )
  )
  res <- diagnose_suggested_in_examples(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("diagnose_suggested_in_examples accepts a requireNamespace guard", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = "Suggests: dplyr",
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\value{1}",
        "\\examples{",
        "if (requireNamespace(\"dplyr\", quietly = TRUE)) {",
        "  library(dplyr)",
        "}",
        "}"
      )
    )
  )
  expect_true(diagnose_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_suggested_in_examples ignores usage inside \\dontrun", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = "Suggests: dplyr",
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\value{1}",
        "\\examples{",
        "\\dontrun{",
        "library(dplyr)",
        "}",
        "}"
      )
    )
  )
  expect_true(diagnose_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

test_that("diagnose_suggested_in_examples passes when the package has no Suggests", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "fn.Rd" = c(
        "\\name{fn}",
        "\\title{fn}",
        "\\value{1}",
        "\\examples{",
        "library(dplyr)",
        "}"
      )
    )
  )
  expect_true(diagnose_suggested_in_examples(pkg, verbose = FALSE)$passed)
})

# ---- commented_examples: prose vs commented-out code --------------------------

test_that("commented_examples does not flag ordinary prose comments", {
  # The old rule was "a comment containing an open paren", which flags English.
  # All 41 comment lines across the 9 Rd files this fired on in the wild were
  # prose; not one was a disabled call.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "foo.Rd" = c(
        "\\name{foo}",
        "\\alias{foo}",
        "\\title{Foo}",
        "\\usage{foo()}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "# Simulate random choices (default)",
        "# (Columns are attributes, rows are alternatives)",
        "# Example 2: Named categorical priors (more explicit)",
        "foo()",
        "}"
      )
    )
  )
  expect_true(diagnose_commented_examples(pkg, verbose = FALSE)$passed)
})

test_that("commented_examples flags an example that runs nothing", {
  # The real defect: every line that would demonstrate the function is commented
  # out, so the example block executes nothing at all.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "foo.Rd" = c(
        "\\name{foo}",
        "\\alias{foo}",
        "\\title{Foo}",
        "\\usage{foo()}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "# foo(slow = TRUE)",
        "# foo()",
        "}"
      )
    )
  )
  res <- diagnose_commented_examples(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "runs nothing", all = FALSE)
})

test_that("commented_examples allows a comment alongside live code", {
  # surveydown's examples comment out the server and .qmd snippets that belong in
  # the USER's files, then call sd_create_survey() for real. That is illustration,
  # not a disabled example, and flagging it flagged the docs for doing their job.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "foo.Rd" = c(
        "\\name{foo}",
        "\\alias{foo}",
        "\\title{Foo}",
        "\\usage{foo()}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "# Put this in your own app.R:",
        "# server <- function(input, output) {",
        "#   foo(reactive = TRUE)",
        "# }",
        "foo()",
        "}"
      )
    )
  )
  expect_true(diagnose_commented_examples(pkg, verbose = FALSE)$passed)
})

# ---- missing_examples honours \keyword{internal} ------------------------------

test_that("missing_examples exempts \\keyword{internal} topics", {
  # R's own checkRdContents grants keyword-internal pages substantive leniency,
  # keying off the keyword alone and never reading NAMESPACE.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = "deprecated_fn <- function() TRUE",
    rd_files = list(
      "deprecated_fn.Rd" = c(
        "\\name{deprecated_fn}",
        "\\alias{deprecated_fn}",
        "\\title{Old}",
        "\\usage{deprecated_fn()}",
        "\\description{Superseded.}",
        "\\value{x}",
        "\\keyword{internal}"
      )
    )
  )
  writeLines("export(deprecated_fn)", file.path(pkg, "NAMESPACE"))
  expect_true(diagnose_missing_examples(pkg, verbose = FALSE)$passed)
})

# ---- value_tags delegates to tools::checkRdContents ---------------------------

test_that("value_tags flags a missing \\value and exempts internal topics", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = "f <- function() TRUE",
    rd_files = list(
      "f.Rd" = c(
        "\\name{f}",
        "\\alias{f}",
        "\\title{F}",
        "\\usage{f()}",
        "\\description{d}"
      ), # missing \value
      "g.Rd" = c(
        "\\name{g}",
        "\\alias{g}",
        "\\title{G}",
        "\\usage{g()}",
        "\\description{d}",
        "\\keyword{internal}"
      ) # internal: exempt
    )
  )
  res <- diagnose_value_tags(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(res$issues, "f.Rd")
})

# --- roxygen_usage (rebuilt: NAMESPACE/roxygen drift, no clocks) ------------

# A roxygen-managed package: NAMESPACE carries the banner, so the check engages.
write_roxy_pkg <- function(pkg, r_code, namespace) {
  write_pkg(pkg, r_code = r_code)
  writeLines(
    c("# Generated by roxygen2: do not edit by hand", namespace),
    file.path(pkg, "NAMESPACE")
  )
  invisible(pkg)
}

test_that("roxygen_usage flags an @export that never reached NAMESPACE", {
  # The real cost of a forgotten devtools::document(): the function is tagged
  # for export, is not exported, and R CMD check says nothing.
  pkg <- make_temp_dir()
  write_roxy_pkg(
    pkg,
    r_code = c("#' Add", "#' @export", "add <- function(a, b) a + b"),
    namespace = character(0)
  )

  res <- diagnose_roxygen_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "add is tagged @export", all = FALSE)
})

test_that("roxygen_usage passes when the export is registered", {
  pkg <- make_temp_dir()
  write_roxy_pkg(
    pkg,
    r_code = c("#' Add", "#' @export", "add <- function(a, b) a + b"),
    namespace = "export(add)"
  )
  expect_true(diagnose_roxygen_usage(pkg, verbose = FALSE)$passed)
})

test_that("roxygen_usage counts an S3method registration as an export", {
  # `#' @export` on print.foo generates S3method(print, foo), not export().
  pkg <- make_temp_dir()
  write_roxy_pkg(
    pkg,
    r_code = c("#' Print", "#' @export", "print.foo <- function(x, ...) x"),
    namespace = "S3method(print,foo)"
  )
  expect_true(diagnose_roxygen_usage(pkg, verbose = FALSE)$passed)
})

test_that("roxygen_usage flags an Rd orphaned by a deleted source file", {
  pkg <- make_temp_dir()
  write_roxy_pkg(
    pkg,
    r_code = c("#' Add", "#' @export", "add <- function(a, b) a + b"),
    namespace = "export(add)"
  )
  dir.create(file.path(pkg, "man"), showWarnings = FALSE)
  writeLines(
    c(
      "% Generated by roxygen2: do not edit by hand",
      "% Please edit documentation in R/deleted.R",
      "\\name{gone}",
      "\\alias{gone}",
      "\\title{Gone}",
      "\\value{NULL}",
      "\\description{Gone}"
    ),
    file.path(pkg, "man", "gone.Rd")
  )

  res <- diagnose_roxygen_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "no longer exists", all = FALSE)
})

test_that("roxygen_usage ignores a package with a hand-written NAMESPACE", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c("#' Add", "#' @export", "add <- function(a, b) a + b")
  )
  writeLines("# hand maintained", file.path(pkg, "NAMESPACE"))
  expect_true(diagnose_roxygen_usage(pkg, verbose = FALSE)$passed)
})

test_that("roxygen_usage does not confuse @exportS3Method with @export", {
  pkg <- make_temp_dir()
  write_roxy_pkg(
    pkg,
    r_code = c(
      "#' Tidy",
      "#' @exportS3Method generics::tidy",
      "tidy.foo <- function(x, ...) x"
    ),
    namespace = "S3method(generics::tidy,foo)"
  )
  expect_true(diagnose_roxygen_usage(pkg, verbose = FALSE)$passed)
})

# --- unexported_example_namespace (restored as a static pre-flight) ---------

write_unexported_rd <- function(pkg, examples) {
  dir.create(file.path(pkg, "man"), showWarnings = FALSE)
  writeLines(
    c(
      "\\name{helper}",
      "\\alias{helper}",
      "\\title{Helper}",
      "\\description{A helper.}",
      "\\value{NULL}",
      paste0("\\examples{", examples, "}")
    ),
    file.path(pkg, "man", "helper.Rd")
  )
}

test_that("unexported_example_namespace flags a bare call to an unexported topic", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(add)", file.path(pkg, "NAMESPACE"))
  write_unexported_rd(pkg, "helper(1)")

  res <- diagnose_unexported_example_namespace(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "helper", all = FALSE)
})

test_that("unexported_example_namespace accepts a ::: -qualified call", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(add)", file.path(pkg, "NAMESPACE"))
  write_unexported_rd(pkg, "pkg:::helper(1)")

  expect_true(
    diagnose_unexported_example_namespace(pkg, verbose = FALSE)$passed
  )
})

test_that("unexported_example_namespace ignores \\dontrun{} examples", {
  # \dontrun{} is never executed, so a bare call there cannot fail. R CMD check
  # would not run it either.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(add)", file.path(pkg, "NAMESPACE"))
  write_unexported_rd(pkg, "\\dontrun{helper(1)}")

  expect_true(
    diagnose_unexported_example_namespace(pkg, verbose = FALSE)$passed
  )
})

test_that("unexported_example_namespace does not flag an exported topic", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(helper)", file.path(pkg, "NAMESPACE"))
  write_unexported_rd(pkg, "helper(1)")

  expect_true(
    diagnose_unexported_example_namespace(pkg, verbose = FALSE)$passed
  )
})

# --- what the parse tree buys these two checks ------------------------------
# Each case below is one the previous regex implementation got wrong.

test_that("roxygen_usage sees an assignment split across lines", {
  # `add <-` and `function(a, b)` on separate lines. A "regex the next line for
  # `name <-`" approach misses this entirely.
  pkg <- make_temp_dir()
  write_roxy_pkg(
    pkg,
    r_code = c("#' Add", "#' @export", "add <-", "  function(a, b) a + b"),
    namespace = character(0)
  )
  res <- diagnose_roxygen_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "add is tagged @export", all = FALSE)
})

test_that("roxygen_usage reads a backticked or `=` assigned name", {
  pkg <- make_temp_dir()
  write_roxy_pkg(
    pkg,
    r_code = c("#' Odd", "#' @export", "`odd name` = function() NULL"),
    namespace = character(0)
  )
  res <- diagnose_roxygen_usage(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_match(res$issues, "odd name", all = FALSE)
})

test_that("roxygen_usage ignores an @export inside a string or a plain comment", {
  # Neither is a roxygen tag. Only a `#'` COMMENT token counts.
  pkg <- make_temp_dir()
  write_roxy_pkg(
    pkg,
    r_code = c(
      "# @export not_a_tag",
      "tag <- \"#' @export also_not_a_tag\"",
      "helper <- function() NULL"
    ),
    namespace = character(0)
  )
  expect_true(diagnose_roxygen_usage(pkg, verbose = FALSE)$passed)
})

test_that("unexported_example_ns ignores a call named only in a comment or string", {
  # The exact false positive the AST rewrite exists to prevent.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(add)", file.path(pkg, "NAMESPACE"))
  write_unexported_rd(
    pkg,
    paste(
      "# you could call helper(1) yourself",
      "msg <- \"helper(2)\"",
      sep = "\n"
    )
  )
  expect_true(
    diagnose_unexported_example_namespace(pkg, verbose = FALSE)$passed
  )
})

test_that("unexported_example_ns is not fooled by a same-named object that is not a call", {
  # `helper` as a value, never invoked, is not a namespace problem.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines("export(add)", file.path(pkg, "NAMESPACE"))
  write_unexported_rd(pkg, "x <- list(helper = 1)")
  expect_true(
    diagnose_unexported_example_namespace(pkg, verbose = FALSE)$passed
  )
})

test_that("package_exports reads a MULTI-LINE export( block", {
  # The bug that broke everything. The old reader regexed NAMESPACE line by line,
  # so an export( block spanning lines lost every name after the first. On the
  # real `digest` package it returned exactly one entry, the string "AES,"
  # (trailing comma included), when the truth is nine exports -- so digest::digest()
  # itself was reported as unexported.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c(
      "export(AES,",
      "       digest,",
      "       digest2int,",
      "       hmac)",
      "S3method(\"[\",foo)",
      "S3method(\"names<-\",foo)",
      "S3method(print,foo)"
    ),
    file.path(pkg, "NAMESPACE")
  )

  ex <- package_exports(pkg)
  expect_true(all(c("AES", "digest", "digest2int", "hmac") %in% ex$names))
  expect_true(all(c("[.foo", "names<-.foo", "print.foo") %in% ex$names))
})

test_that("package_exports honours exportPattern()", {
  # A name can be exported without ever being listed.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines('exportPattern("^[^.]")', file.path(pkg, "NAMESPACE"))
  ex <- package_exports(pkg)
  expect_true(name_is_exported("visible_fn", ex))
  expect_false(name_is_exported(".hidden_fn", ex))
})

test_that("package_exports returns NULL when it cannot read NAMESPACE, and callers then skip", {
  # "Cannot tell" must never become "is unexported". Guessing here is how a check
  # starts accusing a package's flagship function of not existing.
  pkg <- make_temp_dir()
  write_pkg(pkg) # write_pkg writes no NAMESPACE
  expect_false(file.exists(file.path(pkg, "NAMESPACE")))
  expect_null(package_exports(pkg))
  expect_true(name_is_exported("anything", NULL))
})

test_that("roxygen_usage accepts an @export on a non-syntactic S3 method", {
  pkg <- make_temp_dir()
  write_roxy_pkg(
    pkg,
    r_code = c(
      "#' Subset",
      "#' @export",
      "`[.foo` <- function(x, i) x",
      "#' Rename",
      "#' @export",
      "`names<-.foo` <- function(x, value) x"
    ),
    namespace = c("S3method(\"[\",foo)", "S3method(\"names<-\",foo)")
  )
  expect_true(diagnose_roxygen_usage(pkg, verbose = FALSE)$passed)
})

test_that("example_structure accepts \\dontrun{} around a shiny reactive context", {
  # surveydown's examples define server <- function(input, output, session),
  # which cannot run outside a live app -- but never say the word "shiny", so a
  # literal search for it reported three correct \dontrun{} blocks as needless.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "sd_value.Rd" = c(
        "\\name{sd_value}",
        "\\alias{sd_value}",
        "\\title{v}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "\\dontrun{",
        "  server <- function(input, output, session) {",
        "    age <- sd_value(age)",
        "  }",
        "}",
        "}"
      )
    )
  )
  expect_true(diagnose_example_structure(pkg, verbose = FALSE)$passed)
})

test_that("example_structure accepts an install/launcher \\dontrun{} with a placeholder path", {
  # shinyelectron ships install_*() and run_electron_app("path/to/app") examples:
  # they install software or open a placeholder path, so \dontrun{} is justified.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "launch.Rd" = c(
        "\\name{launch}",
        "\\alias{launch}",
        "\\title{l}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "\\dontrun{",
        "  install_nodejs()",
        "  run_electron_app(\"path/to/electron/app\")",
        "}",
        "}"
      )
    )
  )
  expect_true(diagnose_example_structure(pkg, verbose = FALSE)$passed)
})

test_that("example_structure still flags \\dontrun{} with no justification", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    rd_files = list(
      "add.Rd" = c(
        "\\name{add}",
        "\\alias{add}",
        "\\title{a}",
        "\\description{d}",
        "\\value{x}",
        "\\examples{",
        "\\dontrun{",
        "  add(1, 2)",
        "}",
        "}"
      )
    )
  )
  expect_false(diagnose_example_structure(pkg, verbose = FALSE)$passed)
})

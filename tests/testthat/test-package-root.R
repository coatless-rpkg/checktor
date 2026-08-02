# checktor is meant to run from anywhere inside a package tree, rather than only
# from the directory holding DESCRIPTION. These tests pin that behaviour down.

test_that("find_package_root returns a root path untouched", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # Returned verbatim, so an existing caller sees exactly what it passed in.
  expect_identical(find_package_root(pkg), pkg)
})

test_that("find_package_root walks up from a subdirectory", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "tests", "testthat"), recursive = TRUE)
  real <- normalizePath(pkg, winslash = "/")

  for (sub in c("R", "man", file.path("tests", "testthat"))) {
    found <- find_package_root(file.path(pkg, sub))
    expect_equal(normalizePath(found, winslash = "/"), real)
  }
})

test_that("find_package_root accepts a file inside the package", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  found <- find_package_root(file.path(pkg, "R", "test.R"))
  expect_equal(
    normalizePath(found, winslash = "/"),
    normalizePath(pkg, winslash = "/")
  )
})

test_that("find_package_root leaves a non-package path alone", {
  # No DESCRIPTION anywhere above a temp directory, so the caller still gets the
  # path it asked about and can report against that.
  bare <- make_temp_dir()
  expect_identical(find_package_root(bare), bare)
  expect_identical(find_package_root("/no/such/directory"), "/no/such/directory")
})

test_that("find_package_root stops at the nearest root", {
  outer <- make_temp_dir()
  write_pkg(outer, package = "outerpkg")
  inner <- file.path(outer, "inst", "innerpkg")
  dir.create(inner, recursive = TRUE)
  write_pkg(inner, package = "innerpkg")

  found <- find_package_root(file.path(inner, "R"))
  expect_equal(
    normalizePath(found, winslash = "/"),
    normalizePath(inner, winslash = "/")
  )
})

test_that("checktor() from a subdirectory matches a run from the root", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  from_root <- checktor(pkg, verbose = FALSE, progress = FALSE)
  from_sub <- checktor(file.path(pkg, "R"), verbose = FALSE, progress = FALSE)

  expect_equal(tidy(from_sub)$check, tidy(from_root)$check)
  expect_equal(tidy(from_sub)$passed, tidy(from_root)$passed)
  expect_equal(n_issues(from_sub), n_issues(from_root))
})

test_that("checktor() resolves the package from the working directory", {
  pkg <- make_temp_dir()
  write_pkg(pkg)

  owd <- setwd(file.path(pkg, "R"))
  # `after = FALSE` so the working directory is restored BEFORE make_temp_dir()'s
  # deferred unlink runs. Windows refuses to remove a directory that is a
  # process's working directory.
  on.exit(setwd(owd), add = TRUE, after = FALSE)
  res <- checktor(verbose = FALSE, progress = FALSE) # path defaults to "."
  expect_s3_class(res, "checktor_results")
  expect_true(is_healthy(res))
})

test_that("every path-taking entry point resolves the root as its first act", {
  # The regression this guards against is a new check forgetting the resolution
  # line. Comparing results alone cannot see that, because a check pointed at the
  # wrong directory finds no R/ and passes, exactly as it does on a clean package.
  # So assert the invariant directly against the parsed body.
  resolves <- quote(path <- find_package_root(path))
  ns <- asNamespace("checktor")

  path_first <- Filter(
    function(nm) {
      f <- get(nm, envir = ns)
      is.function(f) && identical(names(formals(f))[[1L]], "path")
    },
    sort(getNamespaceExports("checktor"))
  )
  # checkup() delegates straight to checktor(), which resolves, and
  # find_package_root() is the resolver itself.
  path_first <- setdiff(path_first, c("checkup", "find_package_root"))
  expect_gt(length(path_first), 55L)

  for (nm in path_first) {
    body_expr <- body(get(nm, envir = ns))
    first <- if (identical(body_expr[[1L]], as.name("{"))) {
      body_expr[[2L]]
    } else {
      body_expr
    }
    expect_identical(first, resolves, info = nm)
  }
})

test_that("checks called from a subdirectory find the same real issues", {
  # A fixture that actually trips checks, so the comparison below has teeth: a
  # check that failed to resolve would report nothing and the equality would break.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    title = "a title that is not in title case",
    r_code = c(
      "bad.R" = paste(
        "f <- function(x) {",
        "  set.seed(42)",
        "  y <- T",
        "  print(y)",
        "  invisible(x)",
        "}",
        sep = "\n"
      )
    )
  )
  sub <- file.path(pkg, "R")

  named <- c(
    "lab_tf_usage", "lab_seed_setting", "lab_print_cat_usage",
    "lab_title_case", "diagnose_code_issues"
  )
  found <- 0L
  for (nm in named) {
    fn <- get(nm, envir = asNamespace("checktor"))
    from_root <- fn(pkg, verbose = FALSE)
    from_sub <- fn(sub, verbose = FALSE)
    expect_equal(from_sub$passed, from_root$passed, info = nm)
    expect_equal(from_sub$issues, from_root$issues, info = nm)
    found <- found + length(from_sub$issues)
  }
  # Proves the comparisons above were not all trivially empty.
  expect_gt(found, 0L)

  # The helpers that take a path but no verbose flag resolve it too.
  expect_equal(length(read_r_xml(sub)), length(read_r_xml(pkg)))
  expect_equal(checkup(sub), checkup(pkg))
})

test_that("a directory outside any package still errors clearly", {
  bare <- make_temp_dir()
  expect_error(
    checktor(bare, verbose = FALSE, progress = FALSE),
    "any directory above it"
  )
})

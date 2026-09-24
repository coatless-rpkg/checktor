# Test build_ignore_matcher() ----

test_that("build_ignore_matcher(): recognises .Rbuildignore entries", {
  pkg <- make_temp_dir()
  writeLines(c("^foo/", "^bar\\.txt$"), file.path(pkg, ".Rbuildignore"))
  matcher <- build_ignore_matcher(pkg)
  expect_true(matcher("foo/anything.R"))
  expect_true(matcher("bar.txt"))
  expect_false(matcher("baz.R"))
})

test_that("build_ignore_matcher(): always skips .git and friends", {
  pkg <- make_temp_dir()
  matcher <- build_ignore_matcher(pkg) # no .Rbuildignore present
  expect_true(matcher(".git/HEAD"))
  expect_true(matcher(".Rproj.user/foo"))
  expect_false(matcher("R/code.R"))
})

test_that("build_ignore_matcher(): honours a bare directory pattern ^docs$", {
  # R CMD build excludes a matched directory's whole subtree, so a top-level
  # `^docs$` drops every file under docs/. Matching a leaf path alone missed this
  # and counted a pkgdown docs/ or a .quarto cache against the size limit.
  pkg <- make_temp_dir()
  writeLines(c("^docs$", "^\\.quarto$"), file.path(pkg, ".Rbuildignore"))
  matcher <- build_ignore_matcher(pkg)
  expect_true(matcher("docs/index.html"))
  expect_true(matcher("docs/reference/foo.html"))
  expect_true(matcher(".quarto/cache.bin"))
  expect_true(matcher("DOCS/index.html")) # case-insensitive, as in R
  expect_false(matcher("R/code.R"))
  expect_false(matcher("documentation.R")) # not the docs/ directory
})

# Test list_included_files() ----

test_that("list_included_files(): returns the matching files under subdir", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "vignettes"))
  writeLines("x", file.path(pkg, "vignettes", "intro.Rmd"))
  writeLines("x", file.path(pkg, "vignettes", "notes.txt"))
  expect_equal(
    basename(list_included_files(pkg, "vignettes", "\\.Rmd$")),
    "intro.Rmd"
  )
})

test_that("list_included_files(): drops what .Rbuildignore excludes", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "vignettes", "articles"), recursive = TRUE)
  writeLines("x", file.path(pkg, "vignettes", "intro.Rmd"))
  writeLines("x", file.path(pkg, "vignettes", "articles", "extra.Rmd"))
  writeLines("^vignettes/articles$", file.path(pkg, ".Rbuildignore"))
  expect_equal(
    basename(list_included_files(pkg, "vignettes", "\\.Rmd$", recursive = TRUE)),
    "intro.Rmd"
  )
})

test_that("list_included_files(): descends only when asked", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "vignettes", "articles"), recursive = TRUE)
  writeLines("x", file.path(pkg, "vignettes", "articles", "extra.Rmd"))
  expect_identical(
    list_included_files(pkg, "vignettes", "\\.Rmd$"),
    character(0)
  )
  expect_equal(
    basename(list_included_files(pkg, "vignettes", "\\.Rmd$", recursive = TRUE)),
    "extra.Rmd"
  )
})

test_that("list_included_files(): is empty when the directory is absent", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_identical(
    list_included_files(pkg, "vignettes", "\\.Rmd$"),
    character(0)
  )
})

# Test list_rd_files() ----

test_that("list_rd_files(): returns man/*.Rd and nothing else", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("a.Rd" = "\\name{a}", "b.Rd" = "\\name{b}"))
  dir.create(file.path(pkg, "man", "figures"), recursive = TRUE)
  writeLines("x", file.path(pkg, "man", "figures", "logo.png"))
  writeLines("notes", file.path(pkg, "man", "README.txt"))
  expect_equal(sort(basename(list_rd_files(pkg))), c("a.Rd", "b.Rd"))
})

test_that("list_rd_files(): drops the topics .Rbuildignore holds back", {
  # {devtag}'s @dev tag writes exactly this: an .Rd plus an .Rbuildignore line
  # naming it, so the topic never enters the tarball.
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("a.Rd" = "\\name{a}", "dev.Rd" = "\\name{dev}"))
  writeLines("^man/dev\\.Rd$", file.path(pkg, ".Rbuildignore"))
  expect_equal(basename(list_rd_files(pkg)), "a.Rd")
})

test_that("list_rd_files(): keeps man/ when .Rbuildignore is about something else", {
  pkg <- make_temp_dir()
  write_pkg(pkg, rd_files = list("a.Rd" = "\\name{a}"))
  writeLines(c("^docs$", "^README\\.Rmd$"), file.path(pkg, ".Rbuildignore"))
  expect_equal(basename(list_rd_files(pkg)), "a.Rd")
})

test_that("list_rd_files(): is empty when there is no man/", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  unlink(file.path(pkg, "man"), recursive = TRUE)
  expect_identical(list_rd_files(pkg), character(0))
})

# Test vignette_r_code() ----

test_that("vignette_r_code(): keeps every code line on its line in the file", {
  # A finding names the line to open, so prose and fences become blank lines
  # rather than disappearing and pulling the code up the file.
  f <- withr::local_tempfile(fileext = ".Rmd")
  writeLines(
    c(
      "---", "title: v", "---",
      "Prose that names `download.file()`.",
      "```{r}", "x <- 1", "```",
      "More prose.",
      "```{r}", "y <- 2", "```"
    ),
    f
  )
  expect_identical(
    vignette_r_code(f),
    paste(c(rep("", 5), "x <- 1", rep("", 3), "y <- 2", ""), collapse = "\n")
  )
})

test_that("vignette_r_code(): skips a chunk whose options say eval false", {
  f <- withr::local_tempfile(fileext = ".Rmd")
  writeLines(
    c(
      "```{r eval=FALSE}", "a()", "```", # knitr, in the header
      "```{r}", "#| eval: false", "b()", "```", # Quarto
      "```{r}", "#| echo = FALSE, eval = F", "c()", "```", # knitr, in the chunk
      "```{r eval=FALSE}", "#| eval: true", "d()", "```", # the chunk option wins
      "```{r}", "#| echo: false", "e()", "```", # not about eval
      "```{r}", "f() #| eval: false", "```" # not an option line
    ),
    f
  )
  lines <- strsplit(vignette_r_code(f), "\n", fixed = TRUE)[[1L]]
  expect_equal(
    grep("^[a-z]\\(\\)", lines, value = TRUE),
    c("d()", "e()", "f() #| eval: false")
  )
})

test_that("vignette_r_code(): reads the code chunks of an Sweave vignette", {
  f <- withr::local_tempfile(fileext = ".Rnw")
  writeLines(
    c(
      "\\documentclass{article}",
      "\\begin{document}",
      "<<setup, echo=FALSE>>=",
      "x <- 1",
      "@",
      "Prose with \\Sexpr{x}.",
      "<<eval=false>>=",
      "not_run()",
      "@",
      "<<>>=",
      "<<setup>>",
      "y <- 2",
      "@ % end",
      "\\end{document}"
    ),
    f
  )
  lines <- strsplit(vignette_r_code(f), "\n", fixed = TRUE)[[1L]]
  # A `<<setup>>` line reuses another chunk's code and is not R itself.
  expect_equal(which(nzchar(lines)), c(4L, 12L))
  expect_equal(lines[c(4L, 12L)], c("x <- 1", "y <- 2"))
})

test_that("vignette_r_code(): ends an Sweave chunk at the next chunk header", {
  # Sweave needs no `@` between two chunks. The next header opens a chunk with
  # options of its own, and is not code of the chunk before it.
  f <- withr::local_tempfile(fileext = ".Rnw")
  writeLines(
    c("<<a>>=", "x()", "<<b, eval=FALSE>>=", "y()", "<<c>>=", "z()", "@"),
    f
  )
  code <- vignette_r_code(f)
  lines <- strsplit(code, "\n", fixed = TRUE)[[1L]]
  expect_equal(which(nzchar(lines)), c(2L, 6L))
  expect_true(parses(code))
})

test_that("vignette_r_code(): reads a chunk header to its last brace", {
  # A figure caption can hold braces of its own, as LaTeX does. knitr reads the
  # header to the brace that ends the line, so an eval after the caption counts.
  f <- withr::local_tempfile(fileext = ".Rmd")
  writeLines(
    c(
      "```{r, fig.cap = 'Estimates of $\\hat{\\beta}$', eval = FALSE}", "a()", "```",
      "```{r, fig.cap = 'A {b} c'}", "b()", "```"
    ),
    f
  )
  lines <- strsplit(vignette_r_code(f), "\n", fixed = TRUE)[[1L]]
  expect_equal(which(nzchar(lines)), 5L)
})

test_that("vignette_r_code(): reads every YAML spelling of a false eval", {
  # knitr reads `#|` options with the yaml package, where n, no and off are false
  # as well, and it evaluates an `!expr` value. Only a literal false is false.
  f <- withr::local_tempfile(fileext = ".qmd")
  writeLines(
    c(
      "```{r}", "#| eval: n", "a()", "```",
      "```{r}", "#| eval: No", "b()", "```",
      "```{r}", "#| eval: OFF # later", "c()", "```",
      "```{r}", "#| eval: !expr FALSE", "d()", "```",
      "```{r}", "#| eval: !expr F", "e()", "```",
      "```{r}", "#| eval: y", "f()", "```",
      "```{r}", "#| eval: !expr has_key()", "g()", "```",
      "```{r}", "#| eval: nope", "h()", "```"
    ),
    f
  )
  lines <- strsplit(vignette_r_code(f), "\n", fixed = TRUE)[[1L]]
  expect_equal(
    grep("^[a-z]\\(\\)", lines, value = TRUE),
    c("f()", "g()", "h()")
  )
})

test_that("vignette_r_code(): reads an option line only after '#| '", {
  # knitr takes a line as a chunk option only when it starts `#| `. Without the
  # space the line is a comment, so the first chunk runs, and the third keeps
  # the eval = FALSE in its header.
  f <- withr::local_tempfile(fileext = ".Rmd")
  writeLines(
    c(
      "```{r}", "#|eval: no", "a()", "```",
      "```{r}", "#| eval: no", "b()", "```",
      "```{r eval=FALSE}", "#|eval: true", "c()", "```"
    ),
    f
  )
  lines <- strsplit(vignette_r_code(f), "\n", fixed = TRUE)[[1L]]
  expect_equal(grep("^[a-z]\\(\\)", lines, value = TRUE), "a()")
})

# Test cli_literal() ----

test_that("cli_literal(): text reaches the console verbatim, never evaluated", {
  # cli glue-interpolates what it prints, so a `{...}` quoted from the package
  # under check would otherwise run as R code or vanish.
  x <- c("items/{stop('evaluated')}", "\\dontrun{}", "a { b", "}} and {?s}")
  out <- cli::cli_fmt(cli::cli_ul(cli_literal(x)))
  for (item in x) {
    expect_match(paste(out, collapse = "\n"), item, fixed = TRUE)
  }
})

# Test configure_doctor() ----

test_that("configure_doctor(): changes the defaults consumed by checktor", {
  # configure_doctor() also sets cli.num_colors, so that is restored too.
  withr::local_options(
    checktor.verbose = NULL,
    checktor.progress = NULL,
    cli.num_colors = getOption("cli.num_colors")
  )

  expect_message(
    configure_doctor(verbose_default = FALSE, progress_default = FALSE),
    "configuration updated"
  )
  expect_false(getOption("checktor.verbose"))
  expect_false(getOption("checktor.progress"))

  # Default args of checktor() should now resolve to FALSE. cli output is a
  # message, not an error, so expect_no_error() would stay green through a run
  # that printed all of its diagnostics. Silence is the only proof.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_length(cli::cli_fmt(checktor(pkg)), 0L)
})

# Test safe_read_lines() ----

test_that("safe_read_lines(): handles missing files", {
  expect_equal(
    safe_read_lines(file.path(tempdir(), "definitely-missing.R")),
    character(0)
  )
})

# Test find_package_root() ----

# checktor is meant to run from anywhere inside a package tree, rather than only
# from the directory holding DESCRIPTION. These tests pin that behaviour down.

test_that("find_package_root(): returns a root path untouched", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # Returned verbatim, so an existing caller sees exactly what it passed in.
  expect_identical(find_package_root(pkg), pkg)
})

test_that("find_package_root(): walks up from a subdirectory", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "tests", "testthat"), recursive = TRUE)
  real <- normalizePath(pkg, winslash = "/")

  for (sub in c("R", "man", file.path("tests", "testthat"))) {
    found <- find_package_root(file.path(pkg, sub))
    expect_equal(normalizePath(found, winslash = "/"), real)
  }
})

test_that("find_package_root(): accepts a file inside the package", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  found <- find_package_root(file.path(pkg, "R", "test.R"))
  expect_equal(
    normalizePath(found, winslash = "/"),
    normalizePath(pkg, winslash = "/")
  )
})

test_that("find_package_root(): leaves a non-package path alone", {
  # No DESCRIPTION anywhere above a temp directory, so the caller still gets the
  # path it asked about and can report against that.
  skip_if_tempdir_in_package()
  bare <- make_temp_dir()
  expect_identical(find_package_root(bare), bare)
  expect_identical(find_package_root("/no/such/directory"), "/no/such/directory")
})

test_that("find_package_root(): stops at the nearest root", {
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

test_that("find_package_root(): every path-taking entry point resolves first", {
  # The regression this guards against is a new check forgetting the resolution
  # line. Comparing results alone cannot see that, because a check pointed at the
  # wrong directory finds no R/ and passes, exactly as it does on a clean package.
  # So assert the invariant directly against the parsed body. covr rewrites
  # function bodies to count lines, so this cannot hold under coverage; R CMD
  # check still runs it.
  skip_on_covr()
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

test_that("find_package_root(): subdirectory checks find the same issues", {
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

# Test checkup() ----

test_that("checkup(): follows the verdict, so opinion does not fail CI", {
  # checkup() is the CI wrapper. A convention nobody enforces must not break a
  # build, or the tiers bought us nothing.
  pkg <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  expect_false(checkup(pkg)) # tf_usage is robustness: fails the build

  # A package whose ONLY finding is a convention (no NEWS file) still passes CI.
  clean <- make_temp_dir()
  write_pkg(clean, news = FALSE)
  expect_true(checkup(clean))
  expect_false(checkup(clean, severity = SEVERITY_LEVELS)) # unless you ask for it
})

test_that("checkup(): fails a package whose DESCRIPTION R cannot read", {
  # R CMD build and INSTALL both stop on it, so no build should go green.
  expect_false(checkup(unparseable_pkg()))
})

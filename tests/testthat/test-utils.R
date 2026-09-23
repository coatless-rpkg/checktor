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

# Test read_r_xml() ----

test_that("read_r_xml(): parses every R/*.R file and reports per-file errors", {
  # A DESCRIPTION, so read_r_xml()'s root search stops here rather than walking
  # up from tempdir().
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = NULL)
  writeLines("f <- function() 1", file.path(pkg, "R", "good.R"))
  writeLines("this is not valid", file.path(pkg, "R", "broken.R"))

  parsed <- read_r_xml(pkg)
  expect_equal(length(parsed), 2L)
  ok <- parsed[[file.path(pkg, "R", "good.R")]]
  bad <- parsed[[file.path(pkg, "R", "broken.R")]]
  expect_null(ok$error)
  expect_false(is.null(ok$xml))
  expect_false(is.null(bad$error))
  expect_true(is.null(bad$xml))
})

# Test undesirable_function_check() ----

test_that("undesirable_function_check(): ignores function names in strings", {
  # A DESCRIPTION, so read_r_xml()'s root search stops here rather than walking
  # up from tempdir().
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = NULL)
  writeLines(
    c(
      "msg <- 'browser() reminder'",
      "f <- function() browser()"
    ),
    file.path(pkg, "R", "f.R")
  )
  parsed <- read_r_xml(pkg)
  hits <- undesirable_function_check(parsed, "browser", label = FALSE)
  expect_equal(length(hits), 1L)
  expect_match(hits, "f\\.R:2")
})

# Test extract_rd_section() ----

test_that("extract_rd_section(): finds a top-level Rd section by tag", {
  rd_file <- withr::local_tempfile(fileext = ".Rd")
  writeLines(
    c(
      "\\name{x}",
      "\\title{Title}",
      "\\value{a number}"
    ),
    rd_file
  )
  rd <- tools::parse_Rd(rd_file)
  val <- extract_rd_section(rd, "\\value")
  expect_false(is.null(val))
  expect_match(collect_rd_text(val), "a number")
  expect_null(extract_rd_section(rd, "\\seealso"))
})

# Test collect_rd_text() ----

test_that("collect_rd_text(): honours the skip argument", {
  rd_file <- withr::local_tempfile(fileext = ".Rd")
  writeLines(
    c(
      "\\name{x}",
      "\\title{Title}",
      "\\value{1}",
      "\\examples{",
      "  visible_part()",
      "  \\dontrun{ hidden_part() }",
      "}"
    ),
    rd_file
  )
  rd <- tools::parse_Rd(rd_file)
  ex <- extract_rd_section(rd, "\\examples")
  full <- collect_rd_text(ex)
  expect_match(full, "visible_part")
  expect_match(full, "hidden_part")
  skipped <- collect_rd_text(ex, skip = "\\dontrun")
  expect_match(skipped, "visible_part")
  expect_false(grepl("hidden_part", skipped))
})

# Test is_commented_out_code() ----

test_that("is_commented_out_code(): separates prose from commented-out calls", {
  prose <- c(
    "# --- end", # separator: parses as unary minus
    "# --- welcome",
    "# Simulate random choices (default)",
    "# (Columns are attributes, rows are alternatives)",
    "# Example 2: Named categorical priors (more explicit)",
    "# TODO",
    "#' roxygen line"
  )
  code <- c(
    '# sd_copy_value(id = "name")',
    "# all_params <- sd_get_url_pars()",
    '# message("Age question answered!")',
    "# foo(slow = TRUE)"
  )
  expect_false(any(vapply(prose, is_commented_out_code, logical(1))))
  expect_true(all(vapply(code, is_commented_out_code, logical(1))))
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

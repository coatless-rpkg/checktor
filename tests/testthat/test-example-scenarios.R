# Test example_diagnose_scenario() ----

test_that("example_diagnose_scenario(): rejects anything but one string", {
  expect_error(example_diagnose_scenario(), "single character string")
  expect_error(example_diagnose_scenario(1), "single character string")
  expect_error(
    example_diagnose_scenario(c("a.R", "b.R")),
    "single character string"
  )
})

test_that("example_diagnose_scenario(): warns and returns NULL for an unknown file", {
  before <- list.files(tempdir())
  expect_warning(
    res <- example_diagnose_scenario("code_examples/nope.R", show_content = FALSE),
    "Example file not found: code_examples/nope.R",
    fixed = TRUE
  )
  expect_null(res)
  # It gives up before building anything, so there is nothing left to clean up.
  expect_identical(list.files(tempdir()), before)
})

test_that("example_diagnose_scenario(): puts each kind of file where a package keeps it", {
  code <- example_diagnose_scenario(
    "code_examples/tf_usage_bad.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  expect_identical(list.files(file.path(code, "R")), "tf_usage_bad.R")
  expect_true(all(dir.exists(file.path(code, c("R", "man", "tests")))))
  # A scenario that brings no DESCRIPTION gets the template, and the NEWS.md and
  # cran-comments.md that keep the general checks quiet.
  expect_identical(
    read.dcf(file.path(code, "DESCRIPTION"), fields = "Package")[[1]],
    "examplepackage"
  )
  expect_true(all(file.exists(file.path(code, c("NEWS.md", "cran-comments.md")))))

  # A .txt scenario becomes the DESCRIPTION itself (the content is checked for
  # every scenario in "every shipped scenario lands where its kind belongs"), and
  # brings no R code.
  desc <- example_diagnose_scenario(
    "description_examples/bad_description.txt",
    show_content = FALSE,
    cleanup = TRUE
  )
  expect_identical(list.files(file.path(desc, "R")), character(0))

  doc <- example_diagnose_scenario(
    "documentation_examples/missing_value_tag.Rd",
    show_content = FALSE,
    cleanup = TRUE
  )
  expect_identical(list.files(file.path(doc, "man")), "missing_value_tag.Rd")
  expect_identical(list.files(file.path(doc, "R")), character(0))
})

test_that("example_diagnose_scenario(): places a file by its extension, not its folder", {
  # network_examples/ holds an .Rd. Routed by folder name it went to R/, where no
  # Rd check reads, so the example of lab_network_operations() showed nothing.
  net <- example_diagnose_scenario(
    "network_examples/bad_network_example.Rd",
    show_content = FALSE,
    cleanup = TRUE
  )
  expect_identical(list.files(file.path(net, "man")), "bad_network_example.Rd")
  expect_identical(list.files(file.path(net, "R")), character(0))

  tmp <- example_diagnose_scenario(
    "temp_examples/bad_temp_usage.R",
    show_content = FALSE,
    cleanup = TRUE
  )
  expect_identical(list.files(file.path(tmp, "R")), "bad_temp_usage.R")
})

test_that("example_diagnose_scenario(): puts a vignette scenario in vignettes/, where vignette checks read it", {
  vig <- example_diagnose_scenario(
    "documentation_examples/example_state_bad.Rmd",
    show_content = FALSE,
    cleanup = TRUE
  )
  expect_identical(list.files(file.path(vig, "vignettes")), "example_state_bad.Rmd")
  expect_identical(list.files(file.path(vig, "R")), character(0))
  expect_identical(list.files(file.path(vig, "man")), character(0))
  expect_identical(
    lab_example_state(vig, verbose = FALSE)$issues,
    "vignette example_state_bad.Rmd:9 (never restored)"
  )
})

test_that("example_diagnose_scenario(): an extension no package keeps is an error", {
  # It is the caller's mistake whether or not such a file ships, so it is caught
  # before the lookup and before anything is built.
  before <- list.files(tempdir())
  expect_error(
    example_diagnose_scenario("code_examples/notes.md", show_content = FALSE),
    "notes.md",
    class = "rlang_error"
  )
  expect_identical(list.files(tempdir()), before)
})

test_that("example_diagnose_scenario(): every shipped scenario lands where its kind belongs", {
  # Each scenario arrives exactly as shipped. That includes a .txt scenario,
  # whose target is DESCRIPTION: it IS the DESCRIPTION, so the template must
  # not replace it.
  for (example in show_example_files()) {
    pkg <- example_diagnose_scenario(example, show_content = FALSE, cleanup = TRUE)
    target <- file.path(pkg, scenario_target(example))
    expect_identical(
      readLines(target),
      readLines(system.file("diagnose", example, package = "checktor")),
      info = example
    )
  }
})

test_that("scenario_target(): maps each extension to its place in a package", {
  expect_identical(scenario_target("code_examples/a.R"), file.path("R", "a.R"))
  expect_identical(scenario_target("network_examples/b.Rd"), file.path("man", "b.Rd"))
  expect_identical(scenario_target("description_examples/c.txt"), "DESCRIPTION")
  for (vignette in c("v.Rmd", "v.qmd", "v.Rnw")) {
    expect_identical(
      scenario_target(file.path("vignette_examples", vignette)),
      file.path("vignettes", vignette)
    )
  }
  expect_identical(
    scenario_target("general_examples/citation_file_bad.CITATION"),
    file.path("inst", "CITATION")
  )
  expect_identical(
    scenario_target("description_examples/license_year_bad.LICENSE"),
    "LICENSE"
  )
  expect_identical(scenario_target("misc/notes.md"), NA_character_)
})

test_that("example_diagnose_scenario(): description_type picks the template", {
  expected <- c(minimal = "examplepackage", bad = "badexample", good = "goodexample")
  for (type in names(expected)) {
    pkg <- example_diagnose_scenario(
      "code_examples/tf_usage_bad.R",
      show_content = FALSE,
      description_type = type,
      cleanup = TRUE
    )
    expect_identical(
      read.dcf(file.path(pkg, "DESCRIPTION"), fields = "Package")[[1]],
      expected[[type]],
      info = type
    )
  }
})

test_that("example_diagnose_scenario(): two scenarios never share a directory", {
  # The name was a timestamp plus sample(1000:9999, 1), so two calls in one second
  # from the same RNG state drew the same suffix and built into one tree, the
  # second scenario's file landing beside the first's.
  a <- withr::with_seed(
    1,
    example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  )
  withr::defer(unlink(a, recursive = TRUE))
  b <- withr::with_seed(
    1,
    example_diagnose_scenario("code_examples/seed_setting_bad.R", show_content = FALSE)
  )
  withr::defer(unlink(b, recursive = TRUE))
  expect_false(identical(a, b))
  expect_identical(list.files(file.path(b, "R")), "seed_setting_bad.R")
  expect_identical(normalizePath(dirname(a)), normalizePath(tempdir()))
  expect_match(basename(a), "^checktor_example_")
})

test_that("example_diagnose_scenario(): does not advance the caller's random seed", {
  # The directory name was drawn with sample(), which moved the caller's RNG
  # stream: an example that set a seed and then built a scenario got different
  # numbers from one that did not. lab_seed_setting() reports the same side effect
  # in package code.
  withr::local_seed(42)
  before <- get(".Random.seed", envir = globalenv())
  example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE, cleanup = TRUE)
  expect_identical(get(".Random.seed", envir = globalenv()), before)
})

test_that("example_diagnose_scenario(): does not create a random seed", {
  # In a session that has drawn no random number yet there is no .Random.seed,
  # and sample() created one. local_preserve_seed() puts back whatever was there.
  withr::local_preserve_seed()
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }
  example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE, cleanup = TRUE)
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})

test_that("example_diagnose_scenario(): cleanup = TRUE removes the scenario when the caller returns", {
  build <- function() {
    pkg <- example_diagnose_scenario(
      "code_examples/tf_usage_bad.R",
      show_content = FALSE,
      cleanup = TRUE
    )
    # Still there for the caller to use...
    expect_true(dir.exists(pkg))
    pkg
  }
  # ...and gone once it has returned.
  expect_false(dir.exists(build()))

  kept <- example_diagnose_scenario("code_examples/tf_usage_bad.R", show_content = FALSE)
  withr::defer(unlink(kept, recursive = TRUE))
  expect_true(dir.exists(kept))
})

test_that("example_diagnose_scenario(): show_content frames the file with its name, and FALSE prints nothing", {
  out <- cli::cli_fmt(
    pkg <- example_diagnose_scenario("code_examples/seed_setting_bad.R")
  )
  withr::defer(unlink(pkg, recursive = TRUE))
  expect_match(out[1], "Example file: seed_setting_bad.R", fixed = TRUE)
  expect_match(out, "End of example", all = FALSE, fixed = TRUE)

  expect_silent(
    pkg3 <- example_diagnose_scenario("code_examples/seed_setting_bad.R", show_content = FALSE)
  )
  withr::defer(unlink(pkg3, recursive = TRUE))
})

test_that("example_diagnose_scenario(): show_content prints every scenario as written", {
  # The scenarios are full of braces (function bodies, Rd macros), which cli
  # would read as code to run if the file reached it as a template.
  for (example in show_example_files()) {
    out <- NULL
    expect_no_error(
      out <- cli::cli_fmt(
        pkg <- example_diagnose_scenario(example, cleanup = TRUE)
      )
    )
    shipped <- readLines(system.file("diagnose", example, package = "checktor"))
    expect_true(all(shipped[nzchar(shipped)] %in% out), info = example)
  }
})

# Test show_example_files() ----

test_that("show_example_files(): lists every shipped scenario, sorted", {
  all <- show_example_files()
  expect_true("code_examples/tf_usage_bad.R" %in% all)
  expect_true("documentation_examples/missing_value_tag.Rd" %in% all)
  expect_false(is.unsorted(all))
  # Each one is a path example_diagnose_scenario() accepts. system.file() drops
  # the paths that do not exist, so the lengths agree only if every one does.
  expect_length(system.file("diagnose", all, package = "checktor"), length(all))
})

test_that("show_example_files(): filters by category and by pattern", {
  code <- show_example_files("code")
  expect_gt(length(code), 0L)
  expect_true(all(startsWith(code, "code_examples/")))
  # Membership rather than the whole list, so a scenario added for a new check
  # does not break the filter test.
  desc <- show_example_files("description")
  expect_true(all(startsWith(desc, "description_examples/")))
  expect_true(all(
    c(
      "description_examples/bad_description.txt",
      "description_examples/good_description.txt"
    ) %in% desc
  ))
  expect_true(all(startsWith(show_example_files("documentation"), "documentation_examples/")))
  general <- show_example_files("general")
  expect_true("general_examples/code_exercised_bad.R" %in% general)
  expect_true(all(startsWith(general, "general_examples/")))

  bad <- show_example_files(pattern = "_bad\\.R$")
  expect_gt(length(bad), 0L)
  expect_true(all(grepl("_bad\\.R$", bad)))
  # Both filters apply together.
  expect_identical(
    show_example_files("code", pattern = "seed"),
    "code_examples/seed_setting_bad.R"
  )
  expect_identical(show_example_files(pattern = "no-such-file-xyz"), character(0))
})

# Test the scenarios the help pages use ----

test_that("example_diagnose_scenario(): every lab_*() example shows its check finding something", {
  # An example that runs its check on a package where the check passes shows the
  # reader nothing, which is what 46 of them did. Each one builds a scenario
  # that trips its own check, and this holds every exported check to that.
  #
  # The exceptions, and why:
  # - lab_url_liveness() needs a network, so its example is in \dontrun{} and
  #   never runs here.
  # - lab_spelling() needs aspell or hunspell. Without one it is skipped, and
  #   which words a dictionary flags differs by machine, so a finding is
  #   required only off CRAN on a machine with a backend.
  # - lab_rd_bibliography() looks keys up in R's own bibliography, which R 4.6.0
  #   added. On an older R it is skipped, so its example finds nothing there.
  not_run <- "lab_url_liveness"
  backend <- "lab_spelling"
  needs_r_bibliography <- if (is.null(r_bibliography_keys())) "lab_rd_bibliography"
  withr::local_options(checktor.spelling = TRUE)
  has_backend <- nzchar(Sys.which("aspell")) || nzchar(Sys.which("hunspell"))

  rd_db <- package_rd_db()
  labs <- sort(grep("^lab_", getNamespaceExports("checktor"), value = TRUE))
  scenario_dirs <- function() {
    list.files(tempdir(), pattern = "^checktor_example_")
  }
  before <- scenario_dirs()
  for (fn in labs) {
    rd <- rd_db[[paste0(fn, ".Rd")]]
    expect_false(is.null(rd), label = paste(fn, "has a help page"))
    seen <- run_rd_example(rd, fn)
    if (fn %in% not_run) {
      expect_length(seen, 0L)
      next
    }
    expect_gt(length(seen), 0L, label = paste(fn, "calls in its example"))
    res <- seen[[length(seen)]]
    if (fn %in% backend && (!has_backend || !identical(Sys.getenv("NOT_CRAN"), "true"))) {
      next
    }
    if (fn %in% needs_r_bibliography) {
      expect_true(isTRUE(res$skipped), label = paste(fn, "skipped without R's bibliography"))
      next
    }
    expect_false(isTRUE(res$skipped), label = paste(fn, "skipped in its example"))
    expect_gt(length(res$issues), 0L, label = paste(fn, "issues in its example"))
  }
  # Every example deletes the package it built.
  expect_identical(scenario_dirs(), before)
})

test_that("show_example_files(): every shipped scenario is used by a help page", {
  # A scenario no example uses is one nobody sees; six sat unused while the
  # examples of their checks ran on tf_usage_bad.R. The good fixtures are the
  # exception: a clean package has nothing to show, so the next test uses them.
  fixtures <- c(
    "description_examples/good_description.txt",
    "documentation_examples/good_documentation.Rd"
  )
  code <- unlist(lapply(package_rd_db(), function(rd) {
    out <- withr::local_tempfile(fileext = ".R")
    tools::Rd2ex(rd, out, commentDontrun = TRUE)
    if (file.exists(out)) readLines(out) else character(0)
  }))
  code <- paste(code, collapse = "\n")
  for (example in setdiff(show_example_files(), fixtures)) {
    expect_true(
      grepl(paste0("\"", example, "\""), code, fixed = TRUE),
      label = paste(example, "is used by an example")
    )
  }
})

test_that("example_diagnose_scenario(): the good fixtures pass every check that runs", {
  for (example in c(
    "description_examples/good_description.txt",
    "documentation_examples/good_documentation.Rd"
  )) {
    pkg <- example_diagnose_scenario(example, show_content = FALSE, cleanup = TRUE)
    # At every tier, so an opinion-tier finding in a fixture meant to be clean
    # is caught too.
    res <- checktor(
      pkg,
      verbose = FALSE,
      progress = FALSE,
      severity = c("policy", "robustness", "opinion")
    )
    expect_identical(failed_checks(res), character(0), label = example)
  }
})

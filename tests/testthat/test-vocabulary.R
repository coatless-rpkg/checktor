# Every list below is the literal a check carried before the vocabularies moved
# to R/vocabulary.R. Deriving them from shared base vectors must not change what
# any check looks for, so each derived list is held to its old value.

test_that("VOCABULARY: software_names is the list lab_software_names() always used", {
  # bare_name_issues() reports in vocabulary order, so the order is held too.
  expect_identical(
    VOCABULARY$software_names,
    c(
      "ggplot2", "dplyr", "tidyr", "purrr", "tibble", "shiny", "plotly",
      "data.table", "tidyverse", "WebAssembly"
    )
  )
})

test_that("VOCABULARY: language_names is the list lab_language_names() always used", {
  expect_identical(
    VOCABULARY$language_names,
    c(
      "Python", "Java", "JavaScript", "TypeScript", "C#", "Perl", "PHP",
      "Ruby", "Rust", "Julia", "Scala", "Kotlin", "Haskell", "Lua", "MATLAB",
      "SAS", "Stata", "SPSS", "Octave", "Mathematica"
    )
  )
})

test_that("VOCABULARY: format_names is the list lab_format_names() always used", {
  expect_identical(
    VOCABULARY$format_names,
    c(
      "HTML", "CSS", "XML", "JSON", "YAML", "TOML", "Markdown", "LaTeX",
      "TeX", "SQL", "C++", "Fortran", "Tcl"
    )
  )
})

test_that("VOCABULARY: acronyms is the set lab_acronyms() always accepted", {
  # lab_acronyms() only takes a set difference, so order does not matter.
  old <- c(
    "API", "SQL", "HTML", "CSS", "PDF", "XML", "JSON", "YAML", "TOML", "URL",
    "HTTP", "HTTPS", "FTP", "GUI", "CLI", "CRAN", "ID", "OS", "TLS", "SSL",
    "UTF", "ASCII", "CMD"
  )
  expect_setequal(VOCABULARY$acronyms, old)
  expect_length(VOCABULARY$acronyms, length(old))
})

test_that("SOFTWARE_NAMES: is the set lab_description_quoted_quotes() always recognised", {
  # is_software_name() only asks for a match, so order does not matter.
  old <- c(
    "R", "Python", "Java", "C", "JavaScript", "TypeScript", "C#", "Perl",
    "PHP", "Ruby", "Rust", "Scala", "Kotlin", "Haskell", "Lua", "Octave",
    "Mathematica", "Excel", "Stata", "SAS", "SPSS", "MATLAB", "Julia",
    "Docker", "Git", "GitHub", "Quarto", "Pandoc", "shiny", "ggplot2", "dplyr",
    "tidyr", "purrr", "tibble", "plotly", "tidyverse", "knitr", "rmarkdown",
    "Rcpp", "data.table", "Stan", "JAGS", "BUGS", "TensorFlow", "PyTorch",
    "Keras", "WebAssembly", "WASM", "webR", "Shinylive"
  )
  expect_setequal(SOFTWARE_NAMES, old)
  expect_length(SOFTWARE_NAMES, length(old))
})

test_that("SOFTWARE_NAMES: holds every name the two policy quoting checks demand", {
  # A name alone in double quotes is reported by quoted_quotes or nowhere.
  expect_true(all(VOCABULARY$software_names %in% SOFTWARE_NAMES))
  expect_true(all(VOCABULARY$language_names %in% SOFTWARE_NAMES))
})

test_that("VOCABULARY_FIELDS: checktor_config() reads one field per vocabulary", {
  pkg <- make_temp_dir()
  expect_named(
    checktor_config(pkg),
    c("disable", "allow", "software_names", "language_names", "format_names", "acronyms")
  )
})

# Test lab_software_names() ----

test_that("lab_software_names(): inspects continuation lines of Description", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Provides utilities.",
    "    Builds on ggplot2 (without quotes) and dplyr too.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  expect_identical(
    lab_software_names(pkg, verbose = FALSE)$issues,
    c(
      "Description: ggplot2 should be in single quotes",
      "Description: dplyr should be in single quotes"
    )
  )
})

test_that("lab_software_names(): reads a desc from read.dcf(), a one-row matrix", {
  # The form `desc` is documented to take. Its fields are column names, so
  # looking them up with names() found none and a bare ggplot2 passed.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    title = "Draws Python Figures with JSON Themes",
    description = "Builds on ggplot2 layers for the users of the package here."
  )
  desc <- read.dcf(file.path(pkg, "DESCRIPTION"))
  expect_identical(
    lab_software_names(pkg, verbose = FALSE, desc = desc)$issues,
    "Description: ggplot2 should be in single quotes"
  )
  expect_identical(
    lab_language_names(pkg, verbose = FALSE, desc = desc)$issues,
    "Title: Python should be in single quotes"
  )
  expect_identical(
    lab_format_names(pkg, verbose = FALSE, desc = desc)$issues,
    "Title: JSON is not in single quotes"
  )
})

test_that("lab_software_names(): accepts properly quoted names", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Wraps 'ggplot2' and 'dplyr' for convenience.")
  res <- lab_software_names(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_identical(res$issues, character(0))
})

test_that("lab_software_names(): does NOT flag the bare letter R", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = "A package for R users that integrates with 'ggplot2'."
  )
  expect_identical(lab_software_names(pkg, verbose = FALSE)$issues, character(0))
})

test_that("lab_software_names(): flags an unquoted WebAssembly", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Runs R code in a WebAssembly runtime.")
  res <- lab_software_names(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(res$issues, "Description: WebAssembly should be in single quotes")

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, description = "Runs R code in a 'WebAssembly' runtime.")
  expect_true(
    lab_software_names(pkg_ok, verbose = FALSE)$passed
  )
})

test_that("lab_software_names(): a configured name is flagged when unquoted", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = "Wraps brms models for the user. It does several helpful things here.",
    extra = "Config/checktor/software_names: brms"
  )
  res <- lab_software_names(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(res$issues, "Description: brms should be in single quotes")
})

test_that("lab_software_names(): without config, the name is NOT flagged", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = "Wraps brms models for the user. It does several helpful things here."
  )
  expect_true(lab_software_names(pkg, verbose = FALSE)$passed)
})

test_that("lab_software_names(): a dotted name does not match plain English", {
  # data.table is a regular expression unless escaped, where the dot would match
  # the space in "data table".
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Stores rows in a data table for later use here.")
  expect_true(lab_software_names(pkg, verbose = FALSE)$passed)

  named <- make_temp_dir()
  write_pkg(named, description = "Builds on data.table for fast grouped joins.")
  expect_identical(
    lab_software_names(named, verbose = FALSE)$issues,
    "Description: data.table should be in single quotes"
  )
})

test_that("lab_software_names(): flags a package name but not a programming language", {
  # Empirically split: ggplot2 is quoted in 96% of CRAN Descriptions that mention
  # it (a convention); JavaScript in 46%, HTML in 20% (a coin flip, not a rule).
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      "Bindings for JavaScript and HTML that build on ggplot2 graphics.",
      "It does a number of useful things for the user here."
    )
  )
  expect_identical(
    lab_software_names(pkg, verbose = FALSE)$issues,
    "Description: ggplot2 should be in single quotes"
  )
})

test_that("lab_software_names(): accepts a properly quoted package name", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      "Extends 'ggplot2' and 'shiny' with new layers.",
      "It does a number of useful things for the user here."
    )
  )
  expect_true(lab_software_names(pkg, verbose = FALSE)$passed)
})

test_that("lab_software_names(): a name inside a quoted longer name is quoted", {
  # semantic.assets and fomantic.plus quote 'shiny.semantic' exactly as asked. The
  # shiny inside it matched a plain word boundary, and only a literal 'shiny'
  # counted as quoted, so correct text failed a policy check.
  for (title in c(
    "Assets for 'shiny.semantic'",
    "Add Extra 'Fomantic UI' Components to 'shiny.semantic'"
  )) {
    res <- lab_software_names(make_temp_dir(), verbose = FALSE, desc = c(Title = title))
    expect_identical(res$issues, character(0), info = title)
  }
})

test_that("lab_software_names(): a quoted name may take a plural or possessive s", {
  # gdxdt reads GAMS files "with 'data.table's", pixiedust is "similar to
  # 'ggplot2's system of layers". CRAN's pattern wants a blank or punctuation after
  # the closing quote, but the name itself is quoted.
  for (d in c(
    "Interfaces GAMS data files with 'data.table's for fast joins.",
    "An interface similar to 'ggplot2's system of layers for tables."
  )) {
    res <- lab_software_names(make_temp_dir(), verbose = FALSE, desc = c(Description = d))
    expect_identical(res$issues, character(0), info = d)
  }
})

test_that("lab_software_names(): a dotted package is not the name it starts or ends with", {
  # shiny.semantic is its own package, so it is not a bare mention of shiny.
  res <- lab_software_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Themes for shiny.semantic apps, served as static assets.")
  )
  expect_identical(res$issues, character(0))

  # Nor are refund.shiny and semantic.shiny, where the name comes last.
  res <- lab_software_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Builds on refund.shiny and semantic.shiny for apps.")
  )
  expect_identical(res$issues, character(0))

  # A full stop that ends the sentence is still a boundary.
  res <- lab_software_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Adds new layers that extend ggplot2.")
  )
  expect_identical(res$issues, "Description: ggplot2 should be in single quotes")
})

test_that("lab_software_names(): a name in a web address is part of the address", {
  # adea: "an on-line and interactive version is available at
  # <https://knuth.uca.es/shiny/DEA/>". A bare URL is no different.
  for (d in c(
    "An interactive version is available at <https://knuth.uca.es/shiny/DEA/>.",
    "An interactive version is available at https://knuth.uca.es/shiny/DEA/ today."
  )) {
    res <- lab_software_names(make_temp_dir(), verbose = FALSE, desc = c(Description = d))
    expect_identical(res$issues, character(0), info = d)
  }
})

test_that("lab_software_names(): a function call is code, not a mention", {
  # bread, fauxnaif and mappp describe themselves through data.table::fread(),
  # dplyr::na_if() and purrr::map(). CRAN asks for a function written as foo()
  # without quotes, and its own speller skips pkg::foo(), so quoting the package
  # inside a call is not the fix. A package name in a call may have a dot in it.
  for (d in c(
    "Wraps data.table::fread() and purrr::map() for big files.",
    "Uses shiny.semantic::semanticPage() for layout."
  )) {
    res <- lab_software_names(make_temp_dir(), verbose = FALSE, desc = c(Description = d))
    expect_identical(res$issues, character(0), info = d)
  }
})

test_that("lab_software_names(): a name in a double-quoted title is part of the title", {
  # AutoAds, tidyspec and yum cite a book or article by its title, which Writing R
  # Extensions puts in double quotes. A name inside the title is not a mention.
  res <- lab_software_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = paste(
      "Plots with 'ggplot2'. See \"ggplot2: Elegant Graphics for Data Analysis\"",
      "(Wickham 2016) and \"Welcome to the tidyverse\" (Wickham et al. 2019)."
    ))
  )
  expect_identical(res$issues, character(0))

  # A bare name outside the title is still bare.
  res <- lab_software_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Follows \"R for Data Science\" with tidyverse code.")
  )
  expect_identical(res$issues, "Description: tidyverse should be in single quotes")
})

test_that("lab_software_names(): leaves a double-quoted name to lab_description_quoted_quotes()", {
  # A name alone in double quotes is the wrong kind of quote, not a bare name,
  # and lab_description_quoted_quotes() is the check that says so.
  d <- c(Description = "Builds dashboards with \"shiny\" for the user here.")
  expect_identical(
    lab_software_names(make_temp_dir(), verbose = FALSE, desc = d)$issues,
    character(0)
  )
  res <- lab_description_quoted_quotes(make_temp_dir(), verbose = FALSE, desc = d)
  expect_length(res$issues, 1L)
  expect_match(res$issues, "Description: \"shiny\" is a software name in double quotes", fixed = TRUE)
})

test_that("lab_software_names(): an elided year opens no quotation", {
  # The apostrophe in '90s is not a quote, so the text up to the next apostrophe
  # is not quoted either.
  for (d in c(
    "Data from the '90s plotted with ggplot2 and the package's own theme.",
    "Covers the '90s ggplot2 users' plots and more."
  )) {
    res <- lab_software_names(make_temp_dir(), verbose = FALSE, desc = c(Description = d))
    expect_identical(res$issues, "Description: ggplot2 should be in single quotes", info = d)
  }
})

test_that("lab_software_names(): one quoted mention does not excuse a bare one", {
  # Each occurrence is judged on its own. A single 'shiny' used to clear every
  # bare shiny in the same field.
  res <- lab_software_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Builds 'shiny' modules that drop into any shiny app.")
  )
  expect_identical(res$issues, "Description: shiny should be in single quotes")
})

# Test lab_language_names() ----

test_that("lab_language_names(): flags bare programming-language names", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Bridges R with Python and a Julia backend.")
  res <- lab_language_names(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(
    res$issues,
    c(
      "Description: Python should be in single quotes",
      "Description: Julia should be in single quotes"
    )
  )
})

test_that("lab_language_names(): accepts quoted names, does not flag bare R", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Bridges R with 'Python' and a 'Julia' backend.")
  res <- lab_language_names(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_identical(res$issues, character(0))
})

test_that("lab_language_names(): flags a bare Python that lab_software_names() leaves alone", {
  # A language name and a package name are different kinds of thing, so each is
  # the job of its own check. The tier is pinned in test-severity.R.
  d <- c(Description = "Bridges R with Python and 'ggplot2'.")
  expect_identical(
    lab_language_names(make_temp_dir(), verbose = FALSE, desc = d)$issues,
    "Description: Python should be in single quotes"
  )
  expect_identical(
    lab_software_names(make_temp_dir(), verbose = FALSE, desc = d)$issues,
    character(0)
  )
})

test_that("lab_language_names(): flags C# but not inside a larger token", {
  # "C#" is not a word to a plain word boundary; quoting it clears the flag.
  bad <- make_temp_dir()
  write_pkg(bad, description = "Exposes a C# engine to R.")
  res <- lab_language_names(bad, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(res$issues, "Description: C# should be in single quotes")

  ok <- make_temp_dir()
  write_pkg(ok, description = "Exposes a 'C#' engine to R.")
  expect_true(lab_language_names(ok, verbose = FALSE)$passed)

  # Java inside JavaScript, and Rust inside Rustaceans, is not a bare Java or
  # Rust. Written bare, so the guard is what decides.
  edge <- make_temp_dir()
  write_pkg(edge, description = "Serves Rustaceans a JavaScript viewer.")
  expect_identical(
    lab_language_names(edge, verbose = FALSE)$issues,
    "Description: JavaScript should be in single quotes"
  )
})

test_that("lab_language_names(): covers statistical-computing environments", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Imports data from MATLAB and SAS into R.")
  res <- lab_language_names(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(
    res$issues,
    c(
      "Description: MATLAB should be in single quotes",
      "Description: SAS should be in single quotes"
    )
  )
})

test_that("lab_language_names(): leaves format and markup names to lab_format_names()", {
  # A census of CRAN in September 2026 found these written bare in most packages
  # accepted at review, so a bare one is not a policy finding (#16).
  d <- c(
    Title = "Repair Malformed JSON Strings", # llmjson, accepted 2026-03-11
    Description = paste(
      "Renders Markdown and LaTeX, reads YAML, TOML and XML, writes HTML, CSS",
      "and SQL, and drives Tcl widgets from C++ and Fortran code."
    )
  )
  expect_identical(
    lab_language_names(make_temp_dir(), verbose = FALSE, desc = d)$issues,
    character(0)
  )
})

test_that("lab_language_names(): a name inside a quoted longer name is quoted", {
  # Real CRAN Titles, each quoting the whole name as Writing R Extensions asks.
  # The term inside the quotes matched as bare, and only a literal 'SAS' or
  # 'Python' counted as quoted, so every one of these failed a policy check.
  for (title in c(
    "Recreates Some 'SAS\u00ae' Procedures in 'R'", # procs
    "'AWS Python SDK' ('boto3') for R", # botor
    "Create Interactive Graphs with 'Echarts JavaScript' Version 6", # echarts4r
    "Deploys Models to the 'MATLAB Runtime'"
  )) {
    res <- lab_language_names(make_temp_dir(), verbose = FALSE, desc = c(Title = title))
    expect_identical(res$issues, character(0), info = title)
  }
})

test_that("lab_language_names(): a quoted name opening a continuation line is quoted", {
  # read.dcf() joins a continuation line with a newline, which CRAN's pattern does
  # not count as a boundary. CRAN's speller never meets one because it reads the
  # file line by line, and a quote that opens a line is still a quote.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      "Deploys models that were compiled for the",
      "    'MATLAB Runtime' to R users on any platform.",
      sep = "\n"
    )
  )
  expect_identical(lab_language_names(pkg, verbose = FALSE)$issues, character(0))
})

test_that("lab_language_names(): one quoted mention does not excuse a bare one", {
  # Each occurrence is judged on its own. A single 'Python' used to clear every
  # bare Python in the same field.
  res <- lab_language_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Runs 'Python' scripts, so Python must be installed.")
  )
  expect_identical(res$issues, "Description: Python should be in single quotes")

  # AWR's Title quotes the words either side of a bare Java.
  res <- lab_language_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Title = "'AWS' Java 'SDK' for R")
  )
  expect_identical(res$issues, "Title: Java should be in single quotes")
})

test_that("lab_language_names(): a name in a double-quoted title is part of the title", {
  res <- lab_language_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = paste(
      "Wraps the 'Python' API; see \"Python for Data Analysis\"",
      "(McKinney 2017) for the background."
    ))
  )
  expect_identical(res$issues, character(0))
})

test_that("lab_language_names(): a name in a web address or DOI is part of it", {
  res <- lab_language_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = paste(
      "Mirrors <https://github.com/JuliaLang/Julia/> and the method of",
      "<doi:10.1000/Python-2020>, with notes at https://example.org/SAS/ too."
    ))
  )
  expect_identical(res$issues, character(0))
})

# Test lab_format_names() ----

test_that("lab_format_names(): flags bare format, markup and query names", {
  res <- lab_format_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(
      Title = "Repair Malformed JSON Strings", # llmjson
      Description = "Reads YAML, TOML and XML, and writes HTML, CSS and SQL."
    )
  )
  expect_false(res$passed)
  expect_identical(
    res$issues,
    c(
      "Title: JSON is not in single quotes",
      paste("Description:", c("HTML", "CSS", "XML", "YAML", "TOML", "SQL"), "is not in single quotes")
    )
  )
})

test_that("lab_format_names(): covers typesetting and the languages CRAN writes both ways", {
  res <- lab_format_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Renders Markdown and LaTeX, and drives Tcl from C++ and Fortran.")
  )
  expect_setequal(
    res$issues,
    paste("Description:", c("Markdown", "LaTeX", "C++", "Fortran", "Tcl"), "is not in single quotes")
  )
})

test_that("lab_format_names(): accepts quoted names and quoted longer names", {
  ok <- lab_format_names(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Reads 'YAML' and 'JSON', and renders 'Markdown' with 'LaTeX'.")
  )
  expect_true(ok$passed)
  expect_identical(ok$issues, character(0))

  # Real CRAN Titles, each quoting the whole name.
  for (title in c(
    "'R Markdown' Format for Scientific and Technical Writing", # distill
    "Interface to 'JSON-stat'", # jsonstat
    "Implementation of the Remote Procedure Call Protocol ('XML-RPC')", # xmlrpc2
    "Bindings to the 'Tcl/Tk' Toolkit",
    "Readers for 'Arrow C++' Files"
  )) {
    res <- lab_format_names(make_temp_dir(), verbose = FALSE, desc = c(Title = title))
    expect_identical(res$issues, character(0), info = title)
  }
})

test_that("lab_format_names(): matches whole names only", {
  # TeX sits inside LaTeX, SQL inside PostgreSQL and JSON inside GeoJSON, and none
  # of those is a bare TeX, SQL or JSON. Written bare, so the guard is what
  # decides. C++ carries regex metacharacters.
  cases <- list(
    "Builds a LaTeX manual." = "Description: LaTeX is not in single quotes",
    "Reads a PostgreSQL dump." = character(0),
    "Reads GeoJSON files." = character(0),
    "Exposes a C++ engine to R." = "Description: C++ is not in single quotes"
  )
  for (d in names(cases)) {
    res <- lab_format_names(make_temp_dir(), verbose = FALSE, desc = c(Description = d))
    expect_identical(res$issues, cases[[d]], info = d)
  }
})

test_that("lab_format_names(): a format name in double quotes is reported by no check", {
  # Double quotes are the wrong kind for a name, but CRAN accepts a format name
  # with no quotes at all, so neither this check nor the policy-tier
  # lab_description_quoted_quotes() reports one alone in double quotes (#16).
  d <- c(
    Title = "Writes \"JSON\" Files",
    Description = "Renders \"HTML\" and \"C++\" snippets for the user."
  )
  expect_identical(
    lab_format_names(make_temp_dir(), verbose = FALSE, desc = d)$issues,
    character(0)
  )
  expect_identical(
    lab_description_quoted_quotes(make_temp_dir(), verbose = FALSE, desc = d)$issues,
    character(0)
  )
})

test_that("lab_format_names(): Config/checktor/format_names adds a name", {
  d <- "Reads GeoJSON files for the analysis of spatial data here."
  plain <- make_temp_dir()
  write_pkg(plain, description = d)
  expect_identical(lab_format_names(plain, verbose = FALSE)$issues, character(0))

  configured <- make_temp_dir()
  write_pkg(configured, description = d, extra = "Config/checktor/format_names: GeoJSON")
  expect_identical(
    lab_format_names(configured, verbose = FALSE)$issues,
    "Description: GeoJSON is not in single quotes"
  )
})

test_that("lab_format_names(): runs only on request (#16)", {
  # A bare format name is how most accepted packages write it, so it cannot count
  # against a clean result; it is there for a maintainer who wants consistency.
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "Repair Malformed JSON Strings")
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false("format_names" %in% tidy(r)$check)
  expect_true("format_names" %in% r$metadata$on_request_checks)
  expect_true(checkup(pkg))
  expect_false(lab_format_names(pkg, verbose = FALSE)$passed)
})

test_that("lab_format_names(): says a bare name is a choice, not a violation", {
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "Repair Malformed JSON Strings")
  out <- paste(cli::cli_fmt(lab_format_names(pkg)), collapse = " ")
  expect_match(out, "Title: JSON is not in single quotes", fixed = TRUE)
  expect_match(out, "CRAN accepts", fixed = TRUE)
  # The finding is in the Title, so the advice cannot be about the Description only.
  expect_match(out, "consistent throughout the Title and Description", fixed = TRUE)
})

# Test blank_ignored_spans() ----

test_that("blank_ignored_spans(): blanks quotes, calls, links and DOIs, and keeps the rest", {
  x <- blank_ignored_spans(paste(
    "Uses 'R Markdown' with purrr::map() and <doi:10.1000/xyz>",
    "at https://example.org/a/ for Python users."
  ))
  # Blanked, not deleted: the words either side stay apart.
  expect_identical(gsub(" +", " ", x), " Uses with and < > at for Python users. ")
  # An apostrophe inside a word opens no span, so nothing after it is lost, and
  # nor does the one that elides a year.
  expect_identical(
    gsub(" +", " ", blank_ignored_spans("R's Python and the users' Julia")),
    " R's Python and the users' Julia "
  )
  expect_identical(
    gsub(" +", " ", blank_ignored_spans("the '90s Python users' Julia")),
    " the '90s Python users' Julia "
  )
  # A quoted name may still start with a digit (DTAT, latte).
  expect_identical(
    gsub(" +", " ", blank_ignored_spans("a '3+3/PC' design with '4ti2' for Julia")),
    " a design with for Julia "
  )
})

test_that("blank_ignored_spans(): blanks a double-quoted title", {
  expect_identical(
    gsub(" +", " ", blank_ignored_spans("See \"Python for Data Analysis\" (2017) for Julia.")),
    " See (2017) for Julia. "
  )
})

test_that("blank_ignored_spans(): NA or empty in, empty out", {
  expect_identical(blank_ignored_spans(NA_character_), "")
  expect_identical(blank_ignored_spans(""), "")
  expect_identical(blank_ignored_spans(c("Julia", NA)), c(" Julia ", ""))
  expect_identical(blank_ignored_spans(character(0)), character(0))
})

test_that("blank_ignored_spans(): a quote opening a continuation line counts", {
  # read.dcf() joins continuation lines with a newline, which CRAN's pattern does
  # not accept as the blank before a quote.
  expect_identical(
    gsub(" +", " ", blank_ignored_spans("Deploys to the\n'MATLAB Runtime' today.")),
    " Deploys to the today. "
  )
})

# Test lab_description_quoted_quotes() ----

test_that("lab_description_quoted_quotes(): flags double-quoted names", {
  # The check only inspects DOUBLE-quoted spans, so a single-quoted fixture
  # exits before is_software_name() is ever consulted and proves nothing about
  # the vocabulary. Double quotes are what put SOFTWARE_NAMES under test.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste0(
      "Builds links for \"WebAssembly\" (\"WASM\") and \"webR\" apps, ",
      "including \"Shinylive\" bundles."
    )
  )
  res <- lab_description_quoted_quotes(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 4L)
  expect_match(res$issues, "WebAssembly", all = FALSE)
  expect_match(res$issues, "WASM", all = FALSE)
  expect_match(res$issues, "webR", all = FALSE)
  expect_match(res$issues, "Shinylive", all = FALSE)
})

test_that("lab_description_quoted_quotes(): knows every name the quoting checks ask to quote", {
  # lab_software_names() and lab_language_names() read a double-quoted span as a
  # quotation, so a name alone in double quotes is this check's to report, or no
  # check reports it. janitor "follows the principles of the \"tidyverse\"".
  software <- c(
    "ggplot2", "dplyr", "tidyr", "purrr", "tibble", "shiny", "plotly",
    "data.table", "tidyverse", "WebAssembly"
  )
  languages <- c(
    "Python", "Java", "JavaScript", "TypeScript", "C#", "Perl", "PHP", "Ruby",
    "Rust", "Julia", "Scala", "Kotlin", "Haskell", "Lua", "MATLAB", "SAS",
    "Stata", "SPSS", "Octave", "Mathematica"
  )
  for (n in c(software, languages)) {
    bare <- c(Description = paste("Works with", n, "for the user."))
    quoted <- c(Description = paste0("Works with \"", n, "\" for the user."))
    check <- if (n %in% software) lab_software_names else lab_language_names
    # The name is one the quoting check asks to see quoted ...
    expect_false(check(make_temp_dir(), verbose = FALSE, desc = bare)$passed, info = n)
    # ... and in double quotes it is reported here instead.
    expect_identical(
      check(make_temp_dir(), verbose = FALSE, desc = quoted)$issues,
      character(0),
      info = n
    )
    expect_false(
      lab_description_quoted_quotes(make_temp_dir(), verbose = FALSE, desc = quoted)$passed,
      info = n
    )
  }
})

test_that("lab_description_quoted_quotes(): leaves format names to lab_format_names() (#16)", {
  # CRAN accepts JSON and the other format names bare, so double quotes around
  # one are no more a policy finding than no quotes at all.
  formats <- c(
    "JSON", "HTML", "XML", "CSS", "SQL", "YAML", "TOML", "Markdown", "LaTeX",
    "TeX", "C++", "Fortran", "Tcl"
  )
  for (n in formats) {
    d <- c(Description = paste0("Writes \"", n, "\" files for the user."))
    res <- lab_description_quoted_quotes(make_temp_dir(), verbose = FALSE, desc = d)
    expect_identical(res$issues, character(0), info = n)
  }
})

test_that("lab_description_quoted_quotes(): ignores scare-quoted English", {
  # Double-quoted ordinary jargon IS what double quotes are reserved for; only
  # a recognised software name is a finding.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste0(
      "Fits models for so-called \"labeled\" designs and the \"no choice\" ",
      "variant used in discrete-choice work."
    )
  )
  expect_true(lab_description_quoted_quotes(pkg, verbose = FALSE)$passed)
})

test_that("lab_description_quoted_quotes(): accepts single-quoted names", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = "Builds links for 'WebAssembly' ('WASM') and 'webR' apps."
  )
  expect_true(lab_description_quoted_quotes(pkg, verbose = FALSE)$passed)
})

test_that("lab_description_quoted_quotes(): honours Config software_names", {
  # The two-list trap: the include list (software_names) and SOFTWARE_NAMES must
  # both honour the config, or one check obeys it and the other ignores it.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = 'Wraps "brms" models for the user. It does helpful things here.',
    extra = "Config/checktor/software_names: brms"
  )
  expect_false(lab_description_quoted_quotes(pkg, verbose = FALSE)$passed)

  # And a language added through Config/checktor/language_names.
  lang <- make_temp_dir()
  write_pkg(
    lang,
    description = 'Calls "Elixir" code for the user. It does helpful things here.',
    extra = "Config/checktor/language_names: Elixir"
  )
  expect_false(lab_description_quoted_quotes(lang, verbose = FALSE)$passed)
})

test_that("lab_description_quoted_quotes(): flags a double-quoted SOFTWARE name", {
  # Writing R Extensions: double quotes are for quotations, single quotes for
  # "names of other packages and external software".
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      'Builds dashboards with "shiny" and plots.',
      "It does things and more things."
    )
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$description_quoted_quotes$passed)
  expect_true(any(grepl("shiny", res$description_quoted_quotes$issues)))
})

test_that("lab_description_quoted_quotes(): does not flag scare-quoted jargon", {
  # cbcTools ships "labeled" and "no choice" on CRAN today. Those ARE the
  # quotations that double quotes are reserved for, not software names.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      'Supports "labeled" designs and a "no choice"',
      "alternative for conjoint experiments."
    )
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$description_quoted_quotes$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(
    pkg_ok,
    description = paste(
      "A package that does helpful things.",
      "No quoted phrases here at all."
    )
  )
  res2 <- diagnose_description_issues(pkg_ok, verbose = FALSE)
  expect_true(res2$description_quoted_quotes$passed)
})

test_that("lab_description_quoted_quotes(): reads the Title as well as the Description", {
  # lab_software_names() and lab_language_names() read a double-quoted span in
  # either field as a quotation, so a name alone in double quotes in the Title is
  # this check's to report, or no check reports it.
  d <- c(
    Title = "Tools for \"ggplot2\" Plots",
    Description = "Calls \"Python\" code for the user."
  )
  expect_identical(
    lab_description_quoted_quotes(make_temp_dir(), verbose = FALSE, desc = d)$issues,
    c(
      paste(
        "Title: \"ggplot2\" is a software name in double quotes (Writing R",
        "Extensions reserves double quotes for quotations; use single quotes for",
        "software and package names)"
      ),
      paste(
        "Description: \"Python\" is a software name in double quotes (Writing R",
        "Extensions reserves double quotes for quotations; use single quotes for",
        "software and package names)"
      )
    )
  )

  # A full run reports it, where the two quoting checks now pass.
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "Call \"Python\" from R")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$language_names$passed)
  expect_match(res$description_quoted_quotes$issues, "^Title: \"Python\" ")
})

test_that("lab_description_quoted_quotes(): a lower-case word is not the name it spells", {
  # A name is a proper noun, so a lower-case span is an ordinary word or a symbol:
  # the English "rust", BFF's hyperparameter "r" and R2WinBUGS's class "bugs" are
  # not Rust, R and BUGS.
  for (d in c(
    "Removes \"rust\" from images of old machines.",
    "It depends on the hyperparameters \"r\" and \"tau^2\" of the prior.",
    "Returns a class \"bugs\" for the results of a model."
  )) {
    res <- lab_description_quoted_quotes(make_temp_dir(),
      verbose = FALSE,
      desc = c(Description = d)
    )
    expect_identical(res$issues, character(0), info = d)
  }

  # A name written in lower case still counts, in any case, and so does another
  # spelling of a name that has capitals (BayesianNetwork's "Shiny").
  for (q in c("Rust", "RUST", "Matlab", "shiny", "Shiny")) {
    d <- c(Description = paste0("Builds on \"", q, "\" for the user."))
    res <- lab_description_quoted_quotes(make_temp_dir(), verbose = FALSE, desc = d)
    expect_length(res$issues, 1L)
  }
})

test_that("lab_description_quoted_quotes(): reads a desc from read.dcf(), a one-row matrix", {
  # The form `desc` is documented to take. Reading desc[["Description"]] from a
  # matrix stopped with "subscript out of bounds".
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    title = "Tools for \"ggplot2\" Plots",
    description = "Builds dashboards with \"shiny\" for the user."
  )
  desc <- read.dcf(file.path(pkg, "DESCRIPTION"))
  res <- lab_description_quoted_quotes(pkg, verbose = FALSE, desc = desc)
  expect_identical(
    res$issues,
    lab_description_quoted_quotes(pkg, verbose = FALSE)$issues
  )
  expect_identical(
    substr(res$issues, 1L, 20L),
    c("Title: \"ggplot2\" is ", "Description: \"shiny\"")
  )
})

# Test lab_acronyms() ----

test_that("lab_acronyms(): reads a desc from read.dcf(), a one-row matrix", {
  # The form `desc` is documented to take. Reading desc[["Description"]] from a
  # matrix stopped with "subscript out of bounds".
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Fits XYZ models to the data for the user here.")
  desc <- read.dcf(file.path(pkg, "DESCRIPTION"))
  expect_identical(lab_acronyms(pkg, verbose = FALSE, desc = desc)$issues, "XYZ")
})

test_that("lab_acronyms(): knows common abbreviations, reads continuations", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Provides bindings to the OS for HTTP work.", # OS in unexplained set
    "    Includes XYZ helpers for fun.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- lab_acronyms(pkg, verbose = FALSE)
  # XYZ, on the continuation line, is flagged; OS and HTTP are common abbreviations.
  expect_false(res$passed)
  expect_identical(res$issues, "XYZ")
})

test_that("lab_acronyms(): knows YAML and TOML", {
  # lab_format_names() accepts both bare, and its own example writes YAML bare.
  pkg <- example_diagnose_scenario(
    "description_examples/format_names_bad.txt",
    show_content = FALSE,
    cleanup = TRUE
  )
  expect_identical(lab_acronyms(pkg, verbose = FALSE)$issues, character(0))

  res <- lab_acronyms(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Reads TOML and YAML files for the user.")
  )
  expect_identical(res$issues, character(0))
})

test_that("lab_acronyms(): treats 'expansion (ACRONYM)' as explained (#5)", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Calculate and plot r2 coefficients between principal component",
    "    analysis (PCA) components and covariates. The idea is to search",
    "    for components which are explained by the covariates.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- lab_acronyms(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_identical(res$issues, character(0))
})

test_that("lab_acronyms(): reads a gloss whose expansion is a quoted name", {
  # software_names requires a software name to be single-quoted, so the standard
  # gloss is "'WebAssembly' (WASM)". Anchoring the gloss to a word character put
  # the closing quote in the way, and checktor reported an acronym as unexplained
  # for obeying its own policy check.
  for (q in c("'WebAssembly'", "\u2018WebAssembly\u2019", "\"WebAssembly\"")) {
    res <- lab_acronyms(make_temp_dir(),
      verbose = FALSE,
      desc = c(Description = paste0("Creates links for ", q, " (WASM) documents."))
    )
    expect_true(res$passed, info = q)
  }
  # A bare acronym with no expansion in front of it is still reported.
  bare <- lab_acronyms(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Creates links for WASM documents.")
  )
  expect_false(bare$passed)
  expect_identical(bare$issues, "WASM")
})

test_that("lab_acronyms(): treats 'ACRONYM (expansion)' as explained", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Runs PCA (principal component analysis) over supplied matrices and",
    "    returns the resulting components for downstream modelling work.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- lab_acronyms(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_identical(res$issues, character(0))
})

test_that("lab_acronyms(): still flags genuinely unexplained acronyms", {
  pkg <- make_temp_dir()
  desc <- paste(
    "Provides FOOBAR utilities for the analysis of tabular data and the",
    "    production of summaries across many datasets and output formats.",
    sep = "\n"
  )
  write_pkg(pkg, description = desc)
  res <- lab_acronyms(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(res$issues, "FOOBAR")
})

test_that("lab_acronyms(): Config/checktor/acronyms suppresses a finding", {
  desc <- "Runs MCMC over models for the analysis of tabular data here."
  plain <- make_temp_dir()
  write_pkg(plain, description = desc)
  expect_identical(lab_acronyms(plain, verbose = FALSE)$issues, "MCMC")

  configured <- make_temp_dir()
  write_pkg(configured, description = desc, extra = "Config/checktor/acronyms: MCMC")
  res <- lab_acronyms(configured, verbose = FALSE)
  expect_true(res$passed)
  expect_identical(res$issues, character(0))
})

test_that("lab_acronyms(): skips a name the user has single-quoted", {
  # language_names and format_names ask for 'MATLAB' and 'YAML' in single quotes.
  # Reporting the quoted name as an unexplained acronym had checktor contradict
  # its own quoting checks, whichever way the user wrote it.
  res <- lab_acronyms(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = paste(
      "Reads 'YAML' and 'TOML' configuration, 'MATLAB', 'SAS' and 'SPSS' data,",
      "and 'PHP' sources, and runs them in 'WASM'."
    ))
  )
  expect_true(res$passed)
  expect_identical(res$issues, character(0))

  # The same names written bare are still acronyms nobody spelled out.
  res <- lab_acronyms(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Reads MATLAB files and SPSS data for the user.")
  )
  expect_identical(res$issues, c("MATLAB", "SPSS"))
})

test_that("lab_acronyms(): skips a name in typographic single quotes", {
  # \u2018GLMM\u2019 is quoted as surely as 'GLMM', and the gloss detection already
  # reads the curly closing quote. A curly apostrophe opens nothing.
  res <- lab_acronyms(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = paste(
      "Fits \u2018GLMM\u2019 models with an \u2018MCMC\u2019 sampler, and the",
      "package\u2019s GWAS helpers."
    ))
  )
  expect_identical(res$issues, "GWAS")
})

test_that("lab_acronyms(): a typographic single quote opens and closes like a straight one", {
  # A curly quote follows the rules of a straight one: it opens after a blank or
  # punctuation but not at an elided year (\u201890s), and it closes where a
  # quote ends the word or takes a plural or possessive s. Only one side may be
  # curled (CFO, rsocialwatcher), and a curly apostrophe inside a word closes
  # nothing, so GWAS below is not swallowed.
  cases <- list(
    "The \u2018CFO' package fits GWAS data and the package\u2019s MCMC sampler." =
      c("GWAS", "MCMC"),
    "Analyses the \u201890s GWAS data with the package\u2019s MCMC sampler." =
      c("GWAS", "MCMC"),
    "Fits \u2018GLMM\u2019s with the \u2018MCMC\u2019 sampler of GWAS data." = "GWAS",
    # No blank or punctuation before it, so this one opens nothing.
    "Fits O\u2018Hagan GWAS priors with the package\u2019s MCMC sampler." =
      c("GWAS", "MCMC"),
    # Unclosed: the apostrophe inside don\u2019t is not a closing quote.
    "Reads \u2018GWAS files that don\u2019t fit in memory with an MCMC sampler." =
      c("GWAS", "MCMC")
  )
  for (d in names(cases)) {
    res <- lab_acronyms(make_temp_dir(), verbose = FALSE, desc = c(Description = d))
    expect_identical(res$issues, cases[[d]], info = d)
  }
})

test_that("lab_acronyms(): skips a name in typographic double quotes", {
  # \u201cGLMM\u201d is a quotation as surely as "GLMM" or a single-quoted name, so
  # all three are skipped, including one closed by a straight quote (INFOSET).
  res <- lab_acronyms(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = paste(
      "Fits \u201cGLMM\u201d, \"GLMM\" and \u2018GLMM\u2019 models and",
      "\u201cCPD\" steps to GWAS data."
    ))
  )
  expect_identical(res$issues, "GWAS")
})

test_that("lab_acronyms(): an elided year opens no quotation", {
  res <- lab_acronyms(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Analyses the '90s GWAS data with the package's MCMC sampler.")
  )
  expect_identical(res$issues, c("GWAS", "MCMC"))
})

test_that("lab_acronyms(): a missing Description has no acronyms", {
  res <- lab_acronyms(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = NA_character_)
  )
  expect_true(res$passed)
  expect_identical(res$issues, character(0))
})

test_that("lab_acronyms(): agrees with the quoting checks on every quoted name", {
  # Every upper-case name the quoting checks ask to see quoted, written quoted,
  # must satisfy lab_acronyms() as well.
  names <- c(
    "PHP", "MATLAB", "SAS", "SPSS", # language_names
    "HTML", "CSS", "XML", "JSON", "YAML", "TOML", "SQL" # format_names
  )
  d <- c(Description = paste0("Works with '", names, "' files.", collapse = " "))
  expect_identical(lab_language_names(make_temp_dir(), verbose = FALSE, desc = d)$issues, character(0))
  expect_identical(lab_format_names(make_temp_dir(), verbose = FALSE, desc = d)$issues, character(0))
  expect_identical(lab_acronyms(make_temp_dir(), verbose = FALSE, desc = d)$issues, character(0))
})

test_that("lab_acronyms(): an acronym in a web address or DOI is part of it", {
  res <- lab_acronyms(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = paste(
      "Implements the method of <doi:10.1000/JSSAM.2020.017> and serves",
      "results from <https://example.org/NCBI/GEO/> for the analysis."
    ))
  )
  expect_identical(res$issues, character(0))
})

# Regression tests for the DESCRIPTION-file diagnostics, especially that
# multi-line fields (Description, Title) are read in full via read.dcf.
#
# A test that names a CRAN package reproduces a false positive or a missed
# finding from that package's real sources, so a regression fails here first.

# Test lab_description_length() ----

test_that("lab_description_length(): reads continuation lines, not just line 1", {
  pkg <- make_temp_dir()
  long_desc <- paste(
    "First sentence with enough words to fool nobody.",
    "    Second continuation sentence with even more words.",
    "    Third line continuing to make sure word counting picks it up.",
    sep = "\n"
  )
  write_pkg(pkg, description = long_desc)
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_true(res$description_length$passed)
  expect_gte(res$description_length$words, 20L)
  expect_gte(res$description_length$sentences, 2L)
})

test_that("lab_description_length(): still flags short descriptions", {
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Short.")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$description_length$passed)
})

test_that("lab_description_length(): measures words, not sentences", {
  # renderthis ships a complete 31-word single-sentence Description. Demanding
  # "2+ sentences" has no authority and flagged it.
  one_sentence <- paste(
    "Render slides to different formats, including 'html', 'pdf', 'png', 'gif',",
    "'pptx', and 'mp4', as well as a 'social' output, a 'png' of the first slide",
    "re-sized for sharing on social media."
  )
  expect_true(
    lab_description_length(make_temp_dir(),
      verbose = FALSE,
      desc = c(Description = one_sentence)
    )$passed
  )
})

test_that("lab_description_length(): flags a Description that says nothing", {
  res <- lab_description_length(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "Does stuff.")
  )
  expect_false(res$passed)
})

test_that("lab_description_length(): a 31-word single-sentence Description is not too short", {
  # renderthis/DESCRIPTION. The old rule demanded 2+ sentences, which has no
  # authority behind it.
  desc <- paste(
    "Render slides to different formats, including 'html', 'pdf', 'png', 'gif',",
    "'pptx', and 'mp4', as well as a 'social' output, a 'png' of the first slide",
    "re-sized for sharing on social media."
  )
  expect_true(
    lab_description_length(make_temp_dir(),
      verbose = FALSE,
      desc = c(Description = desc)
    )$passed
  )
})

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

# Test dcf_field() ----

test_that("dcf_field(): reads a field from a list or a vector", {
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "Tools for Tests")
  m <- read.dcf(file.path(pkg, "DESCRIPTION"))
  for (desc in list(as.list(m[1L, ]), m[1L, ])) {
    expect_identical(dcf_field(desc, "Title"), "Tools for Tests")
    expect_null(dcf_field(desc, "Copyright"))
  }
})

# Test resolve_description() ----

test_that("resolve_description(): reads a read.dcf() matrix or a vector as the list read_description() gives", {
  # A matrix keeps its field names as column names, so desc[["Title"]] on one is
  # a subscript error, and so is a missing field on a vector.
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "Tools for Tests")
  f <- file.path(pkg, "DESCRIPTION")
  m <- read.dcf(f)
  expect_identical(resolve_description(pkg, m), read_description(f))
  expect_identical(resolve_description(pkg, m[1L, ]), read_description(f))
  expect_null(resolve_description(pkg, m)[["Copyright"]])
  expect_null(resolve_description(pkg, c(Title = "Tools"))[["Description"]])
})

test_that("resolve_description(): every DESCRIPTION check reads a read.dcf() matrix", {
  # `desc` is documented as what read.dcf() returns. Each check must find in
  # the matrix what it finds in the file.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    title = "Tools for \"ggplot2\" Plots in Python",
    description = "Builds on ggplot2 and \"shiny\" to fit XYZ models for the user."
  )
  m <- read.dcf(file.path(pkg, "DESCRIPTION"))
  ns <- asNamespace("checktor")
  checks <- ls(ns, pattern = "^lab_")
  checks <- checks[vapply(
    checks,
    function(f) "desc" %in% names(formals(get(f, envir = ns))),
    logical(1)
  )]
  expect_true(all(c("lab_acronyms", "lab_description_quoted_quotes") %in% checks))
  for (f in checks) {
    check <- get(f, envir = ns)
    from_file <- check(pkg, verbose = FALSE)
    from_matrix <- check(pkg, verbose = FALSE, desc = m)
    expect_identical(from_matrix$issues, from_file$issues, info = f)
    expect_identical(from_matrix$passed, from_file$passed, info = f)
  }
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

# Test lab_title_length() ----

test_that("lab_title_length(): flags a title longer than 65 characters", {
  pkg <- make_temp_dir()
  write_pkg(pkg, title = paste(rep("Word", 20), collapse = " ")) # > 65 chars
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_false(res$title_length$passed)

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, title = "Concise Package Title")
  expect_true(
    diagnose_description_issues(pkg_ok, verbose = FALSE)$title_length$passed
  )
})

test_that("lab_title_length(): puts the boundary between 65 and 66 chars", {
  # The other fixtures are 99 and 21 characters, which leaves the threshold free
  # to move anywhere in 22..99 undetected. Pin it exactly.
  #
  # 65 is the width Writing R Extensions says a listing may truncate to, not a
  # limit, so a title of exactly 65 characters shows in full and is not a
  # finding. 375 packages on CRAN sit at exactly 65.
  for (n in c(64L, 65L)) {
    ok <- lab_title_length(make_temp_dir(), verbose = FALSE, desc = c(Title = strrep("W", n)))
    expect_true(ok$passed, info = paste(n, "characters"))
    expect_equal(ok$nchar, n)
  }

  bad <- lab_title_length(make_temp_dir(), verbose = FALSE, desc = c(Title = strrep("W", 66)))
  expect_false(bad$passed)
  expect_equal(length(bad$issues), 1L)
  expect_match(bad$issues, "66 characters", all = FALSE)
  # The message says how much would be lost, not just that it is long.
  expect_match(bad$issues, "last 1 character", all = FALSE)
})

# Test lab_description_function_quotes() ----

test_that("lab_description_function_quotes(): flags single-quoted functions", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      "Wraps the 'lm()' interface for users.",
      "It does a number of helpful things here."
    )
  )
  # Not part of a run any more: WRE says single quotes are for non-English usage
  # INCLUDING other packages, an inclusive list, so a quoted function name breaks
  # no rule. Still callable directly.
  expect_false(
    lab_description_function_quotes(pkg, verbose = FALSE)$passed
  )
  expect_null(
    diagnose_description_issues(
      pkg,
      verbose = FALSE
    )$description_function_quotes
  )
})

test_that("lab_description_function_quotes(): accepts quoted software names", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    description = paste(
      "Provides an interface to 'ggplot2' graphics.",
      "It does a number of helpful things here."
    )
  )
  expect_true(
    lab_description_function_quotes(pkg, verbose = FALSE)$passed
  )
})

# Test lab_authors() ----

test_that("lab_authors(): is OK when Authors@R is present, fails otherwise", {
  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok)
  expect_true(
    diagnose_description_issues(pkg_ok, verbose = FALSE)$authors$passed
  )

  pkg_legacy <- make_temp_dir()
  write_pkg(
    pkg_legacy,
    authors_r = NULL,
    author = "A. Tester",
    maintainer = "A. Tester <a@example.com>"
  )
  expect_false(
    diagnose_description_issues(pkg_legacy, verbose = FALSE)$authors$passed
  )
})

test_that("lab_authors(): flags an unfilled usethis template", {
  # pcaR2 shipped exactly this and checktor's presence-only check passed it, even
  # though it is a hard CRAN rejection. R CMD check says nothing: the field IS
  # present, so it has nothing to complain about.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    authors_r = paste0(
      "person(\"First\", \"Last\", , \"january.weiner@gmail.com\", ",
      "role = c(\"aut\", \"cre\", \"cph\"))"
    )
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)$authors
  expect_false(res$passed)
  expect_true(any(grepl("placeholder", res$issues)))
})

test_that("lab_authors(): flags a placeholder email and Your Name", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    authors_r = paste0(
      "person(\"Your Name\", , , \"you@example.com\", role = c(\"aut\", \"cre\"))"
    )
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)$authors
  expect_false(res$passed)
  # Both placeholders must be named. The email detector alone satisfies
  # `passed == FALSE`, so without this the "Your Name" entry could vanish from
  # the placeholder list unnoticed.
  expect_match(res$issues, "Your Name", all = FALSE)
  expect_match(res$issues, "you@example.com", all = FALSE)
})

test_that("lab_authors(): does not invent placeholders in a real name", {
  # "Firstname Lastly" contains the placeholder words as substrings; the word
  # boundaries in the matcher are what keep this a pass.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    authors_r = paste0(
      "person(\"Firstname\", \"Lastly\", email = \"f.lastly@university.edu\", ",
      "role = c(\"aut\", \"cre\"))"
    )
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)$authors
  expect_true(res$passed)
  expect_equal(length(res$issues), 0L)
})

test_that("lab_authors(): passes a real, filled-in Authors@R", {
  pkg <- make_temp_dir()
  write_pkg(pkg) # helper default is a real name/email
  expect_true(diagnose_description_issues(pkg, verbose = FALSE)$authors$passed)
})

test_that("lab_authors(): passes a well-formed Authors@R", {
  aar <- "person('Jane', 'Doe', email = 'jane@example.org', role = c('aut', 'cre'))"
  expect_true(
    lab_authors(make_temp_dir(),
      verbose = FALSE,
      desc = list(`Authors@R` = aar)
    )$passed
  )
})

test_that("lab_authors(): flags Authors@R with no maintainer (cre)", {
  aar <- "person('Jane', 'Doe', role = 'aut')"
  res <- lab_authors(make_temp_dir(), verbose = FALSE, desc = list(`Authors@R` = aar))
  expect_false(res$passed)
  expect_true(any(grepl("cre", res$issues)))
})

test_that("lab_authors(): flags a person with no name", {
  aar <- "person(role = c('aut', 'cre'))"
  res <- lab_authors(make_temp_dir(), verbose = FALSE, desc = list(`Authors@R` = aar))
  expect_false(res$passed)
  expect_true(any(grepl("no name", res$issues)))
})

test_that("lab_authors(): flags an Authors@R that does not parse", {
  res <- lab_authors(make_temp_dir(),
    verbose = FALSE,
    desc = list(`Authors@R` = "person('Jane',,")
  )
  expect_false(res$passed)
  expect_true(any(grepl("does not parse", res$issues)))
})

test_that("lab_authors(): flags a person with no role", {
  aar <- "c(person('Jane', 'Doe', role = 'cre'), person('No', 'Role'))"
  res <- lab_authors(make_temp_dir(), verbose = FALSE, desc = list(`Authors@R` = aar))
  expect_false(res$passed)
  expect_true(any(grepl("no role", res$issues)))
})

test_that("lab_authors(): reports a field that evaluates to a non-person", {
  res <- lab_authors(make_temp_dir(),
    verbose = FALSE,
    desc = list(`Authors@R` = "list(1, 2)")
  )
  expect_false(res$passed)
  expect_true(any(grepl("does not (parse|evaluate)", res$issues)))
})

test_that("lab_authors(): a deeply nested Authors@R is reported, not a crash", {
  # 1 + 1 + ... + 1 parses as one call per term, deeper than R's own stack
  # lets a recursive walk go. The field is still one R refuses, so it is a
  # finding like any other.
  deep <- paste(rep("1", 5000), collapse = " + ")
  aar <- sprintf(
    "person('A', 'B', role = c('aut', 'cre'), comment = c(x = %s))",
    deep
  )
  res <- NULL
  expect_no_error(
    res <- lab_authors(make_temp_dir(), verbose = FALSE, desc = list(`Authors@R` = aar))
  )
  expect_false(res$passed)
})

test_that("lab_authors(): Authors@R is not executed while diagnosing", {
  # checktor lints other people's packages; a malicious Authors@R must not run.
  marker <- withr::local_tempfile()
  # A pure-R side effect, so a leak shows on every OS, Windows included.
  aar <- sprintf("file.create(%s)", deparse(marker))
  res <- lab_authors(make_temp_dir(), verbose = FALSE, desc = list(`Authors@R` = aar))
  expect_false(file.exists(marker)) # the command did not run
  expect_false(res$passed) # and the field is reported, not silently accepted
})

test_that("lab_authors(): accepts parentheses around a value, as R does", {
  # panelSUR writes role = ("aut") and TwoCutoff person(("Bhrigu Kumar"), ...).
  # R's own reader allows `(`, so both build, and neither is a finding.
  aar <- paste0(
    "c(person(('Ann'), 'Bee', email = 'a@example.com', role = c('aut', 'cre')), ",
    "person('Cy', 'Dee', role = ('aut')))"
  )
  res <- lab_authors(make_temp_dir(), verbose = FALSE, desc = list(`Authors@R` = aar))
  expect_true(res$passed)
  expect_length(res$issues, 0L)
})

test_that("lab_authors(): reads utils::person() but reports it, as R CMD build does", {
  # R 4.6.0 and later refuse any call in Authors@R outside person(),
  # as.person(), c(), list(), paste(), paste0() and `(`, so R CMD build stops
  # with "Malformed Authors@R field" on a namespace-qualified call.
  aar <- paste0(
    "utils::person('Ann', 'Bee', email = 'a@example.com', ",
    "role = c('aut', 'cre'))"
  )
  res <- lab_authors(make_temp_dir(),
    verbose = FALSE,
    desc = list(`Authors@R` = aar)
  )
  expect_false(res$passed)
  expect_identical(
    res$issues,
    paste0(
      "Authors@R calls utils::person(...), which R CMD build refuses from ",
      "R 4.6.0 on as a malformed field: call only person(), as.person(), ",
      "c(), list(), paste() and paste0(), by their bare names"
    )
  )
})

test_that("lab_authors(): reports every call R's reader refuses, in one issue", {
  # R's allow-list is on the name of the function called, so a parenthesised
  # function is refused as well as a namespaced one, though both evaluate to
  # person() or c().
  aar <- paste0(
    "(c)(person('Ann', 'Bee', email = 'a@example.com', ",
    "role = c('aut', 'cre')), (person)('ACME', role = 'cph'), ",
    "utils::person('Cy', 'Dee', role = 'ctb'))"
  )
  res <- lab_authors(make_temp_dir(),
    verbose = FALSE,
    desc = list(`Authors@R` = aar)
  )
  expect_false(res$passed)
  expect_identical(
    res$issues,
    paste0(
      "Authors@R calls (c)(...), (person)(...) and utils::person(...), which ",
      "R CMD build refuses from R 4.6.0 on as a malformed field: call only ",
      "person(), as.person(), c(), list(), paste() and paste0(), by their ",
      "bare names"
    )
  )
})

test_that("lab_authors(): reports a person combined with a list, rather than erroring", {
  aar <- paste0(
    "c(person('Ann', 'Bee', email = 'a@example.com', role = c('aut', 'cre')), ",
    "list(person('ACME', role = 'cph')))"
  )
  res <- lab_authors(make_temp_dir(), verbose = FALSE, desc = list(`Authors@R` = aar))
  expect_false(res$passed)
  expect_identical(
    res$issues,
    "Authors@R does not parse: entry 2 is not a person, so R cannot read the authors from it"
  )
})

# Test parse_authors_at_r() ----

test_that("parse_authors_at_r(): `(`, `::` and `:::` reach person() and as.person() only", {
  parsed <- function(aar) parse_authors_at_r(list(`Authors@R` = aar))

  pa <- parsed("person(('Ann'), 'Bee', role = ('cph'))")
  expect_null(pa$error)
  expect_identical(pa$persons$role, "cph")
  expect_identical(pa$refused, character(0))

  pa <- parsed(paste0(
    "c(utils::person('Ann', 'Bee', role = 'aut'), ",
    "utils:::as.person('ACME <a@example.com> [cph]'), ",
    "\"utils\"::\"person\"('Cy', 'Dee', role = 'ctb'))"
  ))
  expect_null(pa$error)
  expect_identical(unlist(pa$persons$role), c("aut", "cph", "ctb"))
  expect_identical(
    pa$refused,
    c(
      "utils::person(...)",
      "utils:::as.person(...)",
      "\"utils\"::\"person\"(...)"
    )
  )

  pa <- parsed("base::paste('Ann')")
  expect_null(pa$persons)
  expect_identical(
    pa$error,
    "only utils::person and utils::as.person may be called with a namespace, not base::paste"
  )
  expect_identical(pa$refused, "base::paste(...)")
})

test_that("parse_authors_at_r(): refuses exactly the calls R's own reader does", {
  # The allow-list arrived in R 4.6.0, where R CMD build reads the field with
  # utils:::.read_authors_at_R_field(strict = TRUE).
  skip_if(getRversion() < "4.6.0")
  fields <- c(
    "person('First', 'Last', , 'a@b.com', role = c('aut', 'cre'))",
    "c(person(('A'), role = ('cre')), as.person('C <c@d.org> [ctb]'))",
    "list(person(paste('A', 'B'), paste0('C', 'D'), role = 'cre'))",
    "(c)(person('A', role = 'cre'))",
    "(person)('A', role = 'cre')",
    "utils::person('A', role = 'cre')",
    "do.call(person, list('A', role = 'cre'))",
    "person('A', role = rep('cre', 1L))",
    "person('A', role = 'cre', comment = c(n = -1))",
    "person('A', role = if (TRUE) 'cre')"
  )
  for (aar in fields) {
    r <- tryCatch(
      utils:::.read_authors_at_R_field(aar, strict = TRUE),
      error = conditionMessage
    )
    r_refuses <- is.character(r) && grepl("possibly unsafe calls", r)
    pa <- parse_authors_at_r(list(`Authors@R` = aar))
    expect_identical(length(pa$refused) > 0L, r_refuses, info = aar)
  }
})

test_that("parse_authors_at_r(): names the calls R refuses without running them", {
  # The walk reads only the parse tree. Pure-R side effects, so a leak shows on
  # every OS, Windows included.
  marker <- withr::local_tempfile()
  m <- deparse(marker)
  payloads <- list(
    list(sprintf("(file.create)(%s)", m), "(file.create)(...)"),
    list(sprintf("do.call('file.create', list(%s))", m), "do.call(...)"),
    list(
      sprintf("person('A', role = 'cph', comment = c(x = file.create(%s)))", m),
      "file.create(...)"
    ),
    list(
      sprintf("eval(quote(file.create(%s)))", m),
      c("eval(...)", "quote(...)", "file.create(...)")
    ),
    list(
      sprintf("`::`('base', 'file.create')(%s)", m),
      "\"base\"::\"file.create\"(...)"
    ),
    list(
      sprintf("utils::person(given = (file.create)(%s), role = 'cph')", m),
      c("utils::person(...)", "(file.create)(...)")
    ),
    # A refused function part is named whole, what it contains included.
    list(
      sprintf("(function() file.create(%s))()", m),
      sprintf("(function() file.create(%s))()", m)
    )
  )
  for (p in payloads) {
    pa <- parse_authors_at_r(list(`Authors@R` = p[[1L]]))
    expect_false(file.exists(marker))
    expect_identical(pa$refused, p[[2L]], info = p[[1L]])
    res <- lab_authors(make_temp_dir(),
      verbose = FALSE,
      desc = list(`Authors@R` = p[[1L]])
    )
    expect_false(file.exists(marker))
    expect_match(res$issues, "^Authors@R calls ", all = FALSE)
  }
})

test_that("parse_authors_at_r(): `(` and `::` cannot reach code outside the sandbox", {
  # Pure-R side effects, so a leak shows on every OS, Windows included.
  marker <- withr::local_tempfile()
  m <- deparse(marker)
  payloads <- c(
    sprintf("base::file.create(%s)", m),
    sprintf("base:::file.create(%s)", m),
    sprintf("(base::file.create)(%s)", m),
    sprintf("(file.create)(%s)", m),
    sprintf("`::`('base', 'file.create')(%s)", m),
    sprintf("`::`(paste0('ba', 'se'), file.create)(%s)", m),
    sprintf("utils::getFromNamespace('file.create', 'base')(%s)", m),
    sprintf("utils::person(given = (file.create)(%s), role = 'cph')", m),
    sprintf("person('A', role = 'cph', comment = c(x = base::file.create(%s)))", m)
  )
  for (aar in payloads) {
    pa <- parse_authors_at_r(list(`Authors@R` = aar))
    expect_false(file.exists(marker))
    expect_null(pa$persons)
    expect_type(pa$error, "character")
    res <- lab_authors(make_temp_dir(), verbose = FALSE, desc = list(`Authors@R` = aar))
    expect_false(file.exists(marker))
    expect_match(res$issues, "^Authors@R does not parse: ", all = FALSE)
  }
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

# Test lab_title_case() ----

test_that("lab_title_case(): does not flag a quoted software name", {
  # This is the false positive that made the homegrown word-loop unusable.
  # R's own engine restores single-quoted spans before comparing, so 'shiny'
  # keeps its lowercase s.
  desc <- c(Title = "Extra Diagnostics for 'shiny' and 'rmarkdown' Packages")
  expect_true(lab_title_case(make_temp_dir(), verbose = FALSE, desc = desc)$passed)
})

test_that("lab_title_case(): flags a genuinely non-title-case Title", {
  desc <- c(Title = "A package for running extra checks")
  res <- lab_title_case(make_temp_dir(), verbose = FALSE, desc = desc)
  expect_false(res$passed)
  # The suggestion must carry the corrected string so it can be pasted in.
  expect_match(res$issues, "Running Extra Checks", fixed = TRUE, all = FALSE)
})

test_that("lab_title_case(): accepts a correct Title", {
  desc <- c(Title = "Extra CRAN Diagnostics for R Packages")
  expect_true(lab_title_case(make_temp_dir(), verbose = FALSE, desc = desc)$passed)
})

test_that("lab_title_case(): a quoted package name in Title keeps its own capitalisation", {
  # R's own toTitleCase() restores single-quoted spans, which is why R does not
  # flag 'shiny' and the homegrown word-loop did.
  expect_true(
    lab_title_case(make_temp_dir(),
      verbose = FALSE,
      desc = c(Title = "Extra Diagnostics for 'shiny' and 'rmarkdown' Packages")
    )$passed
  )
})

# Test lab_license() ----

test_that("lab_license(): accepts a standardizable license", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  # `MIT + file LICENSE` is only valid when the file it points at exists.
  writeLines(
    c("YEAR: 2026", "COPYRIGHT HOLDER: Jane Doe"),
    file.path(pkg, "LICENSE")
  )
  expect_true(
    lab_license(
      pkg,
      verbose = FALSE,
      desc = c(License = "MIT + file LICENSE")
    )$passed
  )
  expect_true(
    lab_license(
      pkg,
      verbose = FALSE,
      desc = c(License = "GPL (>= 3)")
    )$passed
  )
})

test_that("lab_license(): flags a non-standardizable license", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  res <- lab_license(
    pkg,
    verbose = FALSE,
    desc = c(License = "Do whatever you like")
  )
  expect_false(res$passed)
})

test_that("lab_license(): flags a missing referenced LICENSE file", {
  pkg <- make_temp_dir()
  write_pkg(pkg) # no LICENSE file written
  res <- lab_license(
    pkg,
    verbose = FALSE,
    desc = c(License = "MIT + file LICENSE")
  )
  expect_false(res$passed)
  expect_match(res$issues, "LICENSE", all = FALSE)
})

# Test lab_description_starts_with() ----

test_that("lab_description_starts_with(): flags CRAN's forbidden openers", {
  for (bad in c(
    "This package provides tools for X.",
    "A package that does X.",
    "In this package we do X."
  )) {
    res <- lab_description_starts_with(make_temp_dir(),
      verbose = FALSE,
      desc = c(Description = bad)
    )
    expect_false(res$passed, info = bad)
  }
})

test_that("lab_description_starts_with(): flags a lowercase initial", {
  # R's own descr_bad_initial rule, which checktor previously lacked.
  res <- lab_description_starts_with(make_temp_dir(),
    verbose = FALSE,
    desc = c(Description = "runs extra diagnostics on R packages.")
  )
  expect_false(res$passed)
})

test_that("lab_description_starts_with(): accepts a well-formed Description", {
  expect_true(
    lab_description_starts_with(make_temp_dir(),
      verbose = FALSE,
      desc = c(Description = "Runs extra diagnostics on R packages.")
    )$passed
  )
})

# Test lab_license_year() ----

test_that("lab_license_year(): flags an unfilled LICENSE template", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c("YEAR: <YEAR>", "COPYRIGHT HOLDER: <COPYRIGHT HOLDER>"),
    file.path(pkg, "LICENSE")
  )
  res <- lab_license_year(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("lab_license_year(): does not flag an old but filled-in year", {
  # The old rule fired on every package not touched this calendar year. A
  # LICENSE reading `YEAR: 1999` passes R CMD check --as-cran in silence.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  writeLines(
    c("YEAR: 1999", "COPYRIGHT HOLDER: Jane Doe"),
    file.path(pkg, "LICENSE")
  )
  expect_true(lab_license_year(pkg, verbose = FALSE)$passed)
})

test_that("lab_license_year(): passes when there is no LICENSE file", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_true(lab_license_year(pkg, verbose = FALSE)$passed)
})

# Test lab_date_format() ----

test_that("lab_date_format(): passes when Date is absent, the preferred case", {
  expect_true(
    lab_date_format(make_temp_dir(), verbose = FALSE, desc = list(Package = "x"))$passed
  )
})

test_that("lab_date_format(): passes on a current ISO-8601 date", {
  today <- format(Sys.Date())
  expect_true(
    lab_date_format(make_temp_dir(), verbose = FALSE, desc = list(Date = today))$passed
  )
})

test_that("lab_date_format(): flags a non-ISO-8601 Date", {
  res <- lab_date_format(make_temp_dir(), verbose = FALSE, desc = list(Date = "Jan 2020"))
  expect_false(res$passed)
  expect_true(any(grepl("ISO 8601", res$issues)))
})

test_that("lab_date_format(): flags a stale Date read from the package file", {
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = "Date: 2000-01-01")
  res <- diagnose_description_issues(pkg, verbose = FALSE)$date_format
  expect_false(res$passed)
  expect_true(any(grepl("month old", res$issues)))
})

test_that("lab_date_format(): flags a future Date", {
  expect_false(
    lab_date_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Date = "2999-01-01")
    )$passed
  )
})

# Test lab_encoding_utf8() ----

test_that("lab_encoding_utf8(): accepts UTF-8, latin1, latin2 or none", {
  for (enc in c("UTF-8", "utf-8", "latin1", "latin2")) {
    expect_true(
      lab_encoding_utf8(make_temp_dir(),
        verbose = FALSE,
        desc = list(Encoding = enc)
      )$passed,
      info = enc
    )
  }
  expect_true(
    lab_encoding_utf8(make_temp_dir(), verbose = FALSE, desc = list(Package = "x"))$passed
  )
})

test_that("lab_encoding_utf8(): flags a non-portable Encoding", {
  res <- lab_encoding_utf8(make_temp_dir(),
    verbose = FALSE,
    desc = list(Encoding = "KOI8-R")
  )
  expect_false(res$passed)
  expect_true(any(grepl("portable", res$issues)))
})

# Test lab_version_format() ----

test_that("lab_version_format(): passes on ordinary versions and dated ones", {
  expect_true(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = "0.2.0")
    )$passed
  )
  dated <- paste0(format(Sys.Date(), "%Y"), ".1")
  expect_true(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = dated)
    )$passed
  )
})

test_that("lab_version_format(): flags a leading-zero component", {
  res <- lab_version_format(make_temp_dir(),
    verbose = FALSE,
    desc = list(Version = "0.02.0")
  )
  expect_false(res$passed)
  expect_true(any(grepl("leading zero", res$issues)))
})

test_that("lab_version_format(): flags a suspiciously large component", {
  expect_false(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = "9999.1")
    )$passed
  )
})

test_that("lab_version_format(): flags an unparseable version", {
  res <- lab_version_format(make_temp_dir(),
    verbose = FALSE,
    desc = list(Version = "not.a.version")
  )
  expect_false(res$passed)
  expect_true(any(grepl("not a valid", res$issues)))
})

test_that("lab_version_format(): exempts dated and dev versions", {
  # a calendar-versioned package from a prior year, a zero-padded month, and the
  # ubiquitous .9000 development suffix are all legitimate, not oversized.
  expect_true(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = "2025.4")
    )$passed
  )
  expect_true(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = "2026.01")
    )$passed
  )
  expect_true(
    lab_version_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(Version = "0.2.0.9000")
    )$passed
  )
})

# Test lab_identifier_format() ----

test_that("lab_identifier_format(): passes a valid ORCID and no identifier", {
  ok <- "person('J', 'D', role = 'cre', comment = c(ORCID = '0000-0002-1825-0097'))"
  expect_true(
    lab_identifier_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(`Authors@R` = ok)
    )$passed
  )
  none <- "person('J', 'D', role = 'cre')"
  expect_true(
    lab_identifier_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(`Authors@R` = none)
    )$passed
  )
})

test_that("lab_identifier_format(): flags an ORCID that fails its checksum", {
  bad <- "person('J', 'D', role = 'cre', comment = c(ORCID = '0000-0002-1825-0090'))"
  res <- lab_identifier_format(make_temp_dir(),
    verbose = FALSE,
    desc = list(`Authors@R` = bad)
  )
  expect_false(res$passed)
  expect_true(any(grepl("ORCID", res$issues)))
})

test_that("lab_identifier_format(): accepts an X check-digit and a URL form", {
  xd <- "person('J', 'D', role = 'cre', comment = c(ORCID = '0000-0002-1694-233X'))"
  expect_true(
    lab_identifier_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(`Authors@R` = xd)
    )$passed
  )
  url <- "person('J', 'D', role = 'cre', comment = c(ORCID = 'https://orcid.org/0000-0002-1694-233X'))"
  expect_true(
    lab_identifier_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(`Authors@R` = url)
    )$passed
  )
})

test_that("lab_identifier_format(): validates ROR ids and ignores free text", {
  good <- "person('J', 'D', role = 'cre', comment = c(ROR = '05dxps055'))"
  expect_true(
    lab_identifier_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(`Authors@R` = good)
    )$passed
  )
  bad <- "person('J', 'D', role = 'cre', comment = c(ROR = 'nope'))"
  res <- lab_identifier_format(make_temp_dir(),
    verbose = FALSE,
    desc = list(`Authors@R` = bad)
  )
  expect_false(res$passed)
  expect_true(any(grepl("ROR", res$issues)))
  free <- "person('J', 'D', role = 'cre', comment = 'maintainer since 2020')"
  expect_true(
    lab_identifier_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(`Authors@R` = free)
    )$passed
  )
})

test_that("lab_identifier_format(): reads identifiers behind `(` and utils::person()", {
  bad <- c(
    "person(('J'), 'D', role = 'cre', comment = c(ORCID = ('0000-0002-1825-0090')))",
    "utils::person('J', 'D', role = 'cre', comment = c(ORCID = '0000-0002-1825-0090'))"
  )
  for (aar in bad) {
    res <- lab_identifier_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(`Authors@R` = aar)
    )
    expect_identical(res$issues, "Invalid ORCID iD in Authors@R: 0000-0002-1825-0090")
  }
})

test_that("lab_identifier_format(): sits out when Authors@R cannot be read", {
  # lab_authors() reports the field itself. This check has nothing to examine,
  # so it says it did not run rather than passing a field it never read.
  unreadable <- c(
    "person('J',,",
    paste0(
      "c(person('J', 'D', role = 'cre'), ",
      "list(person('K', 'E', role = 'aut', comment = c(ORCID = 'nope'))))"
    )
  )
  for (aar in unreadable) {
    res <- lab_identifier_format(make_temp_dir(),
      verbose = FALSE,
      desc = list(`Authors@R` = aar)
    )
    expect_identical(check_status(res), "skipped")
    expect_identical(res$skip_reason, "Authors@R could not be read")
    expect_length(res$issues, 0L)
  }
})

# Test spelling_accepted_words() ----

test_that("spelling_accepted_words(): reads every Config/checktor vocabulary", {
  # A name listed for any of the quoting checks is a word the package uses on
  # purpose, so the spelling check must not ask about it either.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = c(
      "Config/checktor/acronyms: Qacro",
      "Config/checktor/software_names: Vbtool",
      "Config/checktor/language_names: Zqlang",
      "Config/checktor/format_names: Qwxformat"
    )
  )
  expect_contains(
    spelling_accepted_words(pkg),
    c("Qacro", "Vbtool", "Zqlang", "Qwxformat")
  )
})

# Test lab_spelling() ----

test_that("lab_spelling(): flags DESCRIPTION words and honours a whitelist", {
  skip_on_cran() # the words flagged depend on the installed dictionary
  skip_if_not(
    nzchar(Sys.which("aspell")) || nzchar(Sys.which("hunspell")),
    "no spell-check backend"
  )
  withr::local_options(checktor.spelling = TRUE)
  desc <- "Build a WASM REPL for WebAssembly workflows and more."

  pkg <- make_temp_dir()
  write_pkg(pkg, description = desc)
  res <- lab_spelling(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_true(all(c("WASM", "REPL", "WebAssembly") %in% res$issues))

  # accepted via Config/checktor/acronyms
  pkg2 <- make_temp_dir()
  write_pkg(
    pkg2,
    description = desc,
    extra = "Config/checktor/acronyms: WASM, REPL, WebAssembly"
  )
  expect_true(lab_spelling(pkg2, verbose = FALSE)$passed)

  # accepted via a .aspell/ dictionary
  pkg3 <- make_temp_dir()
  write_pkg(pkg3, description = desc)
  dir.create(file.path(pkg3, ".aspell"))
  saveRDS(
    c("WASM", "REPL", "WebAssembly"),
    file.path(pkg3, ".aspell", "words.rds")
  )
  expect_true(lab_spelling(pkg3, verbose = FALSE)$passed)
})

test_that("lab_spelling(): reports a skip, not a pass, when turned off", {
  # A skipped check that reads as a passing one is exactly the failure mode the
  # skipped-result contract exists to prevent: the printed summary would drop
  # spelling from "checks did not run".
  withr::local_options(checktor.spelling = FALSE)
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Build a WASM REPL for WebAssembly.")
  res <- lab_spelling(pkg, verbose = FALSE)
  expect_true(res$skipped)
  expect_true(res$passed)
  expect_equal(length(res$issues), 0L)
})

test_that("lab_spelling(): reports a skip when no backend is installed", {
  withr::local_options(checktor.spelling = TRUE)
  # Empty the PATH so Sys.which() finds neither aspell nor hunspell, which is
  # the state every CI leg actually runs in.
  withr::local_envvar(PATH = "")
  skip_if(
    nzchar(Sys.which("aspell")) || nzchar(Sys.which("hunspell")),
    "backend still reachable with an empty PATH"
  )
  pkg <- make_temp_dir()
  write_pkg(pkg, description = "Build a WASM REPL for WebAssembly.")
  res <- lab_spelling(pkg, verbose = FALSE)
  expect_true(res$skipped)
  expect_match(res$skip_reason, "backend")
})

# Test spelling_accepted_words() ----

test_that("spelling_accepted_words(): gathers every whitelist mechanism", {
  # The detection test above is gated behind a backend that no CI leg installs,
  # so the whitelist plumbing is pinned here instead: no aspell/hunspell needed.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    extra = c(
      "Config/checktor/acronyms: WebAssembly",
      "Config/checktor/software_names: Shinylive"
    )
  )
  dir.create(file.path(pkg, ".aspell"))
  saveRDS("WASM", file.path(pkg, ".aspell", "words.rds"))
  dir.create(file.path(pkg, "inst"))
  writeLines("REPL", file.path(pkg, "inst", "WORDLIST"))

  # One word per source, so dropping any single source changes the answer.
  expect_setequal(
    spelling_accepted_words(pkg),
    c("WASM", "REPL", "WebAssembly", "Shinylive")
  )
})

test_that("spelling_accepted_words(): is empty when there is no whitelist", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  expect_equal(spelling_accepted_words(pkg), character(0))
})

# Test lab_title_starts_with_article() ----

test_that("lab_title_starts_with_article(): is NOT part of a default run", {
  # A mis-transplant of CRAN's real rule, whose source requires the literal noun
  # "package" after the article AND applies to the Description field, not the
  # Title. jsonlite ("A Simple and Robust JSON Parser and Generator for R") and
  # curl ("A Modern and Flexible Web Client for R") are on CRAN with such titles.
  pkg <- make_temp_dir()
  write_pkg(pkg, title = "A Modern and Flexible Web Client")
  res <- diagnose_description_issues(pkg, verbose = FALSE)
  expect_null(res$title_starts_with_article)

  # Still callable directly.
  expect_false(
    lab_title_starts_with_article(pkg, verbose = FALSE)$passed
  )
})

# Test lab_title_redundant_phrases() ----

test_that("lab_title_redundant_phrases(): flags 'for R' and 'Tools for' patterns", {
  for (bad in c(
    "Statistical Models for R",
    "A Toolkit for Imaging",
    "Tools for Reproducible Reporting"
  )) {
    pkg <- make_temp_dir()
    write_pkg(pkg, title = bad)
    expect_false(
      diagnose_description_issues(
        pkg,
        verbose = FALSE
      )$title_redundant_phrases$passed,
      info = bad
    )
  }

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, title = "Statistical Modeling")
  expect_true(
    diagnose_description_issues(
      pkg_ok,
      verbose = FALSE
    )$title_redundant_phrases$passed
  )
})

# Test lab_cph_role() ----

test_that("lab_cph_role(): accepts cph-bearing Authors@R and flags otherwise", {
  pkg <- make_temp_dir()
  write_pkg(pkg, authors_r = "person('A','B', role = c('aut','cre'))")
  res <- lab_cph_role(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(res$issues, "No [cph] role in Authors@R and no Copyright field")

  pkg_ok <- make_temp_dir()
  write_pkg(pkg_ok, authors_r = "person('A','B', role = c('aut','cre','cph'))")
  res_ok <- lab_cph_role(pkg_ok, verbose = FALSE)
  expect_true(res_ok$passed)
  expect_length(res_ok$issues, 0L)
})

test_that("lab_cph_role(): a Copyright field names the holder instead", {
  # CRAN asks only that ownership be clear, and a Copyright field makes it so.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    authors_r = "person('A','B', role = c('aut','cre'))",
    extra = "Copyright: ACME Corporation"
  )
  res <- lab_cph_role(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_length(res$issues, 0L)

  # With no Authors@R at all, the Copyright field still answers the question.
  res <- lab_cph_role(make_temp_dir(), verbose = FALSE,
    desc = list(Copyright = "ACME Corporation")
  )
  expect_true(res$passed)

  # A blank one names nobody.
  res <- lab_cph_role(make_temp_dir(), verbose = FALSE, desc = list(
    `Authors@R` = "person('A','B', role = c('aut','cre'))",
    Copyright = "  "
  ))
  expect_false(res$passed)
})

test_that("lab_cph_role(): reads roles, not the text of the field", {
  # A raw grep for "cph" passed any address or name that happened to contain it.
  no_role <- function(aar) {
    lab_cph_role(make_temp_dir(), verbose = FALSE, desc = list(`Authors@R` = aar))
  }
  expect_false(no_role(
    "person('A','B', email = 'cph@example.com', role = c('aut','cre'))"
  )$passed)
  expect_false(no_role(
    "person('A','B', role = c('aut','cre'), comment = c(note = 'not a cph'))"
  )$passed)

  # A second person holding the role, or the as.person() form, is a real one.
  expect_true(no_role(paste0(
    "c(person('A','B', role = c('aut','cre')), ",
    "person('ACME Corporation', role = 'cph'))"
  ))$passed)
  expect_true(no_role("as.person('A B <a@example.com> [aut, cre, cph]')")$passed)

  # Parentheses and a utils:: prefix are still the role, as R reads them.
  expect_true(no_role("person('ACME', role = ('cph'))")$passed)
  expect_true(no_role("person(('ACME Corporation'), role = c('cph'))")$passed)
  expect_true(no_role("utils::person('ACME', role = 'cph')")$passed)
  expect_true(no_role("utils::as.person('ACME [cph]')")$passed)
})

test_that("lab_cph_role(): reads the roles in a legacy Author field", {
  # With no Authors@R, the Author field is where R reads the authors from, and
  # it writes each person's roles in square brackets.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    authors_r = NULL,
    author = "Ann Bee [aut, cre], ACME Corporation [cph]",
    maintainer = "Ann Bee <a@example.com>"
  )
  res <- lab_cph_role(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_length(res$issues, 0L)

  legacy <- function(author) {
    lab_cph_role(make_temp_dir(), verbose = FALSE, desc = list(Author = author))
  }
  expect_true(legacy("Ann Bee [aut,cre,cph]")$passed)
  # The role, not the letters: an address or a plain name is no holder.
  for (author in c("Ann Bee <cph@example.com> [aut, cre]", "Ann Bee, cph", "Ann Bee")) {
    res <- legacy(author)
    expect_false(res$passed)
    expect_identical(res$issues, "No [cph] role in Author and no Copyright field")
  }
})

test_that("lab_cph_role(): reads a legacy role in any case, but not in a comment", {
  legacy <- function(author) {
    lab_cph_role(make_temp_dir(), verbose = FALSE, desc = list(Author = author))
  }
  expect_true(legacy("Ann Bee [aut, cre], ACME Corporation [CPH]")$passed)
  expect_true(legacy("ACME (formerly Acme Ltd) [Cph]")$passed)
  # A comment is written in parentheses after the roles, and a bracket quoted
  # there is not a role.
  for (author in c(
    "Ann Bee [aut, cre] (see the [cph] note)",
    "Ann Bee [aut, cre] (ACME (her employer) [cph])"
  )) {
    res <- legacy(author)
    expect_false(res$passed)
    expect_identical(
      res$issues,
      "No [cph] role in Author and no Copyright field"
    )
  }
})

test_that("lab_cph_role(): reports a person combined with a list, rather than erroring", {
  aar <- "c(person('A', 'B', role = c('aut', 'cre')), list(person('ACME', role = 'cph')))"
  res <- lab_cph_role(make_temp_dir(), verbose = FALSE, desc = list(`Authors@R` = aar))
  expect_false(res$passed)
  expect_identical(
    res$issues,
    "Authors@R does not parse: entry 2 is not a person, so R cannot read the authors from it"
  )
})

test_that("lab_cph_role(): reports an Authors@R it cannot read, without running it", {
  marker <- withr::local_tempfile()
  aar <- sprintf(
    "c(person('A','B', role = 'cph'), file.create(%s))",
    deparse(marker)
  )
  res <- lab_cph_role(make_temp_dir(), verbose = FALSE,
    desc = list(`Authors@R` = aar)
  )
  expect_false(file.exists(marker))
  expect_false(res$passed)
  expect_match(res$issues, "^Authors@R does not parse: ")

  res <- lab_cph_role(make_temp_dir(), verbose = FALSE, desc = list())
  expect_false(res$passed)
  expect_identical(res$issues, "No Authors@R and no Copyright field")
})

test_that("lab_cph_role(): runs only on request (#17)", {
  # ?person: authors who are natural persons hold copyright by default and need
  # no cph role, so a package without one is not a finding in a default run.
  pkg <- make_temp_dir()
  write_pkg(pkg, authors_r = "person('A','B', role = c('aut','cre'))")
  r <- checktor(pkg, verbose = FALSE, progress = FALSE)
  expect_false("cph_role" %in% tidy(r)$check)
  expect_true("cph_role" %in% r$metadata$on_request_checks)
})

test_that("lab_cph_role(): does not ask a natural person to add cph", {
  pkg <- make_temp_dir()
  write_pkg(pkg, authors_r = "person('A','B', role = c('aut','cre'))")
  out <- paste(cli::cli_fmt(lab_cph_role(pkg)), collapse = " ")
  # The advice has to say both halves: who needs the role, and who does not.
  expect_match(out, "If an organisation owns the copyright", fixed = TRUE)
  expect_match(out, "natural persons hold copyright already", fixed = TRUE)
  expect_snapshot(res <- lab_cph_role(pkg))
})

# Test lab_description_file() ----

test_that("lab_description_file(): passes a DESCRIPTION R can read", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  res <- lab_description_file(pkg, verbose = FALSE)
  expect_true(res$passed)
  expect_length(res$issues, 0L)
})

test_that("lab_description_file(): flags a line that is neither field nor continuation", {
  res <- lab_description_file(unparseable_pkg(), verbose = FALSE)
  expect_false(res$passed)
  expect_length(res$issues, 1L)
  expect_match(res$issues, "^DESCRIPTION does not parse: ")
  # read.dcf()'s own reason, which quotes the start of the offending line.
  expect_match(res$issues, "this line is not a f", fixed = TRUE)
})

test_that("lab_description_file(): flags a blank line that splits the file", {
  # read.dcf() reads the text after a blank line as a second record. R's own
  # reader refuses that file, while checktor used to keep the first record and
  # read on, losing every field after the blank line.
  pkg <- make_temp_dir()
  write_pkg(pkg, extra = c("", "Suggests: testthat"))
  res <- lab_description_file(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_identical(
    res$issues,
    "DESCRIPTION contains a blank line, which splits it into more than one record"
  )
})

test_that("lab_description_file(): flags a missing DESCRIPTION", {
  skip_if_tempdir_in_package()
  res <- lab_description_file(make_temp_dir(), verbose = FALSE)
  expect_false(res$passed)
  expect_identical(res$issues, "DESCRIPTION file not found")
})

test_that("lab_description_file(): gives the reason R cannot open DESCRIPTION", {
  # read.dcf() stops with "cannot open the connection" and leaves the reason in
  # a warning, which used to reach the console while the issue said only that.
  pkg <- unopenable_pkg("directory")
  expect_no_warning(res <- lab_description_file(pkg, verbose = FALSE))
  expect_false(res$passed)
  expect_identical(res$issues, "DESCRIPTION is a directory, not a file")

  skip_on_os("windows") # a mode-000 file is not portable
  pkg <- unopenable_pkg("no_permission")
  skip_if(
    file.access(file.path(pkg, "DESCRIPTION"), 4L) == 0L,
    "this user can read a file with no read permission"
  )
  expect_no_warning(res <- lab_description_file(pkg, verbose = FALSE))
  expect_identical(
    res$issues,
    "DESCRIPTION cannot be read (permission denied)"
  )
})

test_that("lab_description_file(): gives the same reason in any language", {
  # The reason comes from the file system, not from the wording of R's
  # warnings, which a translated session words differently: in German the
  # directory was reported as "does not parse: kann Verbindung nicht öffnen".
  # local_language() sets LANGUAGE and resets R's message cache, as
  # Sys.setLanguage() does, and puts both back when the test ends.
  withr::local_language("de")
  pkg <- unopenable_pkg("directory")
  expect_no_warning(res <- lab_description_file(pkg, verbose = FALSE))
  expect_identical(res$issues, "DESCRIPTION is a directory, not a file")

  skip_on_os("windows") # a mode-000 file is not portable
  pkg <- unopenable_pkg("no_permission")
  skip_if(
    file.access(file.path(pkg, "DESCRIPTION"), 4L) == 0L,
    "this user can read a file with no read permission"
  )
  expect_no_warning(res <- lab_description_file(pkg, verbose = FALSE))
  expect_identical(
    res$issues,
    "DESCRIPTION cannot be read (permission denied)"
  )
})

test_that("lab_description_file(): takes desc like the other DESCRIPTION checks", {
  expect_identical(
    names(formals(lab_description_file)),
    c("path", "verbose", "desc")
  )
  # The question is about the file, so parsed fields handed in do not answer it.
  res <- lab_description_file(unparseable_pkg(),
    verbose = FALSE,
    desc = list(Package = "fine")
  )
  expect_false(res$passed)
  expect_match(res$issues, "^DESCRIPTION does not parse: ")
})

# Test diagnose_description_issues() ----

test_that("diagnose_description_issues(): a DESCRIPTION R cannot read is a failing check", {
  # It used to end the category early with no checks in it, which nothing
  # counted, so checktor() called a package R cannot install healthy.
  res <- diagnose_description_issues(unparseable_pkg(), verbose = FALSE)
  expect_s3_class(res, "checktor_category_result")
  expect_identical(failed_checks(res), "description_file")
  expect_equal(n_issues(res), 1L)
  expect_identical(res$description_file$severity, "policy")
})

test_that("diagnose_description_issues(): the checks that read DESCRIPTION sit out when R cannot", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  readable <- diagnose_description_issues(pkg, verbose = FALSE)
  res <- diagnose_description_issues(unparseable_pkg(), verbose = FALSE)

  # The same panel, so a check that could not run is named rather than missing.
  expect_identical(.check_names(res), .check_names(readable))
  status <- vapply(.check_names(res), function(nm) check_status(res[[nm]]), "")
  expect_identical(names(status)[status == "failed"], "description_file")
  # license_year reads LICENSE alone, so it still has something to examine.
  expect_identical(names(status)[status == "passed"], "license_year")
  sat_out <- names(status)[status == "skipped"]
  expect_setequal(
    sat_out,
    setdiff(.check_names(readable), c("description_file", "license_year"))
  )
  for (nm in sat_out) {
    expect_identical(res[[nm]]$skip_reason, "DESCRIPTION could not be read")
    # Each under its own name, as print() and health_report() show it.
    expect_identical(res[[nm]]$message, readable[[nm]]$message)
  }
})

test_that("diagnose_description_issues(): a registered DESCRIPTION check sits out too", {
  withr::defer(unregister_check("house_rule"))
  register_check(
    "house_rule",
    function(path, verbose = TRUE, desc = NULL) {
      checktor_check_result(FALSE, "DESCRIPTION:1", "House rule")
    },
    category = "description",
    severity = "policy"
  )
  res <- diagnose_description_issues(unparseable_pkg(), verbose = FALSE)
  expect_identical(check_status(res$house_rule), "skipped")
  expect_identical(res$house_rule$skip_reason, "DESCRIPTION could not be read")
  expect_identical(failed_checks(res), "description_file")
})

test_that("diagnose_description_issues(): an unfilled usethis Authors@R template is caught", {
  # pcaR2/DESCRIPTION ships person("First", "Last", ...) -- a hard CRAN
  # rejection. checktor 0.1.0 passed it, because it only tested that the field
  # EXISTS. R CMD check says nothing either, for the same reason.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    authors_r = paste0(
      "person(\"First\", \"Last\", , \"maintainer@example.org\", ",
      "role = c(\"aut\", \"cre\", \"cph\"))"
    )
  )
  res <- diagnose_description_issues(pkg, verbose = FALSE)$authors
  expect_false(res$passed)
  # The finding itself: a check that crashed also comes back failed, with a
  # "Diagnostic errored" issue in place of this one.
  expect_identical(
    res$issues,
    "Authors@R: unfilled template placeholder (\"First\", \"Last\")"
  )
})

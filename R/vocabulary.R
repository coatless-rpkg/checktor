# The word lists the DESCRIPTION checks share, kept in one place.
#
# Several checks judge Title and Description against a list of names:
# software_names, language_names and format_names ask for a name in single
# quotes, acronyms lets a known abbreviation go unexplained, and
# description_quoted_quotes recognises a software name that sits in double
# quotes. Each used to carry its own copy, and the copies drifted. They are now
# assembled from the base vectors below, so a name added to one group reaches
# every list that is built from it.
#
# Order matters for the three quoting checks: bare_name_issues() reports in
# vocabulary order, so each derived list keeps the order its check always had.
# A package extends any of the four VOCABULARY lists through
# Config/checktor/<name>, merged in by check_vocab().

# ---- Base vectors -----------------------------------------------------------

# R packages that Writing R Extensions asks to see in single quotes.
VOCAB_R_PACKAGES <- c(
  "ggplot2", "dplyr", "tidyr", "purrr", "tibble", "shiny", "plotly",
  "data.table", "tidyverse"
)

# Further R packages recognised in double quotes but not demanded in single ones.
VOCAB_R_PACKAGES_RECOGNISED <- c("knitr", "rmarkdown", "Rcpp")

# WebAssembly is a W3C format that CRAN asks to see quoted. Its abbreviation and
# the products built on it are recognised when quoted, but not demanded, since a
# bare abbreviation in parentheses is conventional.
VOCAB_WEBASSEMBLY <- "WebAssembly"
VOCAB_WEBASSEMBLY_RECOGNISED <- c("WASM", "webR", "Shinylive")

# General-purpose programming languages. Single-letter names (C, D) and common
# English words (Go, Swift) are left out: they cannot be told from prose.
VOCAB_PROGRAMMING_LANGUAGES <- c(
  "Python", "Java", "JavaScript", "TypeScript", "C#",
  "Perl", "PHP", "Ruby", "Rust", "Julia", "Scala",
  "Kotlin", "Haskell", "Lua"
)

# Statistical and numerical computing environments.
VOCAB_COMPUTING_ENVIRONMENTS <- c(
  "MATLAB", "SAS", "Stata", "SPSS", "Octave", "Mathematica"
)

# Markup, typesetting and data formats, and one query language.
VOCAB_FORMATS <- c(
  "HTML", "CSS", "XML", "JSON", "YAML", "TOML", "Markdown", "LaTeX", "TeX",
  "SQL"
)

# Languages that CRAN packages write quoted and bare about equally.
VOCAB_LANGUAGES_EITHER_WAY <- c("C++", "Fortran", "Tcl")

# Other software recognised in double quotes. "R" and "C" are here and not in
# the language lists, which never ask for them in single quotes.
VOCAB_OTHER_SOFTWARE <- c(
  "R", "C", "Excel", "Docker", "Git", "GitHub", "Quarto", "Pandoc",
  "Stan", "JAGS", "BUGS", "TensorFlow", "PyTorch", "Keras"
)

# Abbreviations common enough to need no expansion. "CMD" is part of the
# literal command `R CMD check` rather than an acronym anyone expands.
VOCAB_COMMON_ABBREVIATIONS <- c(
  "API", "PDF", "URL", "HTTP", "HTTPS", "FTP", "GUI", "CLI", "CRAN", "ID",
  "OS", "TLS", "SSL", "UTF", "ASCII", "CMD"
)

# ---- Derived lists ----------------------------------------------------------

# Each check's built-in list, named by the check and by its Config/checktor field.
VOCABULARY <- list(
  # lab_software_names(): package and software-product names, at policy.
  software_names = c(VOCAB_R_PACKAGES, VOCAB_WEBASSEMBLY),
  # lab_language_names(): programming languages and computing environments.
  language_names = c(VOCAB_PROGRAMMING_LANGUAGES, VOCAB_COMPUTING_ENVIRONMENTS),
  # lab_format_names(): formats and the either-way languages, on request.
  format_names = c(VOCAB_FORMATS, VOCAB_LANGUAGES_EITHER_WAY),
  # lab_acronyms(): the common abbreviations, plus every format name written as
  # an acronym (JSON, HTML, SQL, ...), which CRAN accepts bare.
  acronyms = c(
    VOCAB_COMMON_ABBREVIATIONS,
    VOCAB_FORMATS[grepl("^[A-Z]{2,6}$", VOCAB_FORMATS)]
  )
)

# The Config/checktor fields that extend a vocabulary.
VOCABULARY_FIELDS <- names(VOCABULARY)

# Software and package names that Writing R Extensions requires to be in SINGLE
# quotes, used by lab_description_quoted_quotes() to recognise one in double
# quotes. Deliberately a closed list: guessing from shape would re-introduce the
# false positives on scare-quoted English that check used to produce.
#
# It holds every name lab_software_names() and lab_language_names() look for by
# default. Those read a double-quoted span as a quotation, so a name alone in
# double quotes is reported there or nowhere. The names lab_format_names() covers
# (JSON, HTML, SQL, C++, ...) are not here: CRAN accepts them bare (#16), so
# double quotes around one are not a policy finding either.
SOFTWARE_NAMES <- unique(c(
  VOCABULARY$software_names,
  VOCABULARY$language_names,
  VOCAB_R_PACKAGES_RECOGNISED,
  VOCAB_WEBASSEMBLY_RECOGNISED,
  VOCAB_OTHER_SOFTWARE
))

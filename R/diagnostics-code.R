#' Diagnose Code Health Issues
#'
#' Runs comprehensive diagnostics on R source code to identify common CRAN
#' submission issues and coding best-practice violations.
#'
#' @param path Character. Path to the R package directory. Default: `"."`.
#' @param verbose Logical. Whether to print detailed diagnostic output.
#'   Default: `TRUE`.
#'
#' @return
#' List of named [checktor_check_result()] objects (e.g., `tf_usage`,
#' `seed_setting`) plus a `passed` named logical vector summarizing pass/fail
#' for each sub-check.
#'
#' @details
#' Each source file is parsed once with `parse(keep.source = TRUE)`; checks
#' run XPath queries against the parsed XML representation, so identifiers
#' that appear only inside string literals or comments do not false-positive.
#' Multi-line constructs (`set.seed(\n123\n)`), formula `~` versus path `~`,
#' and scope-aware patterns (an `options()` call guarded by a sibling
#' `on.exit()` in the same function body) are all handled correctly.
#'
#' @seealso [checktor()] for complete package diagnostics
#'
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' code_results <- diagnose_code_issues(pkg, verbose = FALSE)
#' summary(code_results)   # per-category overview
#' issues(code_results)    # the issues found
diagnose_code_issues <- function(path = ".", verbose = TRUE) {
  path <- find_package_root(path)
  begin_category("code", path, verbose)

  if (!dir.exists(file.path(path, "R"))) {
    if (verbose) {
      cli::cli_alert_info("No R/ directory found")
    }
    out <- list(passed = TRUE, message = "No R directory found")
    class(out) <- "checktor_category_result"
    return(out)
  }

  # Parse all R files once and pass the parse to each check that takes a
  # `parsed` argument. The checks come from the table in R/registry.R.
  run_category("code", path, verbose, parsed = read_r_xml(path))
}

# In the xmlparsedata XML, a call `fn(a, b)` is:
#   <expr>                                <- call expr ("outer" expr)
#     <expr>                              <- function-name expr
#       <SYMBOL_FUNCTION_CALL>fn</...>
#     </expr>
#     <OP-LEFT-PAREN>(
#     <expr><SYMBOL>a</SYMBOL></expr>     <- first positional arg
#     <OP-COMMA>,
#     <expr><SYMBOL>b</SYMBOL></expr>
#     <OP-RIGHT-PAREN>)
#   </expr>
# Named args `f(a = 1)` use SYMBOL_SUB/EQ_SUB/expr triples (children of the
# call expr, not wrapped in another expr).
# Helper: from a SYMBOL_FUNCTION_CALL position, navigate to:
#   - the call expr:           `parent::expr/parent::expr`
#   - first positional arg:    `parent::expr/following-sibling::expr[1]`
#   - any named-arg name:      `parent::expr/parent::expr/SYMBOL_SUB`

#' Diagnose `:::` in Package Code
#'
#' Flags a `pkg:::fn()` call in `R/`. The triple colon reaches an object another
#' package does not export, whose behaviour its author is free to change in routine
#' maintenance, so a release elsewhere can break your package without warning.
#'
#' A call into your own package is reported too, since a package almost never needs
#' `:::` for its own objects: everything in the namespace is already visible to the
#' rest of it.
#'
#' @section Source:
#' CRAN sends this back as "Using foo:::f instead of foo::f allows access to
#' unexported objects. This is generally not recommended ... Please omit one
#' colon." `R CMD check` reports it too, under dependencies in R code, so this
#' check is the same finding without waiting for a full check. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @param path Character. Path to package directory.
#' @param verbose Logical. Print diagnostic messages.
#' @param parsed Internal. Pre-parsed source cache; if `NULL`, files are read
#'   from `path` on demand.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @seealso [checktor()], [lab_example_internal_ns()] for the same rule in examples.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/internal_ns_bad.R",
#'                                  show_content = FALSE)
#' lab_internal_ns(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_internal_ns <- function(path = ".", verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("internal_ns")))
  }

  issues <- xpath_per_file(parsed, "//NS_GET_INT", function(file, nodes) {
    # The package and object either side of the operator name the finding.
    pkgs <- xml2::xml_text(xml2::xml_find_first(
      nodes,
      "preceding-sibling::*[1]"
    ))
    objs <- xml2::xml_text(xml2::xml_find_first(
      nodes,
      "following-sibling::*[1]"
    ))
    line_hits(file, nodes, paste0(" (", pkgs, ":::", objs, ")"))
  })

  report_check(
    issues,
    verbose,
    check_label("internal_ns"),
    "No {.code :::} calls in package code",
    "{.code :::} calls found in package code",
    paste("Treatment:", treatments$internal_ns$treatment)
  )
}

# A bare `T` or `F` read as the logical. lab_tf_usage() runs it over R/ and
# lab_example_tf_usage() over examples, vignettes and demos, so the two judge a
# `T` the same way wherever it is.
#
# `T` and `F` in a NON-EVALUATED language context are language tokens, not
# logicals. EL builds plotmath labels with
# `substitute(expression(F[a] - F[b]), ...)`, where F is the cumulative
# distribution function and has nothing to do with FALSE. quote(), bquote(),
# expression() and substitute() all construct language rather than evaluate it.
#
# There is NO guard here for `f(T = 1)`, and there must not be. An argument NAME
# parses as SYMBOL_SUB, not SYMBOL, so `//SYMBOL` never matches it in the first
# place. The guard that used to sit here, excluding a SYMBOL whose parent expr
# follows an EQ_SUB, therefore protected nothing and suppressed the argument
# VALUE instead: `mean(x, na.rm = T)`, which is the single most common bare `T`
# in R, was silently unreportable.
TF_XPATH <- sprintf(
  paste0(
    "//SYMBOL[(text() = 'T' or text() = 'F')",
    "  and not(parent::expr[OP-DOLLAR or OP-AT])",
    "  and not(ancestor::expr[expr[1]/SYMBOL_FUNCTION_CALL[%s]])",
    "]"
  ),
  xp_text_in(c("quote", "bquote", "expression", "substitute", "Quote"))
)

#' Diagnose `T`/`F` Usage in R Code
#'
#' Flags bare `T` / `F` symbols that should be `TRUE` / `FALSE`. Operates on
#' the parsed syntax tree, so `T` inside a string or a comment is not reported,
#' which a plain text search could not tell apart. Named-argument names
#' (`f(T = 1)`) and `$T` / `@T` extractions are excluded.
#'
#' @section Source:
#' No binding rule forbids `T` and `F`, though the CRAN Cookbook keeps a recipe for
#' it under
#' [T/F Instead of TRUE/FALSE](https://contributor.r-project.org/cran-cookbook/code_issues.html#tf-instead-of-truefalse).
#' They are ordinary variables (see `?logical`) that R sets to `TRUE` and `FALSE` at
#' startup but that any code can rebind, so a function reading `T` after something
#' has run `T <- 0` gets the wrong answer. A real risk that no rule makes citable is
#' why this sits at `robustness` tier rather than policy. See `vignette("check-sources", package = "checktor")` for how every
#' check maps to its source.
#'
#' @param path Character. Path to package directory.
#' @param verbose Logical. Print diagnostic messages.
#' @param parsed Internal. Pre-parsed source cache; if `NULL`, files are read
#'   from `path` on demand.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' # show_content defaults to TRUE, so the offending file prints first
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R")
#' lab_tf_usage(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_tf_usage <- function(path = ".", verbose = TRUE, parsed = NULL) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("tf_usage")))
  }

  issues <- c(xpath_lints(parsed, TF_XPATH), parse_error_issues(parsed))

  report_check(
    issues,
    verbose,
    check_label("tf_usage"),
    "No {.code T}/{.code F} usage found",
    "Found {.code T}/{.code F} usage (should use {.code TRUE}/{.code FALSE})"
  )
}

#' Diagnose Hardcoded Credentials in Package Code
#'
#' Flags a secret that looks like an API key, access token, or private key
#' sitting in a string literal in `R/`. `R CMD check` does not scan for leaked
#' credentials, yet a token committed to a package is a security problem: once
#' the package is published to CRAN the secret is public and must be revoked.
#'
#' Only string literals in the parsed sources are examined, so the same text in
#' a comment or a variable name never matches, and the check's own pattern
#' strings never flag themselves.
#'
#' @details
#' Each format is anchored on a provider-specific prefix so ordinary code does
#' not match. The recognised credentials, and the prefix each is keyed on, are:
#'
#' - **Version control and registries**: GitHub tokens (`ghp_`, `gho_`, `ghu_`,
#'   `ghs_`, `ghr_`, and fine-grained `github_pat_`), GitLab tokens (`glpat-`),
#'   npm tokens (`npm_`), and PyPI upload tokens (`pypi-AgEIcHlwaS5vcmc`).
#' - **Cloud providers**: AWS access keys (`AKIA`, `ASIA`, `AROA`, `AIDA`,
#'   `AGPA`, `ABIA`, `ACCA`), Google API keys (`AIza`), Google OAuth client
#'   secrets (`GOCSPX-`), and DigitalOcean tokens (`dop_v1_`).
#' - **AI and ML providers**: OpenAI keys (`sk-`, `sk-proj-`), Anthropic keys
#'   (`sk-ant-`), and Hugging Face tokens (`hf_`).
#' - **Payments**: Stripe secret and restricted keys (`sk_live_`, `sk_test_`,
#'   `rk_live_`, `rk_test_`) and Square tokens (`sq0atp-`, `sq0csp-`, `EAAA`).
#' - **Messaging**: Slack tokens (`xoxb-`, `xoxp-`, ...) and incoming webhooks
#'   (`hooks.slack.com/services/...`), SendGrid keys (`SG.`), and Telegram bot
#'   tokens (`<id>:AA...`).
#' - **Platforms**: Shopify tokens (`shpat_`, `shpss_`, `shpca_`, `shppa_`),
#'   Databricks tokens (`dapi`), and Postman keys (`PMAK-`).
#' - **Generic**: JSON Web Tokens (`eyJ...`) and PEM private-key headers
#'   (`-----BEGIN ... PRIVATE KEY-----`).
#'
#' The prefixes and lengths follow each provider's published token format and
#' the community-maintained gitleaks secret-detection ruleset.
#'
#' @references
#' Provider token formats and the gitleaks ruleset:
#' \url{https://github.com/gitleaks/gitleaks}
#'
#' @inheritParams lab_tf_usage
#' @section Source:
#' No formal rule. A token or key committed to a package is public the moment it
#' reaches CRAN and must be revoked, which is why this sits at `robustness`
#' tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @return [checktor_check_result()] with `passed`, `issues`, `message`.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/credentials_bad.R",
#'                                  show_content = FALSE)
#' lab_hardcoded_credentials(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_hardcoded_credentials <- function(
  path = ".",
  verbose = TRUE,
  parsed = NULL
) {
  path <- find_package_root(path)
  parsed <- code_sources(path, parsed)
  if (length(parsed) == 0L) {
    return(pass_result(check_label("hardcoded_credentials")))
  }

  # Well-known secret shapes only, keyed on a provider prefix so ordinary code
  # does not match. Prefixes and lengths follow each provider's published token
  # format and the gitleaks ruleset. The random-tail quantifiers mean the
  # pattern strings below never match themselves when checktor scans its own R/.
  patterns <- c(
    # version control and package registries
    "GitHub token" = "gh[pousr]_[A-Za-z0-9]{36}",
    "GitHub fine-grained PAT" = "github_pat_[A-Za-z0-9_]{80,}",
    "GitLab token" = "glpat-[A-Za-z0-9_-]{20}",
    "npm token" = "npm_[A-Za-z0-9]{36}",
    "PyPI token" = "pypi-AgEIcHlwaS5vcmc[A-Za-z0-9_-]{50,}",
    # cloud providers
    "AWS access key" = "(?:AKIA|ASIA|AIDA|AROA|AGPA|ABIA|ACCA)[A-Z0-9]{16}",
    "Google API key" = "AIza[A-Za-z0-9_-]{35}",
    "Google OAuth secret" = "GOCSPX-[A-Za-z0-9_-]{28}",
    "DigitalOcean token" = "dop_v1_[a-f0-9]{64}",
    # AI / ML providers
    "OpenAI key" = "sk-proj-[A-Za-z0-9_-]{20,}",
    "OpenAI key (legacy)" = "sk-[A-Za-z0-9]{32,}",
    "Anthropic key" = "sk-ant-[A-Za-z0-9_-]{20,}",
    "Hugging Face token" = "hf_[A-Za-z0-9]{34,}",
    # payments
    "Stripe key" = "(?:sk|rk)_(?:live|test|prod)_[A-Za-z0-9]{10,99}",
    "Square token" = "(?:EAAA|sq0atp-|sq0csp-)[A-Za-z0-9_-]{22,60}",
    # messaging
    "Slack token" = "xox[baprs]-[A-Za-z0-9-]{10,}",
    "Slack webhook" = "https://hooks\\.slack\\.com/(?:services|workflows|triggers)/[A-Za-z0-9+/]{43,56}",
    "SendGrid key" = "SG\\.[A-Za-z0-9_.=-]{66}",
    "Telegram bot token" = "[0-9]{6,16}:AA[A-Za-z0-9_-]{33}",
    # platforms
    "Shopify token" = "shp(?:at|ss|ca|pa)_[a-fA-F0-9]{32}",
    "Databricks token" = "dapi[a-f0-9]{32}",
    "Postman API key" = "PMAK-[a-fA-F0-9]{24}-[a-fA-F0-9]{34}",
    # generic
    "JSON Web Token" = "eyJ[A-Za-z0-9_-]{10,}\\.eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}",
    "private key" = "-----BEGIN [A-Z ]*PRIVATE KEY-----"
  )

  issues <- xpath_per_file(parsed, "//STR_CONST", function(file, nodes) {
    text <- xml2::xml_text(nodes)
    hits <- character(0)
    for (k in seq_along(patterns)) {
      # A left boundary so a prefix like `sk-` or `AKIA` only matches when it
      # starts a token, not when it sits inside a longer word (`disk-...`).
      m <- grepl(
        paste0("(?<![A-Za-z0-9])", patterns[[k]]),
        text,
        perl = TRUE
      )
      if (any(m)) {
        hits <- c(
          hits,
          line_hits(file, nodes[m], paste0(" (", names(patterns)[k], ")"))
        )
      }
    }
    hits
  })
  report_check(
    unique(issues),
    verbose,
    check_label("hardcoded_credentials"),
    "No hardcoded credentials found",
    "Possible hardcoded credential in package code",
    paste("Treatment:", treatments$hardcoded_credentials$treatment)
  )
}

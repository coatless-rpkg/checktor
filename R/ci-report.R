# Machine-readable findings for a build, in whatever shape the forge understands.
#
# A log a human has to read is the weakest form of feedback. Every forge can put a
# finding next to the line that caused it, given the right format, so this renders
# the same results as GitHub workflow commands, GitLab Code Quality, Checkstyle,
# SARIF or Azure logging commands.

# Where a finding's file lives, relative to the package root. Checks report a
# basename, so the directory has to be recovered before a forge can link it.
CI_SEARCH_DIRS <- c(
  "R",
  "man",
  "vignettes",
  "tests/testthat",
  "tests",
  "inst/demo",
  "demo",
  "src",
  "data-raw",
  "."
)

resolve_finding_path <- function(file, path) {
  if (is.na(file) || !nzchar(file)) {
    return(NA_character_)
  }
  for (dir in CI_SEARCH_DIRS) {
    candidate <- if (identical(dir, ".")) file else file.path(dir, file)
    if (file.exists(file.path(path, candidate))) {
      return(candidate)
    }
  }
  # Not found on disk, so report the name as given rather than inventing a path.
  file
}

# Severity words each forge uses, keyed by checktor's tier.
CI_SEVERITY <- list(
  github = c(policy = "error", robustness = "error", opinion = "notice"),
  gitlab = c(policy = "blocker", robustness = "major", opinion = "minor"),
  checkstyle = c(policy = "error", robustness = "warning", opinion = "info"),
  sarif = c(policy = "error", robustness = "warning", opinion = "note"),
  azure = c(policy = "error", robustness = "error", opinion = "warning")
)

ci_severity <- function(tier, format) {
  map <- CI_SEVERITY[[format]]
  out <- unname(map[tier])
  out[is.na(out)] <- unname(map[["robustness"]])
  out
}

escape_ci_data <- function(x) {
  x <- gsub("%", "%25", x, fixed = TRUE)
  x <- gsub("\r", "%0D", x, fixed = TRUE)
  gsub("\n", "%0A", x, fixed = TRUE)
}

escape_ci_property <- function(x) {
  x <- escape_ci_data(x)
  x <- gsub(":", "%3A", x, fixed = TRUE)
  gsub(",", "%2C", x, fixed = TRUE)
}

# Azure logging commands take the same percent escapes, but `;` separates the
# properties and `]` closes the block, so those have to go too. A registered check
# supplies its own message, so this is reachable rather than theoretical.
escape_azure_data <- function(x) {
  escape_ci_data(x)
}
escape_azure_property <- function(x) {
  x <- escape_azure_data(x)
  x <- gsub(";", "%3B", x, fixed = TRUE)
  gsub("]", "%5D", x, fixed = TRUE)
}

# The text format is one finding per element, so an embedded newline would turn
# one finding into two lines and break anything reading it line by line.
flatten_lines <- function(x) {
  trimws(gsub("[[:space:]]*[\r\n]+[[:space:]]*", " ", x))
}

# The forge this build is running on, from the variables each one sets.
detect_ci <- function() {
  if (nzchar(Sys.getenv("GITHUB_ACTIONS"))) {
    # Gitea and Forgejo Actions set this too, and speak the same commands.
    return("github")
  }
  if (nzchar(Sys.getenv("GITLAB_CI"))) {
    return("gitlab")
  }
  if (nzchar(Sys.getenv("TF_BUILD"))) {
    return("azure")
  }
  if (nzchar(Sys.getenv("JENKINS_URL"))) {
    return("checkstyle")
  }
  "text"
}

github_annotations <- function(df) {
  sprintf(
    "::%s file=%s,line=%s,title=%s::%s",
    ci_severity(df$severity, "github"),
    escape_ci_property(df$path),
    ifelse(is.na(df$line), 1L, df$line),
    escape_ci_property(paste0("checktor: ", df$check)),
    escape_ci_data(df$detail)
  )
}

azure_annotations <- function(df) {
  sprintf(
    "##vso[task.logissue type=%s;sourcepath=%s;linenumber=%s;code=%s]%s",
    ci_severity(df$severity, "azure"),
    escape_azure_property(df$path),
    ifelse(is.na(df$line), 1L, df$line),
    escape_azure_property(df$check),
    escape_azure_data(df$detail)
  )
}

# GitLab reads Code Quality reports in the CodeClimate shape, and shows them on
# the merge request diff.
gitlab_report <- function(df) {
  entries <- vapply(
    seq_len(nrow(df)),
    function(i) {
      paste0(
        "  {\n",
        '    "description": ', json_string(df$detail[i]), ",\n",
        '    "check_name": ', json_string(df$check[i]), ",\n",
        '    "fingerprint": ',
        json_string(fingerprint(df$check[i], df$path[i], df$line[i], df$detail[i])),
        ",\n",
        '    "severity": ', json_string(ci_severity(df$severity[i], "gitlab")), ",\n",
        '    "location": {\n',
        '      "path": ', json_string(df$path[i]), ",\n",
        '      "lines": { "begin": ', ifelse(is.na(df$line[i]), 1L, df$line[i]), " }\n",
        "    }\n",
        "  }"
      )
    },
    character(1)
  )
  c("[", paste(entries, collapse = ",\n"), "]")
}

# Checkstyle XML is read by Jenkins, reviewdog and most code-review bots, which
# is what makes it the format to reach for on a forge with no native one.
checkstyle_report <- function(df) {
  out <- c('<?xml version="1.0" encoding="UTF-8"?>', '<checkstyle version="8.0">')
  for (p in unique(df$path)) {
    rows <- df[df$path == p, , drop = FALSE]
    out <- c(out, sprintf('  <file name="%s">', escape_xml(p)))
    out <- c(
      out,
      sprintf(
        '    <error line="%s" severity="%s" message="%s" source="checktor.%s"/>',
        ifelse(is.na(rows$line), 1L, rows$line),
        ci_severity(rows$severity, "checkstyle"),
        escape_xml(rows$detail),
        escape_xml(rows$check)
      )
    )
    out <- c(out, "  </file>")
  }
  c(out, "</checkstyle>")
}

# SARIF is the interchange format GitHub code scanning and Azure both ingest.
sarif_report <- function(df) {
  rules <- unique(df$check)
  rule_json <- paste(
    vapply(
      rules,
      function(r) {
        paste0(
          "        { \"id\": ", json_string(r),
          ", \"shortDescription\": { \"text\": ", json_string(r), " } }"
        )
      },
      character(1)
    ),
    collapse = ",\n"
  )
  result_json <- paste(
    vapply(
      seq_len(nrow(df)),
      function(i) {
        paste0(
          "        {\n",
          '          "ruleId": ', json_string(df$check[i]), ",\n",
          '          "level": ', json_string(ci_severity(df$severity[i], "sarif")), ",\n",
          '          "message": { "text": ', json_string(df$detail[i]), " },\n",
          '          "locations": [ { "physicalLocation": {\n',
          '            "artifactLocation": { "uri": ', json_string(df$path[i]), " },\n",
          '            "region": { "startLine": ',
          ifelse(is.na(df$line[i]), 1L, df$line[i]), " }\n",
          "          } } ]\n",
          "        }"
        )
      },
      character(1)
    ),
    collapse = ",\n"
  )
  c(
    "{",
    '  "$schema": "https://json.schemastore.org/sarif-2.1.0.json",',
    '  "version": "2.1.0",',
    '  "runs": [ {',
    '    "tool": { "driver": {',
    '      "name": "checktor",',
    paste0(
      '      "version": ',
      json_string(as.character(utils::packageVersion("checktor"))),
      ","
    ),
    '      "informationUri": "https://r-pkg.thecoatlessprofessor.com/checktor/",',
    '      "rules": [',
    rule_json,
    "      ]",
    "    } },",
    '    "results": [',
    result_json,
    "    ]",
    "  } ]",
    "}"
  )
}

json_string <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  x <- gsub("\n", "\\n", x, fixed = TRUE)
  x <- gsub("\r", "\\r", x, fixed = TRUE)
  x <- gsub("\t", "\\t", x, fixed = TRUE)
  paste0("\"", x, "\"")
}

escape_xml <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  gsub("'", "&apos;", x, fixed = TRUE)
}

# A stable identity for a finding, so GitLab can tell a new one from a repeat.
# No hashing dependency is needed: the same finding has to produce the same
# string, and a positional sum over its bytes does that.
fingerprint <- function(check, path, line, detail) {
  key <- paste(check, path, line, detail, sep = "|")
  bytes <- as.integer(charToRaw(key))
  # The sums run past integer range, so reduce in double and coerce afterwards.
  positional <- as.integer(sum(bytes * seq_along(bytes)) %% 2147483647)
  spread <- as.integer((nchar(key) * 2654435761) %% 2147483647)
  sprintf("%08x%08x", positional, spread)
}

#' Report Findings in the Format Your CI Understands
#'
#' Renders a [checktor()] result as machine-readable findings, so a build puts each
#' one next to the line that caused it instead of leaving it in a log for someone
#' to read. The format defaults to whichever forge the build is running on.
#'
#' @details
#' Each forge reads a different shape, and `format` picks it:
#'
#' - `"github"` writes workflow commands to standard output, which GitHub Actions
#'   turns into annotations on the pull request diff. Gitea and Forgejo Actions
#'   read the same commands.
#' - `"gitlab"` writes a Code Quality report, which GitLab shows on the merge
#'   request diff. Name the file in `artifacts:reports:codequality:`.
#' - `"checkstyle"` writes Checkstyle XML, which Jenkins, reviewdog and most
#'   review bots read. This is the one to reach for on a forge with no format of
#'   its own.
#' - `"sarif"` writes SARIF 2.1.0, which GitHub code scanning and Azure ingest.
#' - `"azure"` writes Azure Pipelines logging commands.
#' - `"text"` writes one plain line per finding, for a build with no forge at all.
#'
#' Findings carry a file name rather than a path, so the path is recovered by
#' looking for the file under `R/`, `man/`, `vignettes/` and the other places a
#' package keeps code. A finding with no location at all, such as a `DESCRIPTION`
#' field problem, is reported against `DESCRIPTION` so it still appears.
#'
#' @param results A `checktor_results` object. Defaults to running [checktor()] on
#'   `path` quietly, so a build can call this on its own.
#' @param format Character. One of `"auto"`, `"github"`, `"gitlab"`,
#'   `"checkstyle"`, `"sarif"`, `"azure"` or `"text"`. `"auto"` reads the
#'   environment variables each forge sets.
#' @param file Character. Where to write. Defaults to standard output for the
#'   comment-style formats and to a conventional file name for the report styles.
#' @param severity Character. Which tiers to report. Defaults to every tier, since
#'   an annotation is information rather than a verdict.
#' @param skipped Logical. Report the checks that did not run. Defaults to `TRUE`,
#'   so a green pipeline never implies a check that never happened. Named once in
#'   aggregate rather than one annotation per check.
#' @param path Character. The package to examine when `results` is not supplied.
#'
#' @return Invisibly, the character vector written.
#' @seealso [checkup()] for the pass or fail gate, [health_report()] for a report
#'   a person reads.
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
#'                                  show_content = FALSE)
#' results <- checktor(pkg, verbose = FALSE, progress = FALSE)
#'
#' # What a GitHub Actions job would emit
#' writeLines(head(ci_report(results, format = "github", file = NULL), 3))
ci_report <- function(
  results = NULL,
  format = c("auto", "github", "gitlab", "checkstyle", "sarif", "azure", "text"),
  file = NULL,
  severity = SEVERITY_LEVELS,
  skipped = TRUE,
  path = "."
) {
  format <- match.arg(format)
  # A mistyped tier in a workflow file would otherwise read as a clean package.
  severity <- match.arg(severity, SEVERITY_LEVELS, several.ok = TRUE)
  path <- find_package_root(path)
  if (is.null(results)) {
    results <- checktor(path, verbose = FALSE, progress = FALSE)
  }
  if (!inherits(results, "checktor_results")) {
    cli::cli_abort("{.arg results} must be a {.cls checktor_results} object.")
  }
  if (identical(format, "auto")) {
    format <- detect_ci()
  }

  found <- issues(results)
  found <- found[found$severity %in% severity, , drop = FALSE]

  pkg_path <- results$metadata$package_path
  if (is.null(pkg_path) || !dir.exists(pkg_path)) {
    pkg_path <- path
  }
  df <- data.frame(
    check = found$check,
    severity = found$severity,
    line = found$line,
    # A finding with no file still belongs somewhere a reader can open.
    path = vapply(
      seq_len(nrow(found)),
      function(i) {
        if (is.na(found$file[i])) {
          "DESCRIPTION"
        } else {
          resolve_finding_path(found$file[i], pkg_path)
        }
      },
      character(1)
    ),
    # paste0() recycles a zero-length argument up to the literal, so an empty
    # result set has to say so explicitly rather than yield one blank row.
    detail = if (nrow(found) == 0L) {
      character(0)
    } else {
      paste0(found$message, ": ", found$location)
    },
    stringsAsFactors = FALSE
  )

  out <- switch(
    format,
    github = github_annotations(df),
    azure = azure_annotations(df),
    gitlab = gitlab_report(df),
    checkstyle = checkstyle_report(df),
    sarif = sarif_report(df),
    text = paste0(
      df$path, ":", ifelse(is.na(df$line), 1L, df$line), " [", df$severity, "] ",
      df$check, " - ", flatten_lines(df$detail)
    )
  )

  # A check that did not run must not read as one that ran and passed. The log
  # styles can say so in line; the artifact styles stay clean documents, so the
  # note goes to the job log instead of becoming a triageable alert.
  did_not_run <- if (isTRUE(skipped)) results$metadata$skipped_checks else NULL
  if (length(did_not_run) > 0L) {
    if (format %in% c("github", "azure", "text")) {
      out <- c(out, skipped_note(did_not_run, format))
    } else {
      cli::cli_alert_info(
        "{length(did_not_run)} check{?s} did not run: {.field {did_not_run}}"
      )
    }
  }

  # The comment styles have to reach the log; the report styles are artifacts.
  default_file <- switch(
    format,
    gitlab = "gl-code-quality-report.json",
    checkstyle = "checktor-checkstyle.xml",
    sarif = "checktor.sarif",
    NULL
  )
  target <- if (missing(file)) default_file else file
  # An artifact is written even with nothing to report, so a forge can clear the
  # findings a previous run left on the same branch.
  if (!is.null(target)) {
    writeLines(out, target)
  } else if (format %in% c("github", "azure", "text") && length(out) > 0L) {
    writeLines(out)
  }
  invisible(out)
}

# One aggregate line, not one per check: GitHub caps annotations at 10 per level
# per step, and a check that did not run should not crowd out one that found
# something.
skipped_note <- function(checks, format) {
  detail <- paste0(
    length(checks), " check", if (length(checks) == 1L) "" else "s",
    " did not run: ", paste(checks, collapse = ", ")
  )
  switch(
    format,
    github = sprintf(
      "::notice title=%s::%s",
      escape_ci_property("checktor: skipped"),
      escape_ci_data(detail)
    ),
    azure = sprintf(
      "##vso[task.logissue type=warning;code=skipped]%s",
      escape_azure_data(detail)
    ),
    paste0("skipped: ", flatten_lines(detail))
  )
}

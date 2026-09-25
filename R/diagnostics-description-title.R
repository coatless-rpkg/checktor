# Checks on the Title field.

# Title should not start with "A ", "An ", or "The ".
#' Diagnose Title Starting With an Article
#'
#' Flags a `Title` beginning with `A`, `An`, or `The`.
#'
#' @section Source:
#' No rule. This was a mis-transplant of a real CRAN rule and is kept
#' callable but off by default. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/title_starts_with_article_bad.txt",
#'                                  show_content = FALSE)
#' lab_title_starts_with_article(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_title_starts_with_article <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  title <- desc_value(desc, "Title")
  if (is.null(title)) {
    return(pass_result(check_label("title_starts_with_article")))
  }
  issues <- if (grepl("^(A|An|The)\\s+", title, perl = TRUE)) {
    "Title starts with an article (A/An/The)"
  } else {
    character(0)
  }
  report_check(
    issues,
    verbose,
    check_label("title_starts_with_article"),
    "Title does not start with an article",
    "Title starts with an article",
    treatment = paste(
      "Treatment:",
      treatments$title_starts_with_article$treatment
    ),
    level = "warning"
  )
}

# Title should not include redundant phrases like "for R", "A Toolkit for",
# "Tools for". CRAN explicitly flags these.
#' Diagnose Redundant Phrases in Title
#'
#' Flags a `Title` carrying a phrase CRAN asks you to drop, such as "for R".
#'
#' @section Source:
#' No formal rule. Phrases like "R package to" are redundant in a
#' `Title`, a convention which is why this sits at `opinion` tier. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/title_redundant_phrases_bad.txt",
#'                                  show_content = FALSE)
#' lab_title_redundant_phrases(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_title_redundant_phrases <- function(
  path = ".",
  verbose = TRUE,
  desc = NULL
) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  title <- desc_value(desc, "Title")
  if (is.null(title)) {
    return(pass_result(check_label("title_redundant_phrases")))
  }
  patterns <- c(
    "\\bfor R\\b",
    "\\bA Toolkit for\\b",
    "\\bTools for\\b"
  )
  issues <- character(0)
  for (pat in patterns) {
    if (grepl(pat, title, perl = TRUE)) {
      issues <- c(
        issues,
        paste0(
          "Title contains redundant phrase: '",
          gsub("\\\\b", "", pat),
          "'"
        )
      )
    }
  }
  report_check(
    issues,
    verbose,
    check_label("title_redundant_phrases"),
    "Title is free of redundant phrases",
    "Title contains redundant phrases that CRAN flags",
    treatment = paste(
      "Treatment:",
      treatments$title_redundant_phrases$treatment
    ),
    level = "warning"
  )
}

# A Title longer than 65 characters risks being cut off in a package listing.
#' Diagnose Title Length
#'
#' Flags a `Title` longer than 65 characters.
#'
#' @section Source:
#' *Writing R Extensions* §1.1.1 notes that some package listings may truncate the
#' title to 65 characters. That is a display width rather than a limit, so a title
#' of exactly 65 characters still shows in full and only a longer one loses its
#' tail. Nothing rejects a long title, which is why this sits at `opinion` tier.
#' See `vignette("check-sources", package = "checktor")` for how every check maps
#' to its source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/title_length_bad.txt",
#'                                  show_content = FALSE)
#' lab_title_length(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_title_length <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  title <- desc_value(desc, "Title")
  if (is.null(title)) {
    return(pass_result(check_label("title_length")))
  }
  flat <- trimws(gsub("\\s+", " ", title))
  n <- nchar(flat)
  # 65 is the width a listing may truncate to, so 65 characters still show in
  # full and only a longer title loses its tail.
  issues <- if (n > 65L) {
    over <- n - 65L
    paste0(
      "Title is ", n, " characters, so a listing that truncates at 65 would cut ",
      "the last ", over, if (over == 1L) " character" else " characters"
    )
  } else {
    character(0)
  }
  report_check(
    issues,
    verbose,
    check_label("title_length"),
    "Title fits the 65 characters a listing may truncate to",
    "Title is longer than a listing may show",
    treatment = paste("Treatment:", treatments$title_length$treatment),
    level = "warning",
    nchar = n
  )
}

#' Diagnose a Title That Repeats the Package Name
#'
#' Flags a `Title` that is just the package name, or that opens with the name
#' followed by a colon, as in `toypkg: Fit Simple Models`. Package listings
#' already show the name beside the `Title`, so it reads twice.
#'
#' R's incoming check also NOTEs a `Title` that opens with the name followed
#' by a space, but that form is left alone here: when the name is an ordinary
#' word, as in survival's "Survival Analysis", CRAN accepts it routinely, and
#' over a hundred packages on CRAN carry one. R drops the NOTE for an update
#' whose `Title` is unchanged since the version on CRAN, which checktor cannot
#' see offline, so an older package may pass CRAN with a finding here.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says of the `Title`: "Do not repeat the package
#' name: it is often used prefixed by the name." The
#' [incoming check](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' NOTEs "The Title field is just the package name: provide a real title." and
#' "The Title field starts with the package name.". See
#' `vignette("check-sources", package = "checktor")` for how every check maps to
#' its source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/title_package_name_bad.txt",
#'                                  show_content = FALSE)
#' lab_title_package_name(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_title_package_name <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  title <- desc_value(desc, "Title")
  pkg <- desc_value(desc, "Package")
  issues <- character(0)
  if (!is.null(title) && !is.null(pkg)) {
    # As R reads them: the Title on one line, the name with its dots escaped.
    title <- trimws(gsub("[\n\t]", " ", title))
    pkg <- trimws(pkg)
    if (tolower(title) == tolower(pkg)) {
      issues <- "Title is just the package name: provide a real title"
    } else if (
      grepl(
        paste0("^", escape_regex(pkg), "[[:space:]]*:"),
        title,
        ignore.case = TRUE
      )
    ) {
      issues <- paste0(
        "Title starts with the package name: ", title,
        " (R drops this NOTE for an update whose Title is unchanged)"
      )
    }
  }
  report_check(
    issues,
    verbose,
    check_label("title_package_name"),
    "Title does not repeat the package name",
    "Title repeats the package name",
    treatment = paste("Treatment:", treatments$title_package_name$treatment)
  )
}

# ---- Title / Description / License checks -------------------------------------

# Title case, delegated to R's own engine.
#
# The previous implementation walked the Title word by word with its own list of
# small words and stripped punctuation before comparing, which mangled real titles:
# "w/Preference" became "wPreference" and was reported as needing capitalisation,
# and a single-quoted package name like 'shiny' was flagged too.
#
# tools::toTitleCase() IS the function behind CRAN's own "Title field should be in
# title case" NOTE, and R's check restores single-quoted spans before comparing --
# which is precisely why R does not flag 'shiny' and we did. Use it, and restore
# the quoted spans the same way.
#' Diagnose Title Case in DESCRIPTION
#'
#' Flags a `Title` that is not in title case, delegating to [tools::toTitleCase()], which restores single-quoted spans so `'shiny'` keeps its own capitalisation.
#'
#' @section Source:
#' [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file),
#' under "The DESCRIPTION file", says the `Title` "should use title case"; the
#' [`--as-cran`](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-packages)
#' incoming check flags one that does not. See
#' `vignette("check-sources", package = "checktor")` for how every check maps to its
#' source.
#' @inheritParams lab_description_fields
#'
#' @inherit lab_description_fields return seealso
#' @export
#' @examples
#' pkg <- example_diagnose_scenario("description_examples/title_case_bad.txt",
#'                                  show_content = FALSE)
#' lab_title_case(pkg, verbose = FALSE)$issues
#' unlink(pkg, recursive = TRUE)
lab_title_case <- function(path = ".", verbose = TRUE, desc = NULL) {
  path <- find_package_root(path)
  desc <- resolve_description(path, desc)
  title <- desc_value(desc, "Title")
  if (is.null(title)) {
    return(pass_result(check_label("title_case")))
  }

  proposed <- tools::toTitleCase(title)
  # Software names in single quotes keep their own capitalisation ('shiny', not
  # 'Shiny'). R does this by putting the original quoted spans back afterwards.
  # Substitute literally: a package name can contain regex metacharacters, and
  # escaping them by hand is a bug farm.
  quoted <- regmatches(title, gregexpr("'[^']*'", title))[[1L]]
  for (q in quoted) {
    proposed <- sub(tools::toTitleCase(q), q, proposed, fixed = TRUE)
  }

  issues <- character(0)
  if (!identical(proposed, title)) {
    issues <- paste0(
      "Title is not in title case. R would write it as: ",
      proposed
    )
  }
  report_check(
    issues,
    verbose,
    check_label("title_case"),
    "Title is in title case",
    "Title is not in title case",
    treatment = paste("Treatment:", treatments$title_case$treatment),
    level = "warning"
  )
}

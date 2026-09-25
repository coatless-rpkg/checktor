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

test_that("lab_authors(): flags the package.skeleton() template", {
  # What utils::package.skeleton() writes (R 4.6.1). R's incoming check tests
  # only the Author and Maintainer fields older skeletons wrote, so it is silent.
  skeleton <- paste0(
    "c(person(\"Givenname\", \"Familyname\", role = c(\"aut\", \"cre\"),\n",
    "    email = \"yourfault@somewhere.net\"),\n",
    "  person(\"Anotherone\", \"Ifany\", role = \"ctb\"))"
  )
  res <- lab_authors(make_temp_dir(),
    verbose = FALSE,
    desc = c(`Authors@R` = skeleton)
  )
  expect_identical(
    res$issues,
    paste(
      "Authors@R: unfilled template placeholder (\"Givenname\", \"Familyname\",",
      "\"Anotherone\", \"Ifany\", \"yourfault@somewhere.net\")"
    )
  )
})

test_that("lab_authors(): reads the Authors@R strings, not its comments", {
  # CGGP's field carries the old skeleton's Maintainer line as an R comment.
  d <- c(`Authors@R` = paste0(
    "c(person(\"Collin\", \"Erickson\", email = \"ce@example.org\",\n",
    "  role = c(\"aut\", \"cre\"))) # Maintainer: Who to complain to ",
    "<yourfault@somewhere.net>"
  ))
  res <- lab_authors(make_temp_dir(), verbose = FALSE, desc = d)
  expect_identical(res$issues, character(0))
})

test_that("lab_authors(): leaves the old skeleton's Maintainer to lab_description_placeholders()", {
  # Older package.skeleton() versions wrote Author and Maintainer fields, whose
  # text R's incoming check and lab_description_placeholders() already report.
  d <- c(
    `Authors@R` = "person(\"Ann\", \"Smith\", email = \"ann@example.org\", role = c(\"aut\", \"cre\"))",
    Maintainer = "Who to complain to <yourfault@somewhere.net>"
  )
  res <- lab_authors(make_temp_dir(), verbose = FALSE, desc = d)
  expect_identical(res$issues, character(0))
  expect_length(
    lab_description_placeholders(make_temp_dir(), verbose = FALSE, desc = d)$issues,
    1L
  )
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

# Test refused_call_issue() ----

test_that("refused_call_issue(): names every refused call in one issue", {
  expect_identical(refused_call_issue(character(0)), character(0))
  expect_match(
    refused_call_issue("utils::person(...)"),
    "Authors@R calls utils::person(...), which",
    fixed = TRUE
  )
  expect_match(
    refused_call_issue(c("a()", "b()", "c()", "a()")),
    "calls a(), b() and c(), which",
    fixed = TRUE
  )
})

# Test person_issues() ----

test_that("person_issues(): flags a person with no name or role, and no maintainer", {
  expect_identical(person_issues(NULL), character(0))
  expect_identical(
    person_issues(utils::person("Ann", "Bee", role = c("aut", "cre"))),
    character(0)
  )
  p <- c(utils::person(role = "aut", email = "a@b.org"), utils::person("Cy"))
  expect_identical(
    person_issues(p),
    c(
      "Authors@R has a person entry with no name",
      "Authors@R has a person entry with no role",
      "Authors@R declares no maintainer (a person with role \"cre\")"
    )
  )
})

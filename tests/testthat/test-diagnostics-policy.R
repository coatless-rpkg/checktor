# A test that names a CRAN package reproduces a false positive or a missed
# finding from that package's real sources, so a regression fails here first.

# Test lab_browser_calls() ----

test_that("lab_browser_calls(): flags browser() and not the word in strings", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "x <- 'browser() reminder'",
      "f <- function() browser()"
    )
  )
  res <- lab_browser_calls(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 1L)
})

# Test lab_system_calls() ----

test_that("lab_system_calls(): flags system()/system2()/shell()", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() system('ls')",
      "g <- function() system2('ls')",
      "h <- function() shell('dir')"
    )
  )
  res <- lab_system_calls(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_gte(length(res$issues), 3L)
})

test_that("lab_system_calls(): obj$system() and obj$browser() are method calls too", {
  # The same defect in undesirable_function_check(), which backs system_calls,
  # browser_calls, library_in_pkg and the install checks.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "run <- function(api) {",
      "  api$system('ls')",
      "  api$browser()",
      "  invisible(NULL)",
      "}"
    )
  )
  expect_true(lab_system_calls(pkg, verbose = FALSE)$passed)
  expect_true(lab_browser_calls(pkg, verbose = FALSE)$passed)
})

test_that("lab_system_calls(): a platform-branched system() call is the platform check", {
  # The check's own remediation asks for a platform check. beepr and cli branch on
  # the OS and were reported anyway.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "play <- function(f) {",
      "  if (Sys.info()[['sysname']] == 'Windows') {",
      "    shell(paste('start', f))",
      "  } else {",
      "    system(paste('afplay', f))",
      "  }",
      "}"
    )
  )
  expect_true(lab_system_calls(pkg, verbose = FALSE)$passed)
})

# Test lab_file_operations() ----

test_that("lab_file_operations(): does NOT double-match saveRDS as save()", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x) saveRDS(x, '/tmp/foo.rds')"
    )
  )
  res <- lab_file_operations(pkg, verbose = FALSE)
  # Should flag saveRDS once. With the bug, the issues list contained both
  # 'saveRDS()' and 'save()' for the same line.
  expect_equal(sum(grepl("saveRDS", res$issues)), 1L)
  expect_false(any(grepl(":\\d+ \\(save\\(\\)\\)", res$issues)))
})

test_that("lab_file_operations(): exempts tempfile/tempdir targets", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function() {",
      "  path <- tempfile()",
      "  saveRDS(1, path)",
      "  unlink(path)",
      "}"
    )
  )
  res <- lab_file_operations(pkg, verbose = FALSE)
  expect_true(res$passed)
})

test_that("lab_file_operations(): flags writes outside tempdir", {
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() write.csv(mtcars, '/etc/foo.csv')")
  res <- lab_file_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
})

test_that("lab_file_operations(): exempts a write to a caller-supplied path", {
  # CRAN's rule is about writing without permission, and a path the caller
  # passed in is permission.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "report <- function(results, file) {",
      "  writeLines(results, file)",
      "}"
    )
  )
  expect_true(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_file_operations(): flags a formal that defaults into the user's filespace", {
  # The destination is a formal, but calling report() with no arguments writes
  # to $HOME, so the exemption must not apply.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      'report <- function(results, file = "~/report.txt") {',
      "  writeLines(results, file)",
      "}"
    )
  )
  expect_false(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_file_operations(): does not exempt on the strength of a non-destination arg", {
  # `x` is a formal, but it is the DATA argument. The destination is a literal
  # home path and must still be flagged.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "bad <- function(x) {",
      '  writeLines(x, "~/data.csv")',
      "}"
    )
  )
  expect_false(lab_file_operations(pkg, verbose = FALSE)$passed)
})

# Only a provable destination is a violation.

test_that("lab_file_operations(): flags a hardcoded literal destination", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x) writeLines(x, 'output.csv')", # writes to the CWD
      "g <- function(x) saveRDS(x, '~/cache.rds')" # writes to $HOME
    )
  )
  res <- lab_file_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)
})

test_that("lab_file_operations(): allows a caller-supplied or computed path", {
  # CRAN's rule is about writing WITHOUT PERMISSION. A path the caller passed in
  # is permission, and a computed path proves nothing either way. surveydown's
  # `writeLines(template, env_file)` builds env_file from a user-given directory.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x, file) writeLines(x, file)",
      "g <- function(x, path) {",
      "  env_file <- file.path(path, '.env')",
      "  writeLines(x, env_file)",
      "}",
      "h <- function(x) saveRDS(x, tempfile())"
    )
  )
  expect_true(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_file_operations(): catches a formal that defaults into $HOME", {
  # The hole the literal rule would otherwise leave: the destination IS a symbol,
  # but calling with no argument writes to the user's home.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = "f <- function(x, path = '~/data.csv') writeLines(x, path)"
  )
  expect_false(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_file_operations(): reads file.create()'s destination as its FIRST arg", {
  # write.csv(x, file) puts the path second; file.create(path) puts it first.
  # Assuming "always the second argument" read file.create()'s path as content.
  pkg <- make_temp_dir()
  write_pkg(pkg, r_code = "f <- function() file.create('~/marker.txt')")
  expect_false(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_file_operations(): judges a path by its ROOT, not any literal", {
  # `file.path(temp_pkg, "NEWS.md")` is rooted at a variable, so the basename
  # literal proves nothing. checktor's own example_diagnose_scenario() does this,
  # and an earlier version of the rule flagged it.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "scaffold <- function() {",
      "  temp_pkg <- tempfile()",
      "  writeLines(c('# news'), file.path(temp_pkg, 'NEWS.md'))",
      "}",
      "under_dir <- function(dir, x) writeLines(x, file.path(dir, 'out.csv'))"
    )
  )
  expect_true(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_file_operations(): flags a path whose ROOT is a literal", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function(x) writeLines(x, file.path('~', 'out.csv'))", # $HOME
      "b <- function(x) writeLines(x, file.path('output', 'out.csv'))" # working dir
    )
  )
  res <- lab_file_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)
})

test_that("lab_file_operations(): a caller-supplied write destination is permission", {
  # surveydown/R/db.R and config.R. CRAN forbids writing to the user's filespace
  # WITHOUT PERMISSION; a path the caller passed in is permission.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "create_env <- function(path, template) {",
      "  env_file <- file.path(path, '.env')",
      "  writeLines(template, env_file)",
      "}",
      "",
      "write_settings <- function(paths, content) {",
      "  writeLines(content, con = paths$target_settings)",
      "}"
    )
  )
  expect_true(lab_file_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_file_operations(): a hardcoded write destination is still caught", {
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "f <- function(x) writeLines(x, 'output.csv')",
      "g <- function(x, path = '~/data.csv') writeLines(x, path)"
    )
  )
  res <- lab_file_operations(pkg, verbose = FALSE)
  expect_false(res$passed)
  expect_equal(length(res$issues), 2L)
})

test_that("lab_file_operations(): finds the destination a pipe hands on", {
  # The piped value is the call's first argument, so the literal in the call is
  # the destination. A piped call that writes where the caller says, or into
  # tempdir(), is still permission.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function(x) x |> writeLines('~/out.txt')",
      "b <- function(d) d %>% write.csv('out.csv')",
      "c <- function(x) x |> saveRDS(file.path(Sys.getenv('HOME'), 'x.rds'))",
      "d <- function(x, path) x |> writeLines(path)",
      "e <- function(x) x %>% writeLines(., tempfile())"
    )
  )
  expect_identical(
    lab_file_operations(pkg, verbose = FALSE)$issues,
    c("test.R:1 (writeLines())", "test.R:2 (write.csv())", "test.R:3 (saveRDS())")
  )
})

test_that("lab_file_operations(): a named argument does not move the destination", {
  # Counting a named argument as a position read the data as the destination.
  # `to =` is file.copy()'s destination, and naming `from =` leaves the path as
  # the first unnamed argument. The last line copies FROM a literal path.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "a <- function(x) file.copy(to = '~/b', from = x)",
      "b <- function(x) file.rename(to = 'b', from = x)",
      "c <- function(x) writeLines(sep = '\\n', x, '~/o.txt')",
      "d <- function(x) write.csv(row.names = FALSE, x, 'o.csv')",
      "e <- function(p) ggplot2::ggsave(plot = p, '~/p.png')",
      "f <- function(x) file.copy(from = x, '/srv/b')",
      "g <- function(dest) file.copy(from = '/etc/hosts', dest)"
    )
  )
  expect_identical(
    lab_file_operations(pkg, verbose = FALSE)$issues,
    c(
      "test.R:1 (file.copy())", "test.R:2 (file.rename())",
      "test.R:3 (writeLines())", "test.R:4 (write.csv())",
      "test.R:5 (ggsave())", "test.R:6 (file.copy())"
    )
  )
})

test_that("lab_file_operations(): a method named like a writer is not a write", {
  # shinyNextUI builds its icons with htmltools' `tags$svg()`, which is not
  # grDevices::svg(), and a named `compression =` is not a path either.
  pkg <- make_temp_dir()
  write_pkg(
    pkg,
    r_code = c(
      "icon <- function() tags$svg(width = 24, tags$g(fill = 'currentColor'))",
      "save_h5 <- function(adata, path) adata$write(path, compression = 'gzip')"
    )
  )
  expect_identical(lab_file_operations(pkg, verbose = FALSE)$issues, character(0))
})

# Test lab_network_operations() ----

test_that("lab_network_operations(): flags an unwrapped download.file in Rd", {
  pkg <- rd_pkg("download.file('https://example.com/x', 'x')")
  expect_equal(
    lab_network_operations(pkg, verbose = FALSE)$issues,
    "f.Rd (unwrapped network call in \\examples)"
  )
})

test_that("lab_network_operations(): reads an example with an #ifdef inside a call", {
  # The #ifdef condition is not R. Kept, it ran into the vector around it, the
  # example did not parse, and the download after it went unread.
  pkg <- rd_pkg(c(
    "urls <- c(",
    "#ifdef windows",
    "  'https://example.com/w',",
    "#endif",
    "  'https://example.com/u')",
    "download.file(urls[1], 'x')"
  ))
  expect_equal(
    lab_network_operations(pkg, verbose = FALSE)$issues,
    "f.Rd (unwrapped network call in \\examples)"
  )
})

test_that("lab_network_operations(): prints the treatment's literal braces", {
  pkg <- rd_pkg("download.file('https://example.com/x', 'x')")
  expect_snapshot(res <- lab_network_operations(pkg))
})

test_that("lab_network_operations(): accepts \\dontrun-wrapped network code", {
  pkg <- rd_pkg(c("\\dontrun{", "download.file('https://example.com/x', 'x')", "}"))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): accepts \\donttest-wrapped network code", {
  pkg <- rd_pkg(c("\\donttest{", "httr::GET('https://example.com')", "}"))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a call named in a comment is not a call", {
  # The example text used to be grepped, so a pointer to download.file() in a
  # comment was reported as a download.
  pkg <- rd_pkg(c(
    "# Fetch the file yourself with download.file() or curl::curl_download()",
    "x <- read_local(path)"
  ))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a call named in a string is not a call", {
  pkg <- rd_pkg("message('See httr::GET() and download.file() for remote files')")
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a call in an Rd comment is not a call", {
  # An Rd `%` comment never reaches the example R runs.
  pkg <- rd_pkg(c("% download.file('https://example.com/x', 'x')", "f()"))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): accepts each network availability guard", {
  # chiOpenData guards with `interactive() && curl::has_internet()`, and the
  # guard's own `curl::` was what got it reported.
  for (guard in c(
    "interactive()",
    "rlang::is_interactive()",
    "curl::has_internet()",
    "has_internet()",
    "pingr::is_online()",
    "httr2::is_online()",
    "capabilities('libcurl')",
    "isTRUE(capabilities('http/ftp'))",
    "interactive() && curl::has_internet()",
    "FALSE"
  )) {
    pkg <- rd_pkg(c(
      paste0("if (", guard, ") {"),
      "  download.file('https://example.com/x', tempfile())",
      "}"
    ))
    expect_true(lab_network_operations(pkg, verbose = FALSE)$passed, label = guard)
  }
})

test_that("lab_network_operations(): accepts an @examplesIf guard", {
  pkg <- rd_pkg(c(
    "\\dontshow{if (curl::has_internet()) (if (getRversion() >= \"3.4\") withAutoprint else force)(\\{ # examplesIf}",
    "resp <- httr::GET('https://example.com')",
    "\\dontshow{\\}) # examplesIf}"
  ))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a probe kept in a variable or short-circuited is a guard", {
  pkg <- rd_pkg(c(
    "online <- curl::has_internet()",
    "if (online) download.file('https://example.com/x', tempfile())",
    "curl::has_internet() && httr::GET('https://example.com')$status_code == 200"
  ))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): the else of a negated guard is guarded", {
  pkg <- rd_pkg(c(
    "if (!curl::has_internet()) {",
    "  message('offline')",
    "} else {",
    "  download.file('https://example.com/x', tempfile())",
    "}"
  ))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a negated guard is no excuse", {
  pkg <- rd_pkg(c(
    "if (!curl::has_internet()) message('offline')",
    "download.file('https://example.com/x', tempfile())"
  ))
  expect_false(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a guard around one call excuses only it", {
  pkg <- rd_pkg(c(
    "if (curl::has_internet()) httr::GET('https://example.com')",
    "download.file('https://example.com/x', tempfile())"
  ))
  expect_false(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a guard in a comment or string is no excuse", {
  pkg <- rd_pkg(c(
    "# needs curl::has_internet()",
    "message('if (interactive()) only')",
    "download.file('https://example.com/x', tempfile())"
  ))
  expect_false(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a condition that holds offline is no guard", {
  for (guard in c(
    "capabilities('X11')",
    "interactive() || TRUE",
    "!curl::has_internet() || ready()",
    "session$interactive()"
  )) {
    pkg <- rd_pkg(c(
      paste0("if (", guard, ") {"),
      "  download.file('https://example.com/x', tempfile())",
      "}"
    ))
    expect_false(lab_network_operations(pkg, verbose = FALSE)$passed, label = guard)
  }
})

test_that("lab_network_operations(): the else of a guarded conjunction is not guarded", {
  # The else runs whenever either side is false, which the negated side alone does
  # not confine to a session that is online.
  pkg <- rd_pkg(c(
    "if (!curl::has_internet() && ready()) message('offline') else",
    "  download.file('https://example.com/x', tempfile())"
  ))
  expect_false(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a helper from a network package is not a request", {
  # httr2's req_body.Rd builds a multipart body with curl::form_file(), which reads
  # a local file. Only the calls that perform a request reach the network.
  pkg <- rd_pkg(c(
    "path <- tempfile()",
    "body <- curl::form_file(path)",
    "h <- curl::new_handle()",
    "hdr <- httr::add_headers(a = 1)",
    "req <- httr2::request('https://example.com')",
    "ok <- curl::has_internet()"
  ))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): recognises the requests each package makes", {
  for (call in c(
    "download.file(u, f)",
    "utils::download.file(u, f)",
    "curl_download(u, f)",
    "curl::curl_fetch_memory(u)",
    "con <- curl::curl(u)",
    "httr::GET(u)",
    "httr::POST(u, body = b)",
    "resp <- httr2::req_perform(req)",
    "RCurl::getURL(u)"
  )) {
    pkg <- rd_pkg(call)
    expect_false(lab_network_operations(pkg, verbose = FALSE)$passed, label = call)
  }
})

test_that("lab_network_operations(): recognises curl's DNS lookup and mail", {
  for (call in c(
    "curl::nslookup('r-project.org')",
    "curl::send_mail(sender, recipients, message, smtp_server = server)"
  )) {
    pkg <- rd_pkg(call)
    expect_equal(
      lab_network_operations(pkg, verbose = FALSE)$issues,
      "f.Rd (unwrapped network call in \\examples)",
      label = call
    )
  }
})

test_that("lab_network_operations(): a request function handed on as a value is a request", {
  # lapply(), Map(), do.call() and purrr's mappers call the function they are
  # given, so naming it there makes the request as surely as calling it.
  for (use in c(
    "lapply(urls, download.file, destfile = f)",
    "res <- lapply(urls, httr::GET)",
    "sapply(urls, curl::curl_fetch_memory)",
    "vapply(urls, curl_download, character(1), destfile = f)",
    "Map(download.file, urls, files)",
    "mapply(curl_download, urls, files)",
    "purrr::map(reqs, httr2::req_perform)",
    "purrr::walk2(urls, files, download.file)",
    "do.call(download.file, list(u, f))",
    "urls |> lapply(httr::GET)",
    "lapply(urls, FUN = download.file)",
    "parallel::mclapply(urls, download.file)",
    "purrr::imap(urls, curl::curl_download)",
    "furrr::future_map(urls, httr::GET)",
    "urls \\%>\\% download.file",
    "do.call('download.file', list(u, f))",
    "do.call(what = \"curl_download\", args = list(u, f))",
    "do.call(args = list(u, f), what = 'curl_download')",
    "fetch <- match.fun('download.file')"
  )) {
    pkg <- rd_pkg(use)
    expect_equal(
      lab_network_operations(pkg, verbose = FALSE)$issues,
      "f.Rd (unwrapped network call in \\examples)",
      label = use
    )
  }
})

test_that("lab_network_operations(): a request handed on as a value is guarded like a call", {
  pkg <- rd_pkg(c(
    "if (curl::has_internet()) lapply(urls, download.file, destfile = f)",
    "\\donttest{",
    "res <- lapply(urls, httr::GET)",
    "}"
  ))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): asking about a request function is not a request", {
  # Only a function that calls what it is handed makes the request.
  pkg <- rd_pkg(c(
    "args(download.file)",
    "formals(httr::GET)",
    "?download.file",
    "client$download.file",
    "class(download.file)",
    "debugonce(download.file)",
    "example(download.file)",
    "fit <- y ~ download.file",
    "do.call(rbind, list('download.file'))",
    "message('download.file')"
  ))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): defining a request function is not a request", {
  # A mock that stands in for the download, so the example never fetches.
  pkg <- rd_pkg(c(
    "download.file <- function(...) invisible(0)",
    "curl_download = function(url, destfile) destfile",
    "function(...) NULL -> multi_download"
  ))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)

  pkg <- script_pkg(
    c("```{r}", "download.file <- function(...) invisible(0)", "```"),
    dir = "vignettes",
    file = "v.Rmd"
  )
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): names a request made through a string", {
  pkg <- script_pkg(
    c("```{r}", "do.call('download.file', list(u, f))", "```"),
    dir = "vignettes",
    file = "intro.Rmd"
  )
  expect_equal(
    lab_network_operations(pkg, verbose = FALSE)$issues,
    "intro.Rmd: unguarded network access in a code chunk (download.file)"
  )
})

test_that("lab_network_operations(): a vignette that hands a request on as a value is flagged", {
  pkg <- script_pkg(
    c("```{r}", "invisible(Map(download.file, urls, files))", "```"),
    dir = "vignettes",
    file = "intro.Rmd"
  )
  expect_equal(
    lab_network_operations(pkg, verbose = FALSE)$issues,
    "intro.Rmd: unguarded network access in a code chunk (download.file)"
  )
})

test_that("lab_network_operations(): a comment inside a guard leaves it a guard", {
  # The comment is a node of its own in the parse tree, between the operands.
  pkg <- rd_pkg(c(
    "if (interactive() && # someone is there to see a failure",
    "    curl::has_internet()) {",
    "  download.file('https://example.com/x', tempfile())",
    "}",
    "if (!( # probe first",
    "  curl::has_internet())) message('offline') else httr::GET(u)"
  ))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a guard read through a wrapper is a guard", {
  for (guard in c(
    "suppressWarnings(curl::has_internet())",
    "suppressMessages(pingr::is_online(), classes = 'message')",
    "invisible(capabilities('libcurl'))",
    "isTRUE(suppressWarnings(curl::has_internet()))",
    "suppressWarnings(expr = curl::has_internet())",
    "suppressMessages(classes = 'message', pingr::is_online())"
  )) {
    pkg <- rd_pkg(c(
      paste0("if (", guard, ") {"),
      "  download.file('https://example.com/x', tempfile())",
      "}"
    ))
    expect_true(lab_network_operations(pkg, verbose = FALSE)$passed, label = guard)
  }
})

test_that("lab_network_operations(): a probe assigned inside another function is no guard", {
  # `online` is local to check(), so the `if` at top level reads nothing it set.
  pkg <- rd_pkg(c(
    "check <- function() {",
    "  online <- curl::has_internet()",
    "}",
    "if (online) download.file('https://example.com/x', tempfile())"
  ))
  expect_equal(
    lab_network_operations(pkg, verbose = FALSE)$issues,
    "f.Rd (unwrapped network call in \\examples)"
  )
})

test_that("lab_network_operations(): a probe assigned on one branch only is no guard", {
  # When `quick` is FALSE, `online` is still TRUE and the download runs.
  pkg <- rd_pkg(c(
    "online <- TRUE",
    "if (quick) online <- curl::has_internet()",
    "if (online) download.file('https://example.com/x', tempfile())"
  ))
  expect_equal(
    lab_network_operations(pkg, verbose = FALSE)$issues,
    "f.Rd (unwrapped network call in \\examples)"
  )
})

test_that("lab_network_operations(): a probe assigned in a condition feeds a later test", {
  # The condition runs whenever the `if` does, so `on` always holds the probe.
  pkg <- rd_pkg(c(
    "if ((on <- curl::has_internet())) {",
    "  if (on) download.file(u, f)",
    "}",
    "if (!(online <- curl::has_internet())) message('offline')",
    "if (online) httr::GET(u)"
  ))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a probe assigned in the same function is a guard", {
  pkg <- rd_pkg(c(
    "fetch <- function(u) {",
    "  online <- curl::has_internet()",
    "  if (online) download.file(u, tempfile())",
    "}"
  ))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a method of the same name is not the call", {
  pkg <- rd_pkg(c("client$download.file(u)", "obj$curl_download(u)"))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): \\dontshow{} code runs, so it is read", {
  # R CMD check runs \dontshow{} code; it is hidden only from the rendered help.
  pkg <- rd_pkg(c("\\dontshow{", "download.file('https://example.com/x', tempfile())", "}"))
  expect_false(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a block that will not parse hides no call", {
  # A \dontrun{} block can hold a `<your key>` placeholder, which stops the whole
  # example parsing. The runnable call outside it must still be read.
  pkg <- rd_pkg(c(
    "\\dontrun{",
    "fetch(key = <your key>)",
    "}",
    "download.file('https://example.com/x', tempfile())"
  ))
  expect_false(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): reports each Rd file once", {
  pkg <- rd_pkg(c("download.file(u, f)", "httr::GET(u)"))
  expect_length(lab_network_operations(pkg, verbose = FALSE)$issues, 1L)
})

test_that("lab_network_operations(): skips a build-ignored pkgdown article", {
  # usethis::use_article() writes vignettes/articles/ and excludes the directory
  # in .Rbuildignore, so nothing under it reaches CRAN.
  pkg <- script_pkg(
    c("```{r}", "download.file('https://example.com', 'f')", "```"),
    dir = file.path("vignettes", "articles"),
    file = "extra.Rmd"
  )
  expect_equal(
    lab_network_operations(pkg, verbose = FALSE)$issues,
    "extra.Rmd: unguarded network access in a code chunk (download.file)"
  )

  writeLines("^vignettes/articles$", file.path(pkg, ".Rbuildignore"))
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a vignette's PROSE is not code", {
  # curl's intro.Rmd calls itself "a drop-in replacement for `download.file` in
  # r-base" and was reported for saying so. Only the R chunks are code.
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "vignettes"), showWarnings = FALSE)
  writeLines(
    c(
      "---",
      "title: Intro",
      "---",
      "",
      "This package is a drop-in replacement for `download.file` in r-base,",
      "and a modern alternative to httr::GET and RCurl.",
      "",
      "```{r}",
      "x <- 1 + 1",
      "```"
    ),
    file.path(pkg, "vignettes", "intro.Rmd")
  )
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

test_that("lab_network_operations(): a vignette chunk that REALLY downloads is still flagged", {
  pkg <- make_temp_dir()
  write_pkg(pkg)
  dir.create(file.path(pkg, "vignettes"), showWarnings = FALSE)
  writeLines(
    c(
      "---",
      "title: Intro",
      "---",
      "",
      "```{r}",
      "download.file('https://example.com/x.csv', tmp)",
      "```"
    ),
    file.path(pkg, "vignettes", "intro.Rmd")
  )
  expect_equal(
    lab_network_operations(pkg, verbose = FALSE)$issues,
    "intro.Rmd: unguarded network access in a code chunk (download.file)"
  )
})

test_that("lab_network_operations(): skips a vignette chunk set to eval: false", {
  # Quarto and knitr read chunk options from `#|` comments too, and a chunk that
  # never runs cannot reach the network.
  pkg <- script_pkg(
    c(
      "---", "title: Intro", "---", "",
      "```{r}", "#| eval: false", "download.file('https://example.com/x.csv', tmp)", "```"
    ),
    "vignettes", "intro.qmd"
  )
  expect_equal(lab_network_operations(pkg, verbose = FALSE)$issues, character(0))
})

test_that("lab_network_operations(): a vignette's probe for the network is not a request", {
  # A setup chunk that makes every chunk conditional on a connection is the guard,
  # and its own `curl::` used to be reported as the network access.
  pkg <- script_pkg(
    c(
      "```{r setup}",
      "knitr::opts_chunk$set(eval = curl::has_internet())",
      "```",
      "",
      "```{r}",
      "download.file('https://example.com/x.csv', tmp)",
      "```"
    ),
    dir = "vignettes",
    file = "intro.Rmd"
  )
  expect_true(lab_network_operations(pkg, verbose = FALSE)$passed)
})

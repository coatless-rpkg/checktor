# lab_spelling() calls utils::aspell(), whose result depends on whether a
# spell-check backend is installed. That would make the count- and severity-based
# tests differ from machine to machine, so the suite runs with spelling off. The
# dedicated spelling test opts back in and skips when no backend is present.
options(checktor.spelling = FALSE)

# lab_url_liveness() fetches every package URL over the network, which is
# non-deterministic (and slow). It is opt-in and off by default; pin it off so a
# stray global option never turns the suite flaky.
options(checktor.url_check = FALSE)

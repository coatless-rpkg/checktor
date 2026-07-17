# Accepted spellings for R CMD check --as-cran and checktor's own spelling check.
# Add a word: saveRDS(c(readRDS(".aspell/words.rds"), "NewTerm"), ".aspell/words.rds")
Rd_files <- vignettes <- R_files <- description <-
  list(encoding = "UTF-8", dictionaries = c("en_stats", "words"))

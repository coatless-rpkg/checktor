# Diagnose a Missing cran-comments.md File

A `cran-comments.md` file carries the submission notes CRAN reviewers
read (test environments, R CMD check results, downstream-dependency
notes). Its absence is flagged so it can be added before submission.

## Usage

``` r
diagnose_cran_comments_file(path, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to package directory

- verbose:

  Logical. Print diagnostic messages

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Details

This check is opt-in: it is **not** part of the default
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
/
[`diagnose_general_issues()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/diagnose_general_issues.md)
run, because a `cran-comments.md` is a workflow convention rather than a
CRAN requirement. Call it directly to use it.

## Examples

``` r
pkg_path <- example_diagnose_scenario("code_examples/tf_usage_bad.R",
                                      show_content = FALSE)
file.remove(file.path(pkg_path, "cran-comments.md"))  # failing case
#> [1] TRUE
issues(diagnose_cran_comments_file(pkg_path, verbose = FALSE))
#>   file line                                       location
#> 1 <NA>   NA No cran-comments.md file with submission notes
#>                    message
#> 1 cran-comments file check
```

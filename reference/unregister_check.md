# Remove Registered Checks

Drops checks added with
[`register_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/register_check.md).
With no argument, clears the whole registry.

## Usage

``` r
unregister_check(name = NULL)
```

## Arguments

- name:

  Character vector of check names to remove, or `NULL` (the default) to
  remove every registered check.

## Value

Invisibly, `NULL`.

## See also

[`register_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/register_check.md),
[`registered_checks()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/registered_checks.md)

## Examples

``` r
register_check("tmp", function(path, verbose = TRUE) {
  checktor_check_result(TRUE, character(0), "noop")
})
unregister_check("tmp")
registered_checks()
#> [1] check    category severity
#> <0 rows> (or 0-length row.names)
```

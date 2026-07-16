# List Registered Checks

Reports the checks currently added with
[`register_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/register_check.md).

## Usage

``` r
registered_checks()
```

## Value

A data frame with columns `check`, `category`, and `severity`, one row
per registered check (zero rows if none are registered).

## See also

[`register_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/register_check.md),
[`unregister_check()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/unregister_check.md)

## Examples

``` r
registered_checks()
#> [1] check    category severity
#> <0 rows> (or 0-length row.names)
```

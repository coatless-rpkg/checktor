# Print Method for checktor_check_result Objects

Print Method for checktor_check_result Objects

## Usage

``` r
# S3 method for class 'checktor_check_result'
print(x, ...)
```

## Arguments

- x:

  A checktor_check_result object

- ...:

  Additional arguments (unused)

## Value

Returns `x` invisibly

## Examples

``` r
res <- checktor_check_result(FALSE, c("foo.R:3", "bar.R:9"), "T/F usage")
print(res)
#> ✖ T/F usage: FAILED
#> Issues found:
#> • foo.R:3
#> • bar.R:9
```

# Configure Package Doctor Defaults

Sets session-wide defaults for
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
behavior. Subsequent calls to
[`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md)
(and helpers that delegate to it) pick up these defaults via
[`getOption()`](https://rdrr.io/r/base/options.html).

## Usage

``` r
configure_doctor(verbose_default = TRUE, progress_default = TRUE, color = TRUE)
```

## Arguments

- verbose_default:

  Logical. Default verbosity for
  [`checktor()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor.md).

- progress_default:

  Logical. Default progress-bar setting.

- color:

  Logical. Whether `cli` should emit ANSI color. Sets `cli.num_colors`
  via [`options()`](https://rdrr.io/r/base/options.html).

## Value

Invisibly returns the previous values of the changed options, so the
call can be reversed with `options(.)`.

## Examples

``` r
# Save defaults so we can restore them after the example runs
old <- options(checktor.verbose = NULL, checktor.progress = NULL)
on.exit(options(old), add = TRUE)

configure_doctor(verbose_default = FALSE)
#> ✔ Package doctor configuration updated
getOption("checktor.verbose")
#> [1] FALSE
```

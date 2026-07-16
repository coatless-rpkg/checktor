# Diagnose Hardcoded Credentials in Package Code

Flags a secret that looks like an API key, access token, or private key
sitting in a string literal in `R/`. `R CMD check` does not scan for
leaked credentials, yet a token committed to a package is a security
problem: once the package is published to CRAN the secret is public and
must be revoked.

## Usage

``` r
diagnose_hardcoded_credentials(path, verbose = TRUE, parsed = NULL)
```

## Arguments

- path:

  Character. Path to package directory.

- verbose:

  Logical. Print diagnostic messages.

- parsed:

  Internal. Pre-parsed source cache; if `NULL`, files are read from
  `path` on demand.

## Value

[`checktor_check_result()`](https://r-pkg.thecoatlessprofessor.com/checktor/reference/checktor_check_result.md)
with `passed`, `issues`, `message`.

## Details

Only string literals in the parsed sources are examined, so the same
text in a comment or a variable name never matches, and the check's own
pattern strings never flag themselves.

Each format is anchored on a provider-specific prefix so ordinary code
does not match. The recognised credentials, and the prefix each is keyed
on, are:

- **Version control and registries**: GitHub tokens (`ghp_`, `gho_`,
  `ghu_`, `ghs_`, `ghr_`, and fine-grained `github_pat_`), GitLab tokens
  (`glpat-`), npm tokens (`npm_`), and PyPI upload tokens
  (`pypi-AgEIcHlwaS5vcmc`).

- **Cloud providers**: AWS access keys (`AKIA`, `ASIA`, `AROA`, `AIDA`,
  `AGPA`, `ABIA`, `ACCA`), Google API keys (`AIza`), Google OAuth client
  secrets (`GOCSPX-`), and DigitalOcean tokens (`dop_v1_`).

- **AI and ML providers**: OpenAI keys (`sk-`, `sk-proj-`), Anthropic
  keys (`sk-ant-`), and Hugging Face tokens (`hf_`).

- **Payments**: Stripe secret and restricted keys (`sk_live_`,
  `sk_test_`, `rk_live_`, `rk_test_`) and Square tokens (`sq0atp-`,
  `sq0csp-`, `EAAA`).

- **Messaging**: Slack tokens (`xoxb-`, `xoxp-`, ...) and incoming
  webhooks (`hooks.slack.com/services/...`), SendGrid keys (`SG.`), and
  Telegram bot tokens (`<id>:AA...`).

- **Platforms**: Shopify tokens (`shpat_`, `shpss_`, `shpca_`,
  `shppa_`), Databricks tokens (`dapi`), and Postman keys (`PMAK-`).

- **Generic**: JSON Web Tokens (`eyJ...`) and PEM private-key headers
  (`-----BEGIN ... PRIVATE KEY-----`).

The prefixes and lengths follow each provider's published token format
and the community-maintained gitleaks secret-detection ruleset.

## References

Provider token formats and the gitleaks ruleset:
<https://github.com/gitleaks/gitleaks>

## Examples

``` r
pkg <- example_diagnose_scenario("code_examples/credentials_bad.R",
                                 show_content = FALSE)
diagnose_hardcoded_credentials(pkg, verbose = FALSE)$passed
#> [1] FALSE
```

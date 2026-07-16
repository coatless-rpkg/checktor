# Example file showing hardcoded credentials in package code.
# The values below are fabricated for demonstration and are not real secrets:
# AKIAIOSFODNN7EXAMPLE is AWS's own documentation example key, and the PEM line
# is a bare header with no key material.

#' Connect to the API
#' @return A configured client
connect_api <- function() {
  # Issue: an AWS access key committed straight into the source
  aws_key <- "AKIAIOSFODNN7EXAMPLE"
  # Issue: a private key pasted in alongside it
  pem_header <- "-----BEGIN RSA PRIVATE KEY-----"
  list(aws_key = aws_key, pem_header = pem_header)
}

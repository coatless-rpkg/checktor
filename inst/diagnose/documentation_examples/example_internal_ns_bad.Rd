\name{trim_values}
\alias{trim_values}
\title{Trim Values}
\description{
A function whose example reaches an unexported object with a triple colon.
}
\usage{
trim_values(x)
}
\arguments{
\item{x}{A numeric vector.}
}
\value{
A numeric vector the length of \code{x}.
}
\examples{
x <- c(1, 5, 100)
examplepackage:::trim_helper(x)
trim_values(x)
}

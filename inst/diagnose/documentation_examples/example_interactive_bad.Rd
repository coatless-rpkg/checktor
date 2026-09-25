\name{pick_values}
\alias{pick_values}
\title{Pick Values}
\description{
A function whose example asks for input inside \code{\\donttest{}} rather than behind \code{if (interactive())}.
}
\usage{
pick_values(x)
}
\arguments{
\item{x}{A numeric vector.}
}
\value{
A numeric vector the length of \code{x}.
}
\examples{
\donttest{
choice <- menu(c("mean", "median"))
pick_values(1:10)
}
}

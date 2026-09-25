\name{save_values}
\alias{save_values}
\title{Save Values}
\description{
A function whose example writes into the working directory, not \code{tempdir()}.
}
\usage{
save_values(x)
}
\arguments{
\item{x}{A numeric vector.}
}
\value{
A numeric vector the length of \code{x}.
}
\examples{
x <- 1:10
write.csv(data.frame(x = x), "values.csv")
}

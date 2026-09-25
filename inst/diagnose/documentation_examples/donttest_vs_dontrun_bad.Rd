\name{smooth_slowly}
\alias{smooth_slowly}
\title{Smooth Slowly}
\description{
A function whose example is only slow, yet hides in \code{\\dontrun{}}.
}
\usage{
smooth_slowly(x)
}
\arguments{
\item{x}{A numeric vector.}
}
\value{
A numeric vector the length of \code{x}.
}
\examples{
\dontrun{
# long-running: takes minutes on a series this long
smooth_slowly(cumsum(sin(seq_len(1e7))))
}
}

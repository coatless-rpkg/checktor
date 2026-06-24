\name{download_data}
\alias{download_data}
\title{Download Data}
\description{
Downloads data from a remote server.
}
\usage{
download_data(url)
}
\arguments{
  \item{url}{URL to download from}
}
\value{
Downloaded data as a data frame.
}
\examples{
# Issue: Network operation without \\dontrun
data <- download_data("https://example.com/data.csv")
result <- httr::GET("https://api.example.com/endpoint")
}

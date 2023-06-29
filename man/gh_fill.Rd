\name{gh_fill}
\alias{gh_fill}

\title{
  Fill geohash(s)
}
\description{
  Fill geohash prefix with members
}
\usage{
gh_fill(geohashes, precision)
}
\arguments{
  \item{geohashes}{ Character vector of input geohashes. They must all be of same precision. }
  \item{precision}{ Positive \code{integer} scalar controlling the 'zoom level' -- how many characters should be used in the output. }
}
\details{
  Note that each increas of \code{precision} by 1 results in an output 32 times larger.
}
\value{
  \code{character} vector of geohashes corresponding to the input.
}
\references{
  \url{http://geohash.org/} ( Gustavo Niemeyer's original geohash service )
}
\author{
  Garnet vanWeerden
}

\examples{
# Single geohash input
gh_fill("9w", 6L)

# Vector of geohashes of same length. 
gh_fill(c("9w", "9x", "9y"), 6L)
}

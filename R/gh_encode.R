#' Geohash encoding
#'
#' Convert latitude/longitude coordinates into geohash-encoded strings
#'
#' @param latitude `numeric` vector of input latitude (y) coordinates. Must be in `[-90, 90)`.
#' @param longitude `numeric` vector of input longitude (x) coordinates. Should be in `[-180, 180)`.
#' @param precision Positive `integer` controlling the 'zoom level' -- how many characters should be used in the
#'   output. Either a single value applied to all coordinates, or a vector the same length as `latitude`/`longitude`
#'   giving a per-coordinate precision.
#'
#' @details
#' `precision` is limited to at most 25. This level of precision encodes locations on the globe at a nanometer scale
#' and is already more than enough for basically all applications.
#'
#' Longitudes outside `[-180, 180)` will be wrapped appropriately to the standard longitude grid.
#'
#' @return
#' `character` vector of geohashes corresponding to the input. `NA` in gives `NA` out.
#'
#' @references
#' <http://geohash.org/> ( Gustavo Niemeyer's original geohash service )
#'
#' @author
#' Michael Chirico
#'
#' @examples
#' # scalar input is treated as a vector
#' gh_encode(2.345, 6.789)
#'
#' # geohashes are left-closed, right-open, so boundary coordinates are
#' #   associated to the east and/or north
#' gh_encode(0, 0)
#'
#' # precision can vary by coordinate
#' gh_encode(c(2.345, 0), c(6.789, 0), precision = c(4L, 8L))
#'
#' @export
gh_encode = function(latitude, longitude, precision = 6L) {
  n = length(latitude)
  np = length(precision)
  if (np != 1L && np != n)
    stop('precision must be length 1 or the same length as the coordinates (got ', np, ' for ', n, ' coordinates)')
  if (anyNA(precision) || any(precision < 1L))
    stop('Invalid precision. Precision is measured in number of characters, must be at least 1.')
  if (any(precision > .global$GH_MAX_PRECISION)) {
    warning('Precision is limited to ', .global$GH_MAX_PRECISION, ' characters; truncating')
    precision = pmin(precision, .global$GH_MAX_PRECISION)
  }

  .Call(Cgh_encode, latitude, longitude, as.integer(precision))
}

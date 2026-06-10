#' Geohash decoding
#'
#' Convert geohash-encoded strings into latitude/longitude coordinates
#'
#' @param geohashes `character` or `factor` vector or of input geohashes. There's no need for all inputs to be of the same precision.
#' @param include_delta `logical`; should the cell half-width delta be included in the output?
#' @param coord_loc `character` specifying where in the cell points should be mapped to; cell centroid is mapped by default; case-insensitive. See Details.
#'
#' @details
#' `coord_loc` can be the cell's center (`'c'` or `'centroid'`), or it can be any of the 8 corners (e.g. `'s'`/`'south'` for the midpoint of the southern boundary of the cell, or `'ne'`/`'northeast'` for the upper-right corner.
#'
#' For `factor` input, decoding will be done on the levels for efficiency.
#'
#' @return
#' `list` with the following entries:
#'
#' \item{latitude}{ `numeric` vector of latitudes (y-coordinates) corresponding to the input `geohashes`, with within-cell position dictated by `coord_loc` }
#' \item{longitude}{ `numeric` vector of longitudes (x-coordinates) corresponding to the input `geohashes`, with within-cell position dictated by `coord_loc` }
#' \item{delta_latitude}{ `numeric` vector of cell half-widths in the y direction (only included if `include_delta` is `TRUE` }
#' \item{delta_longitude}{ `numeric` vector of cell half-widths in the x direction (only included if `include_delta` is `TRUE` }
#'
#' @references
#' <http://geohash.org/> ( Gustavo Niemeyer's original geohash service )
#'
#' @author
#' Michael Chirico
#'
#' @examples
#' # Riddle me this
#' gh_decode('stq4s8c')
#'
#' # Cell half-widths might be convenient to include for downstream analysis
#' gh_decode('tjmd79', include_delta = TRUE)
#'
#' @export
gh_decode = function(geohashes, include_delta = FALSE, coord_loc = 'c') {
  if (is.factor(geohashes)) {
    return(lapply(
      gh_decode(levels(geohashes), include_delta, coord_loc),
      function(z) z[geohashes]
    ))
  }
  if (length(coord_loc) > 1L)
    stop("Please provide only one value for 'coord_loc'")
  coord_loc = switch(
    tolower(coord_loc),
    'southwest' = , 'sw' = 0L,
    'south' = , 's' = 1L,
    'southeast' = , 'se' = 2L,
    'west' = , 'w' = 3L,
    'centroid' = , 'center' = , 'middle' = , 'c' = 4L,
    'east' = , 'e' = 5L,
    'northwest' = , 'nw' = 6L,
    'north' = , 'n' = 7L,
    'northeast' = , 'ne' = 8L,
    stop("Unrecognized coordinate location; please use 'c' for centroid or a cardinal direction; see ?gh_decode")
  )
  .Call(Cgh_decode, geohashes, include_delta, coord_loc)
}

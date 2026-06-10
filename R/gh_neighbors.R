#' Geohash neighborhoods
#'
#' Return the geohashes adjacent to input geohashes
#'
#' @param geohashes `character` vector of input geohashes. There's no need for all inputs to be of the same precision.
#' @param self Should the input also be returned as a list element? Convenient for one-line usage / piping
#'
#' @details
#' North/south-pole adjacent geohashes are missing three of their neighbors; these will be returned as `NA_character_`.
#'
#' @return
#' `list` with `character` vector entries in the direction relative to the input geohashes indicated by their name
#' (e.g. `value$south` gives all of the *southern* neighbors of the input `geohashes`).
#'
#' The order is `self` (if `self = TRUE`), `southwest`, `south`, `southeast`, `west`, `east`, `northwest`, `north`,
#' `northeast` (reflecting an easterly, then northerly traversal of the neighborhod).
#'
#' @references
#' <http://geohash.org/> ( Gustavo Niemeyer's original geohash service )
#'
#' @author
#' Michael Chirico
#'
#' @examples
#' gh_neighbors('d7q8u4')
#'
#' @aliases gh_neighbors gh_neighbours
#' @export
gh_neighbors = function(geohashes, self = TRUE) {
  .Call(Cgh_neighbors, geohashes, self)
}

#' @rdname gh_neighbors
#' @export
gh_neighbours = gh_neighbors

#' @export
gh_neighbors = function(geohashes, self = TRUE) {
  .Call(Cgh_neighbors, geohashes, self)
}

#' @export
gh_neighbours = gh_neighbors

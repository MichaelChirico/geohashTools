gh_neighbors = gh_neighbours = function(geohashes, self = TRUE) {
  .Call(Cgh_neighbors, geohashes, self)
}

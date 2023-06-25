# get cell half-widths for a given geohash precision

gh_delta = function(precision) {
  if (length(precision) > 1L) stop('One precision at a time, please.')
  45.0/2.0^((5.0*precision + c(-1.0, 1.0) * (precision %% 2.0))/2.0 - 1:2)
}

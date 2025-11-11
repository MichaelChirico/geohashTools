# get cell half-widths for a given geohash precision

gh_delta = function(precision) {
  if (length(precision) > 1L) stop('One precision at a time, please.')
  if (!is.numeric(precision) || precision < 0L || precision > 25L) {
    stop('precision must be a single integer between 0 and 25, inclusive.')
  }
  45.0/2.0^((5.0*precision + c(-1.0, 1.0) * (precision %% 2.0))/2.0 - 1:2)
}

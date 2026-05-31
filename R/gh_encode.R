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

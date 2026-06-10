#' Geohash utilities
#'
#' Various common functions that arise when working often with geohashes
#'
#' @param precision `integer` precision level desired.
#'
#' @note
#' *Caveat coder*: not much is done in the way of consistency checking since this is a convenience function.
#' So e.g. real-valued "precision"s will give results.
#'
#' @return
#' Length-2 `numeric` vector; the first element is the *latitude* (y-coordinate) half-width at the input
#' `precision`, the second element is the *longitude* (x-coordinate).
#'
#' @references
#' <http://geohash.org/> ( Gustavo Niemeyer's original geohash service )
#'
#' @author
#' Michael Chirico
#'
#' @examples
#' gh_delta(6)
#'
#' @name utils
#' @export
gh_delta = function(precision) {
  if (length(precision) > 1L) stop('One precision at a time, please.')
  45.0/2.0^((5.0*precision + c(-1.0, 1.0) * (precision %% 2.0))/2.0 - 1:2)
}

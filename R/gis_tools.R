# nocov start
check_suggested = function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop('This function requires an installation of ', pkg, "; install.packages('", pkg, "') to proceed.")
  }
}
# nocov end

gh_to_sfc = function(geohashes) {
  gh = tolower(geohashes)
  gh_xy = gh_decode(gh, include_delta = TRUE)
  polys = lapply(seq_along(gh), function(ii) {
    coords = cbind(
      gh_xy$longitude[ii] + c(-1.0, -1.0, 1.0, 1.0, -1.0) * gh_xy$delta_longitude[ii],
      gh_xy$latitude[ii] + c(-1.0, 1.0, 1.0, -1.0, -1.0) * gh_xy$delta_latitude[ii]
    )
    sf::st_polygon(list(coords))
  })
  sf::st_sfc(polys, crs = 4326L)
}

#' Helpers for interfacing geohashes with sf objects
#'
#' These functions smooth the gateway between working with geohashes and geospatial information built for the
#' major geospatial package in R, [sf::sf].
#'
#' @param geohashes `character` vector of geohashes to be converted to polygons.
#' @param \dots Arguments for subsequent methods.
#' @param x An `sf`, `sfc`, or `sfg` object (from the `sf` package).
#' @param precision `integer` specifying the precision of geohashes to use, same as [gh_encode()]
#' @param minimal `logical`; if `FALSE`, the output will have all geohashes in the bounding box of `x`; if
#'   `TRUE`, any geohashes not intersecting `x` will be removed.
#' @param gh_df `data.frame` which 1) contains a column of geohashes to be converted to polygons and 2) will
#'   serve as the attribute table of the resultant [sf::sf] object.
#' @param gh_col `character` column name saying where the geohashes are stored in `gh_df`.
#'
#' @details
#' `gh_to_sf` relies on the [gh_decode()] function. Note in particular that this function accepts any length
#' of geohash (geohash-6, geohash-4, etc.) and is agnostic to potential overlap, though duplicates will be caught
#' and excluded.
#'
#' @return
#' For `gh_to_sf`, a [sf::sf] object.
#'
#' @examples
#' # get the neighborhood of this geohash in downtown Apia as an sf object
#' downtown = '2jtc5x'
#' apia_nbhd = unlist(gh_neighbors(downtown))
#' apia_sf = gh_to_sf(apia_nbhd)
#'
#' # all geohashes covering a random sampling within Apia:
#' # Note: requires sf package for st_sample
#' if (requireNamespace("sf", quietly = TRUE)) {
#'   apia_covering = gh_covering(sf::st_sample(apia_sf, 10L, type = 'random'))
#' }
#'
#' @name gis_tools
#' @export
gh_to_sf = function(...) {
  check_suggested('sf')
  UseMethod('gh_to_sf')
}

#' @rdname gis_tools
#' @export
gh_to_sf.default = function(geohashes, ...) {
  if (anyDuplicated(geohashes) > 0L) {
    idx = which(duplicated(geohashes))
    warning('Detected ', length(idx), ' duplicate input geohashes; removing')
    geohashes = geohashes[-idx]
  }
  sfc = gh_to_sfc(geohashes)
  sf::st_sf(ID = seq_along(geohashes), geometry = sfc, row.names = geohashes)
}

#' @rdname gis_tools
#' @export
gh_to_sf.data.frame = function(gh_df, gh_col = 'gh', ...) {
  if (is.na(idx <- match(gh_col, names(gh_df))))
    stop('Searched for geohashes at a column named "', gh_col, '", but found nothing.')
  gh = gh_df[[idx]]
  if (anyDuplicated(gh) > 0L) {
    idx = which(duplicated(gh))
    warning('Detected ', length(idx), ' duplicate input geohashes; removing')
    gh = gh[-idx]
    gh_df = gh_df[-idx, , drop = FALSE]
  }
  sfc = gh_to_sfc(gh)
  sf::st_sf(gh_df, geometry = sfc, row.names = gh)
}

#' @rdname gis_tools
#' @export
gh_covering = function(x, precision = 6L, minimal = FALSE) {
  check_suggested('sf')
  if (!inherits(x, c('sf', 'sfc', 'sfg')))
    stop('Object to cover must be sf, sfc, or sfg (from sf package)')
  orig_crs = sf::st_crs(x)
  if (is.na(orig_crs)) {
    orig_crs = sf::st_crs(4326L)
    warning("Input object 'x' has no CRS defined; assuming EPSG:4326 (WGS84)")
    if (inherits(x, 'sfg')) x = sf::st_sfc(x)
    sf::st_crs(x) = orig_crs
  }
  # Transform to 4326 to get lat/long bbox
  x_4326 = sf::st_transform(x, 4326L)
  bb = sf::st_bbox(x_4326)
  delta = 2.0 * gh_delta(precision)
  gh = with(expand.grid(
    latitude = seq(bb[['ymin']], bb[['ymax']] + delta[1L], by = delta[1L]),
    longitude = seq(bb[['xmin']], bb[['xmax']] + delta[2L], by = delta[2L])
  ), gh_encode(latitude, longitude, precision))
  cover = gh_to_sf(gh)
  if (minimal) {
    if (inherits(x_4326, 'sfg')) x_4326 = sf::st_sfc(x_4326, crs = 4326L)
    intersects = sf::st_intersects(cover, x_4326, sparse = FALSE)
    if (is.matrix(intersects)) {
      keep = rowSums(intersects) > 0L
    } else {
      keep = intersects
    }
    cover = cover[keep, ]
  }
  # Transform back to original CRS if it wasn't 4326
  if (orig_crs != sf::st_crs(4326L)) {
    cover = sf::st_transform(cover, orig_crs)
  }
  cover
}

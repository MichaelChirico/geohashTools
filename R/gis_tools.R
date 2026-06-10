# https://epsg.io/4326
wgs = function() sp::CRS('+proj=longlat +datum=WGS84', doCheckCRSArgs = FALSE)

# nocov start
check_suggested = function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop('This function requires an installation of ', pkg, "; install.packages('", pkg, "') to proceed.")
  }
}
# nocov end

#' Helpers for interfacing geohashes with sp/sf objects
#'
#' These functions smooth the gateway between working with geohashes and geospatial information built for the major geospatial packages in R, [sp::sp] and [sf::sf].
#'
#' @param geohashes `character` vector of geohashes to be converted to polygons.
#' @param \dots Arguments for subsequent methods.
#' @param SP A [sp::Spatial] object (requires `bbox` and `proj4string` methods, and `over` if `minimal` is `TRUE`)
#' @param precision `integer` specifying the precision of geohashes to use, same as [gh_encode()]
#' @param minimal `logical`; if `FALSE`, the output will have all geohashes in the bounding box of `SP`; if `TRUE`, any geohashes not intersecting `SP` will be removed.
#' @param gh_df `data.frame` which 1) contains a column of geohashes to be converted to polygons and 2) will serve as the `data` slot of the resultant [sp::SpatialPolygonsDataFrame] object.
#' @param gh_col `character` column name saying where the geohashes are stored in `gh_df`.
#'
#' @details
#' `gh_to_sp` relies on the [gh_decode()] function. Note in particular that this function accepts any length of geohash (geohash-6, geohash-4, etc.) and is agnostic to potential overlap, though duplicates will be caught and excluded.
#'
#' `gh_to_spdf.data.frame` will use `match.ID = FALSE` in the call to `SpatialPolygonsDataFrame`. Please file an issue if you'd like this to be more flexible.
#'
#' `gh_to_sf` is just a wrapper of [sf::st_as_sf()] around `gh_to_spdf`; as such it requires both `sp` and `sf` packages to work.
#'
#' @return
#' For `gh_to_sp`, a [sp::SpatialPolygons] object.
#'
#' For `gh_to_spdf`, a [sp::SpatialPolygonsDataFrame] object.
#'
#' For `gh_to_sf`, a [sf::sf] object.
#'
#' @examples
#' # get the neighborhood of this geohash in downtown Apia as an sp object
#' downtown = '2jtc5x'
#' apia_nbhd = unlist(gh_neighbors(downtown))
#' apia_sp = gh_to_sp(apia_nbhd)
#'
#' # all geohashes covering a random sampling within Apia:
#' apia_covering = gh_covering(smp <- sp::spsample(apia_sp, 10L, 'random'))
#'
#' apia_sf = gh_to_sf(apia_nbhd)
#'
#' @name gis_tools
#' @export
gh_to_sp = function(geohashes) {
  check_suggested('sp')
  gh = tolower(geohashes)
  if (anyDuplicated(gh) > 0L) {
    idx = which(duplicated(gh))
    warning('Detected ', length(idx), ' duplicate input geohashes; removing')
    gh = gh[-idx]
  }
  gh_xy = gh_decode(gh, include_delta = TRUE)
  sp::SpatialPolygons(lapply(seq_along(gh), function(ii) {
    with(gh_xy, sp::Polygons(list(sp::Polygon(cbind(
      # the four corners of the current geohash
      longitude[ii] + c(-1.0, -1.0, 1.0, 1.0, -1.0) * delta_longitude[ii],
      latitude[ii] + c(-1.0, 1.0, 1.0, -1.0, -1.0) * delta_latitude[ii]
    ))), ID = gh[ii]))
    # gh_decode returns values in WSG 84
  }), proj4string = wgs())
}

#' @rdname gis_tools
#' @export
gh_to_spdf = function(...) {
  check_suggested('sp')
  UseMethod('gh_to_spdf')
}

#' @rdname gis_tools
#' @export
gh_to_spdf.default = function(geohashes, ...) {
  if (anyDuplicated(geohashes) > 0L) {
    idx = which(duplicated(geohashes))
    warning('Detected ', length(idx), ' duplicate input geohashes; removing')
    geohashes = geohashes[-idx]
  }
  sp::SpatialPolygonsDataFrame(
    gh_to_sp(geohashes),
    data = data.frame(row.names = geohashes, ID = seq_along(geohashes))
  )
}

#' @rdname gis_tools
#' @export
gh_to_spdf.data.frame = function(gh_df, gh_col = 'gh', ...) {
  if (is.na(idx <- match(gh_col, names(gh_df))))
    stop('Searched for geohashes at a column named "', gh_col, '", but found nothing.')
  gh = gh_df[[idx]]
  if (anyDuplicated(gh) > 0L) {
    idx = which(duplicated(gh))
    warning('Detected ', length(idx), ' duplicate input geohashes; removing')
    gh = gh[-idx]
    gh_df = gh_df[-idx, , drop = FALSE]
  }
  sp::SpatialPolygonsDataFrame(
    gh_to_sp(gh), data = gh_df, match.ID = FALSE
  )
}

#' @rdname gis_tools
#' @export
gh_covering = function(SP, precision = 6L, minimal = FALSE) {
  check_suggested('sp')
  if (sf_input <- inherits(SP, 'sf')) {
    check_suggested('sf')
    SP = sf::as_Spatial(SP)
  }
  if (!inherits(SP, 'Spatial'))
    stop('Object to cover must be Spatial (or subclass)')
  # sp::over behaves poorly with 0-column input
  if (inherits(SP, 'SpatialPointsDataFrame') && !NCOL(SP))
    SP$id = rownames(SP@data)
  bb = sp::bbox(SP)
  delta = 2.0 * gh_delta(precision)
  # TODO: actually goes through an encode-decode cycle -- more efficient to
  #   just build the cells directly by rounding to the precision's grid
  gh = with(expand.grid(
    latitude = seq(bb[2L, 'min'], bb[2L, 'max'] + delta[1L], by = delta[1L]),
    longitude = seq(bb[1L, 'min'], bb[1L, 'max'] + delta[2L], by = delta[2L])
  ), gh_encode(latitude, longitude, precision))
  if (is.na(prj4 <- sp::proj4string(SP))) sp::proj4string(SP) = (prj4 <- wgs())
  cover = methods::as(gh_to_sf(gh), 'Spatial')
  sp::proj4string(cover) = prj4
  if (minimal) {
    # slightly more efficient to use rgeos, but there's a bug preventing
    #   that version from working (reported 2019-08-16):
    #   cover[c(rgeos::gIntersects(cover, SP, byid = c(TRUE, FALSE))), ]
    n_in_cover = vapply(sp::over(cover, SP, returnList=TRUE), NROW, integer(1L))
    cover = cover[which(n_in_cover > 0L), ]
    sp::proj4string(cover) = prj4
  }
  if (sf_input) sf::st_as_sf(cover) else cover
}


#' @rdname gis_tools
#' @export
gh_to_sf = function(...) {
  check_suggested('sf')
  sf::st_as_sf(gh_to_spdf(...))
}

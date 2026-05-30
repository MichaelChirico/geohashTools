# https://epsg.io/4326
wgs = function() sp::CRS('+proj=longlat +datum=WGS84', doCheckCRSArgs = FALSE)

# nocov start
check_suggested = function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop('This function requires an installation of ', pkg, "; install.packages('", pkg, "') to proceed.")
  }
}
# nocov end

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

gh_to_spdf = function(...) {
  check_suggested('sp')
  UseMethod('gh_to_spdf')
}

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

gh_covering = function(SP, precision = 6L, minimal = FALSE) {
  check_suggested('sp')
  if (sf_input <- inherits(SP, 'sf')) {
    check_suggested('sf')
    SP = sf::as_Spatial(SP)
  }
  if (!inherits(SP, 'Spatial'))
    stop('Object to cover must be Spatial (or subclass)')

  # Fast path for point input: the minimal covering of a set of points is
  #   exactly the set of distinct geohashes containing those points. We can
  #   encode the points directly instead of building & filtering a full
  #   bounding-box grid via sp::over -- the grid explodes with precision
  #   (e.g. >50k cells at precision 7, >1.6M at precision 8 for a small bbox),
  #   so this is orders of magnitude faster and uses far less memory.
  if (minimal && inherits(SP, 'SpatialPoints')) {
    xy = sp::coordinates(SP)
    gh = unique(gh_encode(xy[, 2L], xy[, 1L], precision))
    cover = gh_to_spdf(gh)
    if (is.na(prj4 <- sp::proj4string(SP))) prj4 = wgs()
    sp::proj4string(cover) = prj4
    return(if (sf_input) sf::st_as_sf(cover) else cover)
  }

  # sp::over behaves poorly with 0-column input
  if (inherits(SP, 'SpatialPointsDataFrame') && !NCOL(SP))
    SP$id = rownames(SP@data)
  bb = sp::bbox(SP)
  delta = 2.0 * gh_delta(precision)

  # Build grid and encode to geohashes
  gh = with(expand.grid(
    latitude = seq(bb[2L, 'min'], bb[2L, 'max'] + delta[1L], by = delta[1L]),
    longitude = seq(bb[1L, 'min'], bb[1L, 'max'] + delta[2L], by = delta[2L])
  ), gh_encode(latitude, longitude, precision))

  # Optimization: decode once and build polygons directly
  # instead of going through gh_to_sf -> gh_to_spdf -> gh_to_sp -> gh_decode
  gh_xy = gh_decode(gh, include_delta = TRUE)

  # Build SpatialPolygons directly from decoded coordinates
  cover_sp = sp::SpatialPolygons(lapply(seq_along(gh), function(ii) {
    sp::Polygons(list(sp::Polygon(cbind(
      # the four corners of the current geohash
      gh_xy$longitude[ii] + c(-1.0, -1.0, 1.0, 1.0, -1.0) * gh_xy$delta_longitude[ii],
      gh_xy$latitude[ii] + c(-1.0, 1.0, 1.0, -1.0, -1.0) * gh_xy$delta_latitude[ii]
    ))), ID = gh[ii])
  }), proj4string = wgs())

  # Convert to SPDF
  cover = sp::SpatialPolygonsDataFrame(
    cover_sp,
    data = data.frame(row.names = gh, ID = seq_along(gh))
  )

  if (is.na(prj4 <- sp::proj4string(SP))) sp::proj4string(SP) = (prj4 <- wgs())
  sp::proj4string(cover) = prj4
  if (minimal) {
    # slightly more efficient to use rgeos, but there's a bug preventing
    #   that version from working (reported 2019-08-16):
    #   cover[c(rgeos::gIntersects(cover, SP, byid = c(TRUE, FALSE))), ]
    n_in_cover = vapply(sp::over(cover, SP, returnList=TRUE), NROW, integer(1L))
    cover = cover[which(n_in_cover > 0L), ]
    sp::proj4string(cover) = prj4
  }
  return(if (sf_input) sf::st_as_sf(cover) else cover)
}


gh_to_sf = function(...) {
  check_suggested('sf')
  sf::st_as_sf(gh_to_spdf(...))
}

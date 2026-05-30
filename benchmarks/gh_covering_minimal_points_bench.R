# Benchmark: gh_covering(minimal = TRUE) for point input
#
# Compares the previous grid + sp::over implementation against the direct-encode
# fast path. Both produce identical covering cells; the fast path scales with the
# number of points rather than the bounding-box area.
#
# Run with: Rscript benchmarks/gh_covering_minimal_points_bench.R

suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages({
  library(microbenchmark)
  library(sp)
})

# --- previous implementation (grid + sp::over), extracted from pre-fast-path code
gh_covering_grid = function(SP, precision = 6L) {
  bb = sp::bbox(SP)
  delta = 2.0 * gh_delta(precision)
  gh = with(expand.grid(
    latitude  = seq(bb[2L, 'min'], bb[2L, 'max'] + delta[1L], by = delta[1L]),
    longitude = seq(bb[1L, 'min'], bb[1L, 'max'] + delta[2L], by = delta[2L])
  ), gh_encode(latitude, longitude, precision))
  gh_xy = gh_decode(gh, include_delta = TRUE)
  cover_sp = sp::SpatialPolygons(lapply(seq_along(gh), function(ii) {
    sp::Polygons(list(sp::Polygon(cbind(
      gh_xy$longitude[ii] + c(-1, -1, 1, 1, -1) * gh_xy$delta_longitude[ii],
      gh_xy$latitude[ii]  + c(-1, 1, 1, -1, -1) * gh_xy$delta_latitude[ii]
    ))), ID = gh[ii])
  }), proj4string = sp::CRS('+proj=longlat +datum=WGS84', doCheckCRSArgs = FALSE))
  cover = sp::SpatialPolygonsDataFrame(
    cover_sp, data = data.frame(row.names = gh, ID = seq_along(gh))
  )
  sp::proj4string(SP) = sp::proj4string(cover)
  n_in_cover = vapply(sp::over(cover, SP, returnList = TRUE), NROW, integer(1L))
  cover[which(n_in_cover > 0L), ]
}

make_points = function(n, spread) {
  set.seed(123L)
  sp::SpatialPoints(cbind(
    runif(n, 114.5, 114.5 + spread),
    runif(n, -3.4, -3.4 + spread)
  ))
}

cases = expand.grid(
  n_points  = c(100L, 1000L),
  spread    = c(0.1, 0.5),
  precision = c(6L, 7L, 8L),
  stringsAsFactors = FALSE
)

# Above this many candidate grid cells, the old grid + sp::over path is
# impractical (builds one sp polygon per cell -> minutes and/or out of memory).
# We skip timing it there and report it as such; the fast path still runs.
GRID_CELL_CAP = 1e5

rows = vector('list', nrow(cases))
for (i in seq_len(nrow(cases))) {
  tc  = cases[i, ]
  pts = make_points(tc$n_points, tc$spread)

  grid_cells = {
    bb = sp::bbox(pts); delta = 2.0 * gh_delta(tc$precision)
    length(seq(bb[2L, 1L], bb[2L, 2L] + delta[1L], by = delta[1L])) *
      length(seq(bb[1L, 1L], bb[1L, 2L] + delta[2L], by = delta[2L]))
  }

  new_cells = sort(rownames(gh_covering(pts, tc$precision, minimal = TRUE)@data))
  new_ms = median(microbenchmark(
    gh_covering(pts, tc$precision, minimal = TRUE), times = 10L)$time) / 1e6

  if (grid_cells <= GRID_CELL_CAP) {
    # confirm identical covering cells before timing the old path
    old_cells = sort(rownames(gh_covering_grid(pts, tc$precision)@data))
    stopifnot(identical(old_cells, new_cells))
    reps = if (grid_cells > 2e4) 3L else 10L
    old_ms  = round(median(microbenchmark(
      gh_covering_grid(pts, tc$precision), times = reps)$time) / 1e6, 1)
    speedup = round(old_ms / new_ms, 1)
  } else {
    old_ms = NA_real_; speedup = NA_real_
  }

  rows[[i]] = data.frame(
    n_points     = tc$n_points,
    spread       = tc$spread,
    precision    = tc$precision,
    grid_cells   = grid_cells,
    result_cells = length(new_cells),
    old_ms       = old_ms,
    new_ms       = round(new_ms, 2),
    speedup      = speedup
  )
  cat(sprintf("n=%4d spread=%.1f prec=%d: grid=%7d cells, old=%s, new=%.2f ms%s\n",
              tc$n_points, tc$spread, tc$precision, grid_cells,
              if (is.na(old_ms)) "(impractical)" else sprintf("%.1f ms", old_ms),
              new_ms,
              if (is.na(speedup)) "" else sprintf(" (%.0fx)", speedup)))
}

results = do.call(rbind, rows)
saveRDS(results, 'benchmarks/gh_covering_minimal_points_results.rds')
cat('\n=== Summary ===\n')
print(results, row.names = FALSE)
cat(sprintf('\nAmong cases where the old grid path is tractable: median speedup %.0fx, max %.0fx.\n',
            median(results$speedup, na.rm = TRUE), max(results$speedup, na.rm = TRUE)))
cat(sprintf('%d of %d cases have a candidate grid too large for the old path to run at all.\n',
            sum(is.na(results$speedup)), nrow(results)))

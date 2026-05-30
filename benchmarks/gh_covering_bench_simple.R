# Simple benchmark comparing old vs new gh_covering
# Loads both versions and compares directly

library(microbenchmark)
library(ggplot2)
library(sp)

# Define old version (before optimization)
gh_covering_old = function(SP, precision = 6L, minimal = FALSE) {
  if (sf_input <- inherits(SP, 'sf')) {
    SP = sf::as_Spatial(SP)
  }
  if (!inherits(SP, 'Spatial'))
    stop('Object to cover must be Spatial (or subclass)')
  if (inherits(SP, 'SpatialPointsDataFrame') && !NCOL(SP))
    SP$id = rownames(SP@data)
  bb = sp::bbox(SP)
  delta = 2.0 * geohashTools::gh_delta(precision)

  # OLD: goes through encode-decode cycle
  gh = with(expand.grid(
    latitude = seq(bb[2L, 'min'], bb[2L, 'max'] + delta[1L], by = delta[1L]),
    longitude = seq(bb[1L, 'min'], bb[1L, 'max'] + delta[2L], by = delta[2L])
  ), geohashTools::gh_encode(latitude, longitude, precision))

  wgs_crs = sp::CRS('+proj=longlat +datum=WGS84', doCheckCRSArgs = FALSE)
  if (is.na(prj4 <- sp::proj4string(SP))) sp::proj4string(SP) = (prj4 <- wgs_crs)

  # OLD: calls gh_to_sf which calls gh_to_spdf which calls gh_to_sp which decodes
  cover = methods::as(geohashTools::gh_to_sf(gh), 'Spatial')
  sp::proj4string(cover) = prj4

  if (minimal) {
    n_in_cover = vapply(sp::over(cover, SP, returnList=TRUE), NROW, integer(1L))
    cover = cover[which(n_in_cover > 0L), ]
    sp::proj4string(cover) = prj4
  }
  return(if (sf_input) sf::st_as_sf(cover) else cover)
}

# Load new version
devtools::load_all(".", quiet = TRUE)

# Test data
set.seed(123)
test_points <- sp::SpatialPoints(cbind(
  runif(100, 114.5, 115.0),
  runif(100, -3.4, -3.2)
))

cat("Benchmarking gh_covering: Old vs New\n")
cat("Test data: 100 points, 0.5 degree spread\n\n")

# Test different precisions
precisions <- c(4, 5, 6, 7, 8)
results <- list()

for (prec in precisions) {
  cat(sprintf("Precision %d...\n", prec))

  bm <- microbenchmark(
    old = gh_covering_old(test_points, precision = prec),
    new = gh_covering(test_points, precision = prec),
    times = 10L
  )

  results[[as.character(prec)]] <- data.frame(
    precision = prec,
    method = c("old", "new"),
    median_ms = c(
      median(bm$time[bm$expr == "old"]) / 1e6,
      median(bm$time[bm$expr == "new"]) / 1e6
    )
  )

  speedup <- results[[as.character(prec)]]$median_ms[1] /
             results[[as.character(prec)]]$median_ms[2]
  cat(sprintf("  Old: %.1f ms, New: %.1f ms, Speedup: %.2fx\n\n",
              results[[as.character(prec)]]$median_ms[1],
              results[[as.character(prec)]]$median_ms[2],
              speedup))
}

results_df <- do.call(rbind, results)
results_df$speedup <- with(results_df[results_df$method == "old", ],
                             median_ms) / results_df$median_ms[results_df$method == "new"]

# Create plot
p <- ggplot(results_df, aes(x = precision, y = median_ms, color = method)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  scale_y_log10() +
  labs(
    title = "gh_covering Performance Comparison",
    subtitle = "100 random points, 0.5° spread",
    x = "Precision",
    y = "Median Time (ms, log scale)",
    color = "Method"
  ) +
  theme_minimal() +
  theme(legend.position = "top")

ggsave("benchmarks/gh_covering_simple_comparison.png", p, width = 8, height = 6, dpi = 150)
cat("\nSaved plot to benchmarks/gh_covering_simple_comparison.png\n")

# Print summary
cat("\n=== Summary ===\n")
print(results_df)

cat(sprintf("\nMedian speedup across all precisions: %.2fx\n",
            median(results_df$speedup[results_df$method == "new"])))

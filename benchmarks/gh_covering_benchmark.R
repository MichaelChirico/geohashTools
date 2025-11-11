# Benchmark script for gh_covering optimization
# Compares current implementation vs. optimized direct grid generation

# Load package from source
devtools::load_all(".", quiet = TRUE)

library(microbenchmark)
library(ggplot2)
library(sp)

# Create test data of varying sizes
create_test_points <- function(n_points = 100, spread = 1.0) {
  sp::SpatialPoints(cbind(
    runif(n_points, 114.5, 114.5 + spread),
    runif(n_points, -3.4, -3.4 + spread)
  ))
}

# Test different grid sizes by varying point spread and precision
test_cases <- expand.grid(
  n_points = c(10, 100),
  spread = c(0.1, 0.5, 1.0),  # degrees - affects grid size
  precision = c(4, 6, 8, 10),
  stringsAsFactors = FALSE
)

cat("Running benchmarks for gh_covering...\n")
cat("Test cases:", nrow(test_cases), "\n\n")

results <- vector("list", nrow(test_cases))

for (i in seq_len(nrow(test_cases))) {
  tc <- test_cases[i, ]
  cat(sprintf("Test %d/%d: n_points=%d, spread=%.1f, precision=%d\n",
              i, nrow(test_cases), tc$n_points, tc$spread, tc$precision))

  test_points <- create_test_points(tc$n_points, tc$spread)

  # Run benchmark
  bm <- microbenchmark(
    current = gh_covering(test_points, precision = tc$precision),
    times = 20L,
    unit = "ms"
  )

  results[[i]] <- data.frame(
    n_points = tc$n_points,
    spread = tc$spread,
    precision = tc$precision,
    median_ms = median(bm$time) / 1e6,
    mean_ms = mean(bm$time) / 1e6,
    min_ms = min(bm$time) / 1e6,
    max_ms = max(bm$time) / 1e6
  )

  cat(sprintf("  Median: %.2f ms\n\n", results[[i]]$median_ms))
}

results_df <- do.call(rbind, results)

# Save results
saveRDS(results_df, "benchmarks/gh_covering_baseline_results.rds")
cat("Saved baseline results to benchmarks/gh_covering_baseline_results.rds\n")

# Create visualization
p <- ggplot(results_df, aes(x = precision, y = median_ms,
                             color = factor(spread),
                             shape = factor(n_points))) +
  geom_line() +
  geom_point(size = 3) +
  scale_y_log10() +
  labs(
    title = "gh_covering Performance (Baseline)",
    subtitle = "Current encode-decode implementation",
    x = "Precision",
    y = "Median Time (ms, log scale)",
    color = "Spread (degrees)",
    shape = "Points"
  ) +
  theme_minimal() +
  theme(legend.position = "right")

ggsave("benchmarks/gh_covering_baseline.png", p, width = 10, height = 6, dpi = 150)
cat("Saved plot to benchmarks/gh_covering_baseline.png\n")

# Print summary
cat("\n=== Summary Statistics ===\n")
print(results_df[order(results_df$median_ms, decreasing = TRUE), ])

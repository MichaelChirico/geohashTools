# Comparison benchmark for gh_covering optimization
# Tests optimized version vs results from baseline

library(microbenchmark)
library(ggplot2)
library(sp)

# Load the optimized version
devtools::load_all(".", quiet = TRUE)

# Create test data
create_test_points <- function(n_points = 100, spread = 1.0) {
  sp::SpatialPoints(cbind(
    runif(n_points, 114.5, 114.5 + spread),
    runif(n_points, -3.4, -3.4 + spread)
  ))
}

# Smaller, faster test suite for comparison
test_cases <- expand.grid(
  n_points = c(10, 100),
  spread = c(0.1, 0.5, 1.0),
  precision = c(4, 6, 8),
  stringsAsFactors = FALSE
)

cat("Running comparison benchmarks...\n")
cat("Testing optimized gh_covering implementation\n")
cat("Test cases:", nrow(test_cases), "\n\n")

results <- vector("list", nrow(test_cases))

for (i in seq_len(nrow(test_cases))) {
  tc <- test_cases[i, ]
  cat(sprintf("Test %d/%d: n_points=%d, spread=%.1f, precision=%d\n",
              i, nrow(test_cases), tc$n_points, tc$spread, tc$precision))

  test_points <- create_test_points(tc$n_points, tc$spread)

  # Run benchmark on optimized version
  bm <- microbenchmark(
    optimized = gh_covering(test_points, precision = tc$precision),
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

optimized_df <- do.call(rbind, results)

# Save optimized results
saveRDS(optimized_df, "benchmarks/gh_covering_optimized_results.rds")
cat("\nSaved optimized results to benchmarks/gh_covering_optimized_results.rds\n")

# Load baseline if it exists and compare
if (file.exists("benchmarks/gh_covering_baseline_results.rds")) {
  baseline_df <- readRDS("benchmarks/gh_covering_baseline_results.rds")

  # Merge results
  baseline_df$version <- "baseline"
  optimized_df$version <- "optimized"
  combined_df <- rbind(baseline_df[, names(optimized_df)], optimized_df)

  # Calculate speedup
  comparison <- merge(
    baseline_df[, c("n_points", "spread", "precision", "median_ms")],
    optimized_df[, c("n_points", "spread", "precision", "median_ms")],
    by = c("n_points", "spread", "precision"),
    suffixes = c("_baseline", "_optimized")
  )
  comparison$speedup <- comparison$median_ms_baseline / comparison$median_ms_optimized

  cat("\n=== Performance Comparison ===\n")
  print(comparison[order(-comparison$speedup), ])

  cat(sprintf("\nMedian speedup: %.2fx\n", median(comparison$speedup)))
  cat(sprintf("Mean speedup: %.2fx\n", mean(comparison$speedup)))
  cat(sprintf("Max speedup: %.2fx\n", max(comparison$speedup)))

  # Create comparison plot
  p <- ggplot(combined_df, aes(x = precision, y = median_ms,
                                color = version,
                                linetype = factor(spread))) +
    geom_line() +
    geom_point(size = 2) +
    facet_wrap(~n_points, labeller = label_both) +
    scale_y_log10() +
    labs(
      title = "gh_covering Performance: Baseline vs Optimized",
      x = "Precision",
      y = "Median Time (ms, log scale)",
      color = "Version",
      linetype = "Spread (degrees)"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave("benchmarks/gh_covering_comparison.png", p, width = 12, height = 6, dpi = 150)
  cat("\nSaved comparison plot to benchmarks/gh_covering_comparison.png\n")

  # Speedup plot
  p2 <- ggplot(comparison, aes(x = precision, y = speedup,
                                color = factor(spread),
                                shape = factor(n_points))) +
    geom_line() +
    geom_point(size = 3) +
    geom_hline(yintercept = 1, linetype = "dashed", color = "gray50") +
    labs(
      title = "gh_covering Speedup: Optimized vs Baseline",
      subtitle = "Values > 1.0 indicate optimized is faster",
      x = "Precision",
      y = "Speedup Factor",
      color = "Spread (degrees)",
      shape = "Points"
    ) +
    theme_minimal() +
    theme(legend.position = "right")

  ggsave("benchmarks/gh_covering_speedup.png", p2, width = 10, height = 6, dpi = 150)
  cat("Saved speedup plot to benchmarks/gh_covering_speedup.png\n")
}

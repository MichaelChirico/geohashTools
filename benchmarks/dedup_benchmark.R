# Benchmark for duplicate detection optimization
# Compares double-scan (anyDuplicated + duplicated) vs single-pass (duplicated only)

library(microbenchmark)
library(ggplot2)

# Define old double-scan approach
dedup_old <- function(x) {
  if (anyDuplicated(x) > 0L) {
    idx = which(duplicated(x))
    x = x[-idx]
  }
  x
}

# Define new single-pass approach
dedup_new <- function(x) {
  dup_idx = duplicated(x)
  if (any(dup_idx)) {
    x = x[!dup_idx]
  }
  x
}

# Test with varying input sizes and duplicate ratios
test_cases <- expand.grid(
  n = c(100, 1000, 10000, 100000),
  dup_ratio = c(0.0, 0.1, 0.5, 0.9),
  stringsAsFactors = FALSE
)

cat("Benchmarking duplicate detection methods\n")
cat("Test cases:", nrow(test_cases), "\n\n")

results <- vector("list", nrow(test_cases))

for (i in seq_len(nrow(test_cases))) {
  tc <- test_cases[i, ]
  cat(sprintf("Test %d/%d: n=%d, dup_ratio=%.1f\n",
              i, nrow(test_cases), tc$n, tc$dup_ratio))

  # Create test data with specified duplicate ratio
  n_unique <- ceiling(tc$n * (1 - tc$dup_ratio))
  test_data <- sample(paste0("gh", seq_len(n_unique)), tc$n, replace = TRUE)

  # Run benchmark
  bm <- microbenchmark(
    old = dedup_old(test_data),
    new = dedup_new(test_data),
    times = 50L,
    unit = "us"
  )

  old_median <- median(bm$time[bm$expr == "old"]) / 1e3
  new_median <- median(bm$time[bm$expr == "new"]) / 1e3

  results[[i]] <- data.frame(
    n = tc$n,
    dup_ratio = tc$dup_ratio,
    old_median_us = old_median,
    new_median_us = new_median,
    speedup = old_median / new_median
  )

  cat(sprintf("  Old: %.1f µs, New: %.1f µs, Speedup: %.2fx\n\n",
              old_median, new_median, results[[i]]$speedup))
}

results_df <- do.call(rbind, results)

# Save results
saveRDS(results_df, "benchmarks/dedup_results.rds")
cat("\nSaved results to benchmarks/dedup_results.rds\n")

# Create visualization
p1 <- ggplot(results_df, aes(x = n, y = new_median_us / old_median_us,
                              color = factor(dup_ratio),
                              group = factor(dup_ratio))) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "gray50") +
  scale_x_log10(labels = scales::comma) +
  labs(
    title = "Duplicate Detection: Single-Pass vs Double-Scan",
    subtitle = "Values < 1.0 indicate single-pass is faster",
    x = "Input Size (log scale)",
    y = "Relative Speed (New / Old)",
    color = "Duplicate Ratio"
  ) +
  theme_minimal() +
  theme(legend.position = "right")

ggsave("benchmarks/dedup_speedup.png", p1, width = 10, height = 6, dpi = 150)
cat("Saved speedup plot to benchmarks/dedup_speedup.png\n")

# Absolute performance plot
results_long <- reshape2::melt(
  results_df,
  id.vars = c("n", "dup_ratio"),
  measure.vars = c("old_median_us", "new_median_us"),
  variable.name = "method",
  value.name = "time_us"
)
results_long$method <- factor(results_long$method,
                                levels = c("old_median_us", "new_median_us"),
                                labels = c("Double-scan (old)", "Single-pass (new)"))

p2 <- ggplot(results_long, aes(x = n, y = time_us,
                                color = method,
                                linetype = factor(dup_ratio))) +
  geom_line(size = 0.8) +
  geom_point(size = 2) +
  scale_x_log10(labels = scales::comma) +
  scale_y_log10(labels = scales::comma) +
  labs(
    title = "Duplicate Detection Performance",
    x = "Input Size (log scale)",
    y = "Median Time (µs, log scale)",
    color = "Method",
    linetype = "Duplicate Ratio"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave("benchmarks/dedup_absolute.png", p2, width = 10, height = 6, dpi = 150)
cat("Saved absolute performance plot to benchmarks/dedup_absolute.png\n")

# Summary statistics
cat("\n=== Summary Statistics ===\n")
cat(sprintf("Overall median speedup: %.2fx\n", median(results_df$speedup)))
cat(sprintf("Mean speedup: %.2fx\n", mean(results_df$speedup)))
cat(sprintf("Best case speedup: %.2fx (n=%d, dup_ratio=%.1f)\n",
            max(results_df$speedup),
            results_df$n[which.max(results_df$speedup)],
            results_df$dup_ratio[which.max(results_df$speedup)]))

cat("\nBy duplicate ratio:\n")
aggregate(speedup ~ dup_ratio, results_df, function(x) sprintf("%.2fx", median(x)))

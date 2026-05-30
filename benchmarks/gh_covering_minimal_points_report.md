# `gh_covering(minimal = TRUE)` fast path for point input

## Summary

For point input (`SpatialPoints` / `SpatialPointsDataFrame`), the minimal covering
is exactly the set of distinct geohashes that contain the points. The previous
implementation instead built a full geohash grid over the bounding box and filtered
it with `sp::over`. That grid's size scales with the **bounding-box area**, not the
number of points, so it exploded at higher precision — building one `sp` polygon per
candidate cell and running a point-in-polygon test against every one.

The fast path encodes the points directly (`unique(gh_encode(...))`), so cost scales
with the **number of points**. Output is identical (verified cell-for-cell in the
benchmark and in `tests/testthat/test-gis-tools.R`).

## Headline

200 points spread over a ~0.5° × 0.2° box, precision 7:

| | candidate grid cells | time |
|---|---|---|
| old (grid + `sp::over`) | 51,194 | **3184 ms** |
| new (direct encode) | — | **10.7 ms** |

≈ **300× faster**, and the gap widens with precision and bounding-box size.

## Scaling table

`benchmarks/gh_covering_minimal_points_bench.R`, median times. Cases whose candidate
grid exceeds 100,000 cells are marked *impractical* — the old path is too slow / memory
hungry to even time, whereas the new path is unaffected.

| n_points | spread (°) | precision | grid cells | result cells | old (ms) | new (ms) | speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 | 0.1 | 6 | 209 | 73 | 10.1 | 7.05 | 1.4× |
| 1000 | 0.1 | 6 | 220 | 180 | 12.6 | 9.91 | 1.3× |
| 100 | 0.5 | 6 | 4,230 | 98 | 238.0 | 7.33 | 32.5× |
| 1000 | 0.5 | 6 | 4,324 | 895 | 250.1 | 32.71 | 7.6× |
| 100 | 0.1 | 7 | 5,402 | 100 | 334.8 | 7.15 | 46.8× |
| 1000 | 0.1 | 7 | 5,476 | 926 | 331.2 | 30.35 | 10.9× |
| 100 | 0.5 | 7 | 129,591 | 100 | *impractical* | 7.84 | — |
| 1000 | 0.5 | 7 | 133,225 | 998 | *impractical* | 32.18 | — |
| 100 | 0.1 | 8 | 165,870 | 100 | *impractical* | 7.86 | — |
| 1000 | 0.1 | 8 | 170,236 | 998 | *impractical* | 30.94 | — |
| 100 | 0.5 | 8 | 4,118,058 | 100 | *impractical* | 7.76 | — |
| 1000 | 0.5 | 8 | 4,235,504 | 1000 | *impractical* | 31.85 | — |

Key observations:

- The new path's time tracks the **number of points** (~7 ms for 100, ~31 ms for 1000),
  independent of precision and bounding-box area.
- The old path's time tracks the **grid size**, which grows ~32× per precision step and
  with the square of the bounding-box extent — quickly reaching millions of cells.
- At precision 8 with a 0.5° box the old grid is >4 million cells; the new path returns
  the same answer in ~8–32 ms.

## Reproduce

```sh
Rscript benchmarks/gh_covering_minimal_points_bench.R
```

Machine: R 4.5.0, macOS (Darwin 24.4.0). Absolute times vary by machine; the scaling
behaviour does not.

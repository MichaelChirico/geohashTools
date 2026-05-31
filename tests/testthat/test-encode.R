test_that('geohash encoder works', {
  y = 0.1234
  x = 5.6789
  # test defaults on scalar input
  expect_identical(gh_encode(y, x), 's0h09n')
  expect_identical(gh_encode(-y, -x), '7zgzqc')

  # longitude wraps around every 360 degrees
  expect_identical(gh_encode(y, x), gh_encode(y, x - 360.0))

  # all level-1 centroids to be sure my manual logic for precision = 1 works
  # nolint start: line_length_linter.
  expect_identical(
    gh_encode(
      c(-067.5,  -67.5,  -22.5,  -22.5, -67.5, -67.5, -22.5, -22.5,   22.5,   22.5,   67.5,   67.5,  22.5,  22.5,  67.5,  67.5, -67.5, -67.5, -22.5, -22.5, -67.5, -67.5, -22.5, -22.5, 22.5, 22.5, 67.5, 67.5,  22.5,  22.5,  67.5,  67.5),
      c(-157.5, -112.5, -157.5, -112.5, -67.5, -22.5, -67.5, -22.5, -157.5, -112.5, -157.5, -112.5, -67.5, -22.5, -67.5, -22.5,  22.5,  67.5,  22.5,  67.5, 112.5, 157.5, 112.5, 157.5, 22.5, 67.5, 22.5, 67.5, 112.5, 157.5, 112.5, 157.5),
      precision = 1L
    ),
    c('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'j', 'k', 'm', 'n', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z')
  )
  # nolint end: line_length_linter.

  # geohash cells are _left closed, right open_: [x1, x2) x [y1, y2), see:
  #   http://geohash.org/s000
  expect_identical(gh_encode(0.0, 0.0, 2L), 's0')

  # boundary cases
  # need to balloon eps so that adding .5 doesn't obliterate sig figs
  eps = 1000.0*.Machine$double.eps
  expect_identical(
    gh_encode(
      c(eps, eps, -eps, -eps,  90.0 - eps, 90.0 - eps, eps - 90.0, eps - 90.0),
      c(eps, -eps, eps, -eps, eps - 180.0, 180.0 - eps, eps - 180.0, 180.0 - eps)
    ),
    c('s00000', 'ebpbpb', 'kpbpbp', '7zzzzz', 'bpbpbp', 'zzzzzz', '000000', 'pbpbpb')
  )

  # test precision argument
  expect_identical(gh_encode(y, x, 12L), 's0h09nrnzgqv')
  # maximum precision
  n = 25L
  expect_identical(
    gh_encode(y, x, n),
    substring('s0h09nrnzgqv8je0f4jpd0000', 1L, n)
  )
  # truncation beyond there
  expect_warning(
    expect_identical(
      gh_encode(y, x, n + 5L),
      substring('s0h09nrnzgqv8je0f4jpd0000', 1L, n)
    ),
    'Precision is limited',
    fixed = TRUE
  )

  # implicit integer truncation
  expect_identical(gh_encode(y, x, 1.04), 's')

  # invalid precision
  expect_error(gh_encode(y, x, 0.0), 'Precision is measured', fixed = TRUE)

  # invalid input
  expect_error(gh_encode(100.0, x), 'Invalid latitude at index 1', fixed = TRUE)
  expect_error(gh_encode(-91.0, x), 'Invalid latitude at index 1', fixed = TRUE)
  expect_error(
    gh_encode(c(y, 90.0), c(x, x)),
    'Invalid latitude at index 2',
    fixed = TRUE
  )
  expect_error(
    gh_encode(y, x, c(5L, 6L)),
    'precision must be length 1 or the same length as the coordinates',
    fixed = TRUE
  )
  expect_error(
    gh_encode(c(y, y), x),
    'Inputs must be the same size',
    fixed = TRUE
  )

  # semi-valid auto-corrected input -- 180 --> -180 by wrapping
  expect_identical(gh_encode(y, 180.0), '80008n')
  expect_identical(gh_encode(y, 293475908.0), 'db508w')

  # missing/infinite input
  expect_identical(gh_encode(c(y, NA), c(x, NA)), c('s0h09n', NA_character_))
  expect_identical(
    gh_encode(c(NaN, Inf, -Inf, 1:3), c(1:3, NaN, Inf, -Inf)),
    rep(NA_character_, 6L)
  )

  # different branch for precision=1 of the above errors
  expect_error(
    gh_encode(100.0, x, 1L),
    'Invalid latitude at index 1',
    fixed = TRUE
  )
  expect_identical(gh_encode(y, 180.0, 1L), '8')
  expect_identical(gh_encode(NA, NA, 1L), NA_character_)

  # stress testing
  expect_identical(gh_encode(numeric(), numeric()), character())
})

test_that('gh_encode accepts a vector of precisions', {
  set.seed(4080L)
  lat = runif(8L, -80.0, 80.0)
  lon = runif(8L, -170.0, 170.0)
  precision = 1:8

  vec = gh_encode(lat, lon, precision)

  # equivalent to encoding each coordinate at its own precision
  elementwise = vapply(
    seq_along(lat),
    function(i) gh_encode(lat[i], lon[i], precision[i]),
    character(1L)
  )
  expect_identical(vec, elementwise)

  # each result is the length-`precision` prefix of the full-precision encode
  full = gh_encode(lat, lon, max(precision))
  expect_identical(vec, substr(full, 1L, precision))

  # length-1 precision still recycles (unchanged behaviour)
  expect_identical(gh_encode(lat, lon, 6L), substr(full, 1L, 6L))

  # NA / infinite coordinates remain NA even with per-element precision
  expect_identical(
    gh_encode(c(0.1234, NA, Inf), c(5.6789, 1.0, 2.0), c(6L, 5L, 4L)),
    c('s0h09n', NA_character_, NA_character_)
  )

  # per-element truncation past the maximum precision
  expect_warning(
    expect_identical(
      gh_encode(c(0.1234, 0.1234), c(5.6789, 5.6789), c(6L, 30L)),
      c('s0h09n', substring('s0h09nrnzgqv8je0f4jpd0000', 1L, 25L))
    ),
    'Precision is limited',
    fixed = TRUE
  )

  # invalid per-element precision
  expect_error(
    gh_encode(lat, lon, c(1:7, 0L)),
    'Precision is measured',
    fixed = TRUE
  )
  expect_error(
    gh_encode(lat, lon, c(1:7, NA_integer_)),
    'Precision is measured',
    fixed = TRUE
  )
  # wrong-length precision (neither 1 nor length(coords))
  expect_error(
    gh_encode(lat, lon, 1:3),
    'precision must be length 1 or the same length as the coordinates',
    fixed = TRUE
  )
})

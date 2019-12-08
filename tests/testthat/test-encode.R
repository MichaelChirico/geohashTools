context('Geohash encoder')

test_that('geohash encoder works', {
  y = 0.1234; x = 5.6789
  # test defaults on scalar input
  expect_equal(gh_encode(y, x), 's0h09n')
  expect_equal(gh_encode(-y, -x), '7zgzqc')

  # longitude wraps around every 360 degrees
  expect_equal(gh_encode(y, x), gh_encode(y, x-360))

  # all level-1 centroids to be sure my manual logic for precision = 1 works
  expect_equal(gh_encode(c(-67.5, -67.5, -22.5, -22.5, -67.5, -67.5, -22.5,
                           -22.5, 22.5, 22.5, 67.5, 67.5, 22.5, 22.5, 67.5,
                           67.5, -67.5, -67.5, -22.5, -22.5, -67.5, -67.5,
                           -22.5, -22.5, 22.5, 22.5, 67.5, 67.5, 22.5, 22.5,
                           67.5, 67.5),
                         c(-157.5, -112.5, -157.5, -112.5, -67.5, -22.5,
                           -67.5, -22.5, -157.5, -112.5, -157.5, -112.5,
                           -67.5, -22.5, -67.5, -22.5, 22.5, 67.5, 22.5,
                           67.5, 112.5, 157.5, 112.5, 157.5, 22.5, 67.5,
                           22.5, 67.5, 112.5, 157.5, 112.5, 157.5),
                         precision = 1L),
               c("0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "b", "c",
                 "d", "e", "f", "g", "h", "j", "k", "m", "n", "p", "q", "r",
                 "s", "t", "u", "v", "w", "x", "y", "z"))

  # geohash cells are _left closed, right open_: [x1, x2) x [y1, y2), see:
  #   http://geohash.org/s000
  expect_equal(gh_encode(0, 0, 2L), 's0')

  # boundary cases
  # need to balloon eps so that adding .5 doesn't obliterate sig figs
  eps = 1000*.Machine$double.eps
  expect_equal(gh_encode(c(eps, eps, -eps, -eps,
                           90 - eps, 90 - eps, eps - 90, eps - 90),
                         c(eps, -eps, eps, -eps,
                           eps - 180, 180 - eps, eps - 180, 180 - eps)),
               c("s00000", "ebpbpb", "kpbpbp", "7zzzzz",
                 "bpbpbp", "zzzzzz", "000000", "pbpbpb"))

  # test precision argument
  expect_equal(gh_encode(y, x, 12L), 's0h09nrnzgqv')
  # maximum precision
  n = 25L
  expect_equal(gh_encode(y, x, n),
               substring('s0h09nrnzgqv8je0f4jpd0000', 1L, n))
  # truncation beyond there
  expect_warning(out <- gh_encode(y, x, n+5L),
                 'Precision is limited', fixed = TRUE)
  expect_equal(out, substring('s0h09nrnzgqv8je0f4jpd0000', 1L, n))

  # implicit integer truncation
  expect_equal(gh_encode(y, x, 1.04), 's')

  # invalid precision
  expect_error(gh_encode(y, x, 0), 'Precision is measured', fixed = TRUE)

  # invalid input
  expect_error(gh_encode(100, x), 'Invalid latitude at index 1', fixed = TRUE)
  expect_error(gh_encode(-91, x), 'Invalid latitude at index 1', fixed = TRUE)
  expect_error(gh_encode(c(y, 90), c(x, x)),
               'Invalid latitude at index 2', fixed = TRUE)
  expect_error(gh_encode(y, x, c(5, 6)),
               'More than one precision value', fixed = TRUE)
  expect_error(gh_encode(c(y, y), x),
               'Inputs must be the same size', fixed = TRUE)

  # semi-valid auto-corrected input -- 180 --> -180 by wrapping
  expect_equal(gh_encode(y, 180), '80008n')
  expect_equal(gh_encode(y, 293475908), 'db508w')

  # missing/infinite input
  expect_equal(gh_encode(c(y, NA), c(x, NA)), c('s0h09n', NA_character_))
  expect_equal(gh_encode(c(NaN, Inf, -Inf, 1:3), c(1:3, NaN, Inf, -Inf)),
               rep(NA_character_, 6L))

  # different branch for precision=1 of the above errors
  expect_error(gh_encode(100, x, 1L),
               'Invalid latitude at index 1', fixed = TRUE)
  expect_equal(gh_encode(y, 180, 1L), '8')
  expect_equal(gh_encode(NA, NA, 1L), NA_character_)

  # stress testing
  expect_equal(gh_encode(numeric(), numeric()), character())
})

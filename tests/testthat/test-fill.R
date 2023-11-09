test_that('gh_fill works', {

  # Test single string
  expect_equal(gh_fill("9w", 3L), c("9w0", "9w1", "9w2", "9w3", "9w4", "9w5",
                                    "9w6", "9w7", "9w8", "9w9", "9wb", "9wc",
                                    "9wd", "9we", "9wf", "9wg", "9wh", "9wj",
                                    "9wk", "9wm", "9wn", "9wp", "9wq", "9wr",
                                    "9ws", "9wt", "9wu", "9wv", "9ww", "9wx",
                                    "9wy", "9wz"))
  # Test vector of inputs
  expect_equal(gh_fill(c("9w", "9x"), 3L),
               c("9w0", "9w1", "9w2", "9w3", "9w4", "9w5",
                 "9w6", "9w7", "9w8", "9w9", "9wb", "9wc",
                 "9wd", "9we", "9wf", "9wg", "9wh", "9wj",
                 "9wk", "9wm", "9wn", "9wp", "9wq", "9wr",
                 "9ws", "9wt", "9wu", "9wv", "9ww", "9wx",
                 "9wy", "9wz",
                 "9x0", "9x1", "9x2", "9x3", "9x4", "9x5",
                 "9x6", "9x7", "9x8", "9x9", "9xb", "9xc",
                 "9xd", "9xe", "9xf", "9xg", "9xh", "9xj",
                 "9xk", "9xm", "9xn", "9xp", "9xq", "9xr",
                 "9xs", "9xt", "9xu", "9xv", "9xw", "9xx",
                 "9xy", "9xz"))

  # Going down level by level should have same result as doing it all at once
  expect_equal(gh_fill("9w", 4L),
               gh_fill(
                 gh_fill("9w", 3L),
                 4L)
               )

  # Only Valid Characters
  expect_error(gh_fill("i9", 3L), 'Invalid Geohash; Valid characters: [0123456789bcdefghjkmnpqrstuvwxyz](any case)', fixed = TRUE)

})

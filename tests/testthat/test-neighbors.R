test_that('geohash adjacency list works', {
  my_turtle_beach = 'w0zpp8'
  ty_turtle_beach = 'sws374'
  xunantunich = 'd5095x0'

  expect_identical(
    gh_neighbors(my_turtle_beach, self = FALSE),
    list(
      southwest = 'w0znzr',
      south = 'w0znzx',
      southeast = 'w0znzz',
      west = 'w0zpp2',
      east = 'w0zppb',
      northwest = 'w0zpp3',
      north = 'w0zpp9',
      northeast = 'w0zppc'
    )
  )
  # commonwealthers *shakes fist*
  expect_identical(
    gh_neighbours(my_turtle_beach, self = FALSE),
    list(
      southwest = 'w0znzr',
      south = 'w0znzx',
      southeast = 'w0znzz',
      west = 'w0zpp2',
      east = 'w0zppb',
      northwest = 'w0zpp3',
      north = 'w0zpp9',
      northeast = 'w0zppc'
    )
  )

  # input precision doesn't matter; vectors work
  expect_identical(
    gh_neighbors(c(my_turtle_beach, ty_turtle_beach, xunantunich), self = FALSE),
    list(
      southwest = c('w0znzr', 'sws36c', 'd5095qz'),
      south = c('w0znzx', 'sws371', 'd5095wb'),
      southeast = c('w0znzz', 'sws373', 'd5095wc'),
      west = c('w0zpp2', 'sws36f', 'd5095rp'),
      east = c('w0zppb', 'sws376', 'd5095x1'),
      northwest = c('w0zpp3', 'sws36g', 'd5095rr'),
      north = c('w0zpp9', 'sws375', 'd5095x2'),
      northeast = c('w0zppc', 'sws377', 'd5095x3')
    )
  )

  # global boundary geohashes
  #   include a northern geohash whose top-level parent has no neighbor but
  #   which has a neighbor at that precision, #14
  expect_identical(
    gh_neighbors(c('5', 'u', 'pv', 'zry', 'z0'), self = FALSE),
    list(
      southwest = c(NA, 'e', 'ps', 'zrt', 'wz'),
      south = c(NA, 's', 'pu', 'zrw', 'xp'),
      southeast = c(NA, 't', '0h', 'zrx', 'xr'),
      west = c('4', 'g', 'pt', 'zrv', 'yb'),
      east = c('h', 'v', '0j', 'zrz', 'z2'),
      northwest = c('6', NA, 'pw', NA, 'yc'),
      north = c('7', NA, 'py', NA, 'z1'),
      northeast = c('k', NA, '0n', NA, 'z3')
    )
  )

  # option self = TRUE
  expect_identical(
    gh_neighbors(my_turtle_beach),
    list(
      self = my_turtle_beach,
      southwest = 'w0znzr',
      south = 'w0znzx',
      southeast = 'w0znzz',
      west = 'w0zpp2',
      east = 'w0zppb',
      northwest = 'w0zpp3',
      north = 'w0zpp9',
      northeast = 'w0zppc'
    )
  )

  # edge cases: invalid input
  expect_error(gh_neighbors('a'), 'Invalid geohash', fixed = TRUE)
  expect_identical(
    gh_neighbors(''),
    list(
      self='',
      southwest=NA_character_,
      south=NA_character_,
      southeast=NA_character_,
      west=NA_character_,
      east=NA_character_,
      northwest=NA_character_,
      north=NA_character_,
      northeast=NA_character_
    )
  )
})

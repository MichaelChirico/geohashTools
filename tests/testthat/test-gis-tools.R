test_that('gh_to_sf works', {
  skip_if_not_installed('sf')
  baku = c('tp5my', 'tp5mt', 'tp5mw', 'tp5mx', 'tp5mz', 'tp5qp', 'tp5qn', 'tp5qj', 'tp5mv')

  ghSF = gh_to_sf(baku)

  expect_s3_class(ghSF, 'sf')
  expect_identical(ghSF$ID, 1:9)
  expect_length(ghSF$geometry, 9L)

  expect_s3_class(ghSF$geometry[1L], 'sfc')
  expect_s3_class(ghSF$geometry[1L][[1L]], 'sfg')
  expect_identical(
    ghSF$geometry[1L][[1L]][[1L]],
    matrix(
      c(
        49.8339843750, 40.3857421875,
        49.8339843750, 40.4296875000,
        49.8779296875, 40.4296875000,
        49.8779296875, 40.3857421875,
        49.8339843750, 40.3857421875
      ),
      byrow = TRUE, ncol = 2L
    )
  )

  # duplicate inputs dropped (including mixed-case duplicates)
  expect_warning(
    expect_identical(gh_to_sf(c(baku, toupper(baku))), ghSF),
    'duplicate input geohashes',
    fixed = TRUE
  )
})

test_that('gh_to_sf.data.frame works', {
  skip_if_not_installed('sf')
  baku = c('tp5my', 'tp5mt', 'tp5mw', 'tp5mx', 'tp5mz', 'tp5qp', 'tp5qn', 'tp5qj', 'tp5mv')
  DF = data.frame(
    gh = baku,
    V = c(-1.08, 0.03, -0.68, -2.59, -0.02, 0.72, 0.68, 1.14, 0.47)
  )
  ghSF = gh_to_sf(DF)

  expect_s3_class(ghSF, 'sf')
  expect_identical(nrow(ghSF), 9L)
  expect_identical(ghSF$V, DF$V)

  # duplicated inputs
  expect_warning(
    expect_identical(gh_to_sf(rbind(DF, DF)), ghSF),
    'duplicate input geohashes',
    fixed = TRUE
  )

  # custom gh_col
  DF_custom = data.frame(geohash = baku, V = DF$V)
  expect_s3_class(gh_to_sf(DF_custom, gh_col = 'geohash'), 'sf')

  # missing gh_col
  expect_error(
    gh_to_sf(DF_custom),
    'Searched for geohashes at a column named "gh"',
    fixed = TRUE
  )
})

test_that('gh_covering works', {
  skip_if_not_installed('sf')
  banjarmasin = sf::st_as_sf(
    data.frame(
      lon = c(114.6050, 114.5716, 114.627, 114.5922, 114.6321, 114.5804, 114.6046, 114.6028, 114.6232, 114.5792),
      lat = c(-03.3346,  -3.2746, -3.2948,  -3.3424,  -3.3523,  -3.3304,  -3.3005,  -3.3141,  -3.3260,  -3.3552)
    ),
    coords = c('lon', 'lat'), crs = 4326L
  )

  # core
  banjarmasin_cover = gh_covering(banjarmasin)
  expect_false(anyNA(
    vapply(
      sf::st_intersects(banjarmasin, banjarmasin_cover),
      function(z) if (length(z) == 0L) NA_integer_ else z[1L],
      integer(1L)
    )
  ))
  expect_identical(
    sort(rownames(banjarmasin_cover))[1:10],
    c('qx3kzj', 'qx3kzm', 'qx3kzn', 'qx3kzp', 'qx3kzq', 'qx3kzr', 'qx3kzt', 'qx3kzv', 'qx3kzw', 'qx3kzx')
  )
  expect_length(banjarmasin_cover$geometry, 112L)

  # arguments
  expect_identical(nrow(gh_covering(banjarmasin, 5L)), 9L)
  banjarmasin_tight = gh_covering(banjarmasin, minimal = TRUE)
  expect_identical(
    sort(rownames(banjarmasin_tight))[1:10],
    c('qx3kzm', 'qx3kzx', 'qx3mp3', 'qx3mpb', 'qx3mpu', 'qx3mpz', 'qx3mr5', 'qx3sbt', 'qx3t06', 'qx3t22')
  )
  expect_identical(nrow(banjarmasin_tight), 10L)

  # sfg input and no-CRS warning
  pt_sfg = sf::st_point(c(114.605, -3.3346))
  expect_warning(
    cov_sfg <- gh_covering(pt_sfg, precision = 5L),
    'has no CRS defined',
    fixed = TRUE
  )
  expect_s3_class(cov_sfg, 'sf')

  # non-4326 input (e.g. EPSG:3857 Pseudo-Mercator)
  banjarmasin_3857 = sf::st_transform(banjarmasin, 3857L)
  cov_3857 = gh_covering(banjarmasin_3857, minimal = TRUE)
  expect_identical(sf::st_crs(cov_3857), sf::st_crs(3857L))
  expect_identical(nrow(cov_3857), nrow(banjarmasin_tight))

  # errors
  expect_error(gh_covering(4L), 'Object to cover must be sf', fixed = TRUE)
})

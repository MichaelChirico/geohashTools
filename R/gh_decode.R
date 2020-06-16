gh_decode = function(geohashes, include_delta = FALSE, coord_loc = 'c') {
  if (is.factor(geohashes)) {
    return(lapply(gh_decode(levels(geohashes), include_delta, coord_loc),
                  function(z) z[geohashes]))
  }
  if (length(coord_loc) > 1L)
    stop("Please provide only one value for 'coord_loc'")
  coord_loc = switch(
    tolower(coord_loc),
    'southwest' = , 'sw' = 0L,
    'south' = , 's' = 1L,
    'southeast' = , 'se' = 2L,
    'west' = , 'w' = 3L,
    'centroid' = , 'center' = , 'middle' = , 'c' = 4L,
    'east' = , 'e' = 5L,
    'northwest' = , 'nw' = 6L,
    'north' = , 'n' = 7L,
    'northeast' = , 'ne' = 8L,
    stop('Unrecognized coordinate location; please use ',
         "'c' for centroid or a cardinal direction; see ?gh_decode")
  )
  .Call(Cgh_decode, geohashes, include_delta, coord_loc)
}

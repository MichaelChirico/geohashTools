gh_fill <- function(geohashes, precision) {
  if (length(unique(nchar(geohashes))) > 1) {
    stop("Input Geohashes must all have the same precision level.")
  }
  if (any(grepl("['ailoAILO]", geohashes))) {
    stop("Invalid Geohash; Valid characters: [0123456789bcdefghjkmnpqrstuvwxyz](any case)")
  }
  new_levels <- precision - nchar(geohashes[1])
  base32 <-
    unlist(strsplit("0123456789bcdefghjkmnpqrstuvwxyz", split = ""))
  grid <-
    do.call(data.table::CJ, append(list(geohashes), replicate(new_levels, base32, FALSE)))
  do.call(paste0, grid)
}

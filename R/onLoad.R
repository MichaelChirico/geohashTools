#Internal globals
# nocov start
.global = new.env(parent = emptyenv())
setPackageName('geohashTools', .global)

.onLoad <- function(libname, pkgname) {
  # 64-bit integer can fit lat&lon components in 5 bits per 2 units precision
  .global$GH_MAX_PRECISION = 25L
}
# nocov end

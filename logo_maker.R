library(sf)
library(data.table)
library(viridis)

diamond1 = cbind(c(0, 40*sqrt(3), 40*sqrt(3), 0, 0),
                 c(0, 40, -40, -80, 0))
diamond2 = cbind(c(0, -40*sqrt(3), -40*sqrt(3), 0, 0),
                 c(0, 40, -40, -80, 0))
diamond3 = cbind(c(0, 40*sqrt(3), 0, -40*sqrt(3), 0),
                 c(80, 40, 0, 40, 80))

hexSF = st_sf(
  diamond_id = 1:3,
  geometry = st_sfc(
    st_polygon(list(diamond1)),
    st_polygon(list(diamond2)),
    st_polygon(list(diamond3))
  )
)

base32 = c(0:9, setdiff(letters, c('a', 'i', 'l', 'o')))
gh2 = do.call(paste0, expand.grid(base32, base32))
grd = gh_decode(gh2, include_delta = TRUE)

polys = lapply(seq_along(grd$latitude), function(ii) {
  y = grd$latitude[ii] + c(-1, -1, 1, 1, -1) * grd$delta_latitude[1L]
  x = grd$longitude[ii] + c(-1, 1, 1, -1, -1) * grd$delta_longitude[2L]
  st_polygon(list(cbind(x, y)))
})
grdSF = st_sf(grid_id = seq_along(polys), geometry = st_sfc(polys))

hex_union = st_union(hexSF)
grdSF = grdSF[st_intersects(grdSF, hex_union, sparse = FALSE), ]

grd_diamond = st_intersection(grdSF, hexSF)
grd_diamond$area = as.numeric(st_area(grd_diamond))

intDT = as.data.table(grd_diamond)
areaDT = intDT[ , keyby = .(grid_id), .(diamond = diamond_id[which.max(area)])]

grdSF = merge(grdSF, areaDT, by = "grid_id")

# kilt-y option
plot(st_geometry(grd_diamond), col = viridis(nrow(grd_diamond)), border = NA)
plot(st_geometry(hexSF), lwd = 5L, add = TRUE)

# lego option
quartzFonts(
  avenir = c("Avenir Next Condensed Medium", "Avenir Black",
             "Avenir Book Oblique", "Avenir Black Oblique")
)
plot(st_geometry(grdSF), col = viridis(3L)[grdSF$diamond], border = NA)
text(0, 40, labels = 'geohashTools', col = 'red',
     family = 'avenir', font = 4L, cex = 3)

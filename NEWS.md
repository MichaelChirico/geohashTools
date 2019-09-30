# `geohashTools` NEWS

## v0.3.1

### BUG FIXES

 1. `gh_decode` errors early on non-ASCII input to prevent out-of-memory access, [#19](https://github.com/MichaelChirico/geohashTools/issues/19).

## v0.3.0

### NEW FEATURES

 1. Complete overhaul of source code; C++ --> C & changed algorithm
 
### BUG FIXES

 1. `gh_neighbors` incorrectly returned `NA` for geohashes whose first component is a boundary but whose higher components do indeed have neighbors, [#14](https://github.com/MichaelChirico/geohashTools/issues/14).

## v0.2.5

### NEW FEATURES

 1. `gh_covering` works with input from `sf`. Thanks to @dshkol for the PR.

### BUG FIXES

 1. `gh_covering` failed on input with missing `proj4string`, [#13](https://github.com/MichaelChirico/geohashTools/issues/13). Thanks @dshkol for the report.

## v0.2.4

### BUG FIXES

 1. CRAN submission again detected memory issues (accessing memory beyond which was declared for an array), reproduced & fixed for [#6](https://github.com/MichaelChirico/geohashTools/issues/6); the original fix also led to an uninitialized access error, [#12](https://github.com/MichaelChirico/geohashTools/issues/12).
 
 2. CRAN submission also detected a type mismatch error, [#11](https://github.com/MichaelChirico/geohashTools/issues/11).

## v0.2.2

### NEW FEATURES

 1. `gh_covering` for generating a covering of an input polygon in geohashes, [#4](https://github.com/MichaelChirico/geohashTools/issues/4).

### BUG FIXES

 1. CRAN submission detected some memory issues in the C++ code which have now hopefully been fixed for [#6](https://github.com/MichaelChirico/geohashTools/issues/6).
 
 2. `gh_to_spdf` failed with duplicate inputs, [#8](https://github.com/MichaelChirico/geohashTools/issues/8). Duplicates are removed with warning.
 
 3. `gh_neighbors('')` failed, [#9](https://github.com/MichaelChirico/geohashTools/issues/9).

# Updates only tracked here since v0.2.2

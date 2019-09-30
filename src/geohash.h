#include <R.h>
#include <stdint.h> // for uint64_t
#include <stdbool.h> // for bool type & values
#include <Rinternals.h>

SEXP gh_encode(SEXP y, SEXP x, SEXP k_arg);
SEXP gh_decode(SEXP gh, SEXP include_delta_arg, SEXP coord_loc);
SEXP gh_neighbors(SEXP gh, SEXP self_arg);

// ** FOR ENCODING **
// geohash orientation rotates from Z order (odd) to N order (even)
static const char map[4][9] = {
  "0145hjnp",
  "2367kmqr",
  "89destwx",
  "bcfguvyz"
};

// increase the exponent by 2 or 3 (multiply by 4 or 8) in IEEE 754 representation
static const uint64_t mult4 = 2ULL << 52;
static const uint64_t mult8 = 3ULL << 52;

// ** FOR DECODING **
// offsets relative to LHS of the _longer_ side of the 8x4 (or 4x8) geohash rectangle
static const int offset8[128] = {
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
        0,        1,        0,        1,        2,        3,       2,         3,
        0,        1,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,        0,        1,        2,        3,       2,         3,
        4,  INT_MIN,        5,        4,  INT_MIN,        5,       6,   INT_MIN,
        7,        6,        7,        4,        5,        4,       5,         6,
        7,        6,        7,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,        0,        1,        2,        3,       2,         3,
        4,  INT_MIN,        5,        4,  INT_MIN,        5,       6,   INT_MIN,
        7,        6,        7,        4,        5,        4,       5,         6,
        7,        6,        7,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
};
// offsets relative to LHS of the _shorter_ side of the 8x4 (or 4x8) geohash rectangle
static const int offset4 [128] = {
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
        0,        0,        1,        1,        0,        0,       1,         1,
        2,        2,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,        3,        3,        2,        2,       3,         3,
        0,  INT_MIN,        0,        1,  INT_MIN,        1,       0,   INT_MIN,
        0,        1,        1,        2,        2,        3,       3,         2,
        2,        3,        3,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
  INT_MIN,  INT_MIN,        3,        3,        2,        2,       3,         3,
        0,  INT_MIN,        0,        1,  INT_MIN,        1,       0,   INT_MIN,
        0,        1,        1,        2,        2,        3,       3,         2,
        2,        3,        3,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,  INT_MIN,
};

static const int centeroffx[9] = {0, 1, 2, 0, 1, 2, 0, 1, 2};
static const int centeroffy[9] = {0, 0, 0, 1, 1, 1, 2, 2, 2};

static const char nbhd_nm[9][10] = {
  "southwest", "south", "southeast",
       "west",  "self",      "east",
  "northwest", "north", "northeast"
};

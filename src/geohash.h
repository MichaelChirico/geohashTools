#include <R.h>
#include <stdint.h> // for uint64_t
#include <stdbool.h> // for bool type & values
#include <Rinternals.h>

SEXP gh_encode(SEXP y, SEXP x, SEXP k_arg);
SEXP gh_decode(SEXP gh, SEXP include_delta_arg, SEXP coord_loc);
SEXP gh_neighbors(SEXP gh, SEXP self_arg);

// utils.c
int check_range(unsigned char * ch);

// ** FOR ENCODING **
// NB geohash orientation rotates from Z order (odd) to N order (even)
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
// see cat(rawToChar(as.raw(13:127)))
// and/or charToRaw('0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
#define _ INT_MIN // for conciseness
static const int offset8[128] = {
  _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, // 00-0f
  _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, // 10-1f
  _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, // 20-2f
  0, 1, 0, 1, 2, 3, 2, 3, 0, 1, _, _, _, _, _, _, // 30-3f : 0-9
  _, _, 0, 1, 2, 3, 2, 3, 4, _, 5, 4, _, 5, 6, _, // 40-4f : B-HJKMN
  7, 6, 7, 4, 5, 4, 5, 6, 7, 6, 7, _, _, _, _, _, // 50-5f : P-Z
  _, _, 0, 1, 2, 3, 2, 3, 4, _, 5, 4, _, 5, 6, _, // 60-6f : a-hjkmn
  7, 6, 7, 4, 5, 4, 5, 6, 7, 6, 7, _, _, _, _, _, // 70-7f : p-z
};
// offsets relative to LHS of the _shorter_ side of the 8x4 (or 4x8) geohash rectangle
static const int offset4[128] = {
  _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _,
  _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _,
  _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _,
  0, 0, 1, 1, 0, 0, 1, 1, 2, 2, _, _, _, _, _, _,
  _, _, 3, 3, 2, 2, 3, 3, 0, _, 0, 1, _, 1, 0, _,
  0, 1, 1, 2, 2, 3, 3, 2, 2, 3, 3, _, _, _, _, _,
  _, _, 3, 3, 2, 2, 3, 3, 0, _, 0, 1, _, 1, 0, _,
  0, 1, 1, 2, 2, 3, 3, 2, 2, 3, 3, _, _, _, _, _,
};
#undef _

static const int centeroffx[9] = {0, 1, 2, 0, 1, 2, 0, 1, 2};
static const int centeroffy[9] = {0, 0, 0, 1, 1, 1, 2, 2, 2};

static const char nbhd_nm[9][10] = {
  "southwest", "south", "southeast",
       "west",  "self",      "east",
  "northwest", "north", "northeast"
};

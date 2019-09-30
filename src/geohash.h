#include <R.h>
#include <stdint.h> // for uint64_t
#include <stdbool.h> // for bool type & values
#include <Rinternals.h>

SEXP gh_encode(SEXP y, SEXP x, SEXP k_arg);
SEXP gh_decode(SEXP gh, SEXP include_delta_arg, SEXP coord_loc);
SEXP gh_neighbors(SEXP gh, SEXP self_arg);

// utils.c
int char_idx(const char * ch);

// ** FOR ENCODING **
// NB geohash orientation rotates from Z order (odd) to N order (even)
static const char map[4][9] = {
  "0145hjnp",
  "2367kmqr",
  "89destwx",
  "bcfguvyz"
};

// increase the exponent by 2 or 3 (multiply by 4 or 8) in IEEE 754 representation
static const uint64_t mult4  = 2ULL << 52;
static const uint64_t mult8  = 3ULL << 52;
static const uint64_t mult32 = 5ULL << 52;

// ** FOR DECODING **
// see cat(rawToChar(as.raw(13:127)))
// and/or charToRaw('0123456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ')
/*
Code to generate the body here:
library(data.table)
m = matrix(as.integer(intToBits(0:31)), nrow = 32L)[5:1, ]
lookup = cbind(c(1L, 3L, 5L, 2L, 4L, 2L, 4L, 1L, 3L, 5L),
               c(1L, 1L, 1L, 2L, 2L, 1L, 1L, 2L, 2L, 2L))
base32 = strsplit('0123456789bcdefghjkmnpqrstuvwxyz', NULL)[[1L]]
colnames(m) = base32

DT = CJ(c1 = base32, c2 = base32)

get_idx = function(x) tapply(m[ , x][lookup]*2L^c(4:0, 4:0), gl(2L, 5L), sum)
for (ii in 1:nrow(DT)) DT[ii, c('x', 'y') := as.list(get_idx(c(c1, c2)))]
DT[ , arr := sprintf('{%2d, %2d}', x, y)]
DT[ , by = c1, cat('  {', apply(matrix(arr, ncol = 4L), 2L, function(x) {
  paste(
    `[<-`(x, c(1L, 8L), c(sprintf('    %s', x[1L]), sprintf('%s,', x[8L]))),
    collapse = ', '
  )
}), '  },', sep = '\n')]
*/
static const int offset[35][35][2] =
{
  {
    { 0,  0}, { 0,  1}, { 1,  0}, { 1,  1}, { 0,  2}, { 0,  3}, { 1,  2}, { 1,  3},
    { 2,  0}, { 2,  1}, { 3,  0}, { 3,  1}, { 2,  2}, { 2,  3}, { 3,  2}, { 3,  3},
    { 0,  4}, { 0,  5}, { 1,  4}, { 1,  5}, { 0,  6}, { 0,  7}, { 1,  6}, { 1,  7},
    { 2,  4}, { 2,  5}, { 3,  4}, { 3,  5}, { 2,  6}, { 2,  7}, { 3,  6}, { 3,  7},
  },
  {
    { 4,  0}, { 4,  1}, { 5,  0}, { 5,  1}, { 4,  2}, { 4,  3}, { 5,  2}, { 5,  3},
    { 6,  0}, { 6,  1}, { 7,  0}, { 7,  1}, { 6,  2}, { 6,  3}, { 7,  2}, { 7,  3},
    { 4,  4}, { 4,  5}, { 5,  4}, { 5,  5}, { 4,  6}, { 4,  7}, { 5,  6}, { 5,  7},
    { 6,  4}, { 6,  5}, { 7,  4}, { 7,  5}, { 6,  6}, { 6,  7}, { 7,  6}, { 7,  7},
  },
  {
    { 0,  8}, { 0,  9}, { 1,  8}, { 1,  9}, { 0, 10}, { 0, 11}, { 1, 10}, { 1, 11},
    { 2,  8}, { 2,  9}, { 3,  8}, { 3,  9}, { 2, 10}, { 2, 11}, { 3, 10}, { 3, 11},
    { 0, 12}, { 0, 13}, { 1, 12}, { 1, 13}, { 0, 14}, { 0, 15}, { 1, 14}, { 1, 15},
    { 2, 12}, { 2, 13}, { 3, 12}, { 3, 13}, { 2, 14}, { 2, 15}, { 3, 14}, { 3, 15},
  },
  {
    { 4,  8}, { 4,  9}, { 5,  8}, { 5,  9}, { 4, 10}, { 4, 11}, { 5, 10}, { 5, 11},
    { 6,  8}, { 6,  9}, { 7,  8}, { 7,  9}, { 6, 10}, { 6, 11}, { 7, 10}, { 7, 11},
    { 4, 12}, { 4, 13}, { 5, 12}, { 5, 13}, { 4, 14}, { 4, 15}, { 5, 14}, { 5, 15},
    { 6, 12}, { 6, 13}, { 7, 12}, { 7, 13}, { 6, 14}, { 6, 15}, { 7, 14}, { 7, 15},
  },
  {
    { 8,  0}, { 8,  1}, { 9,  0}, { 9,  1}, { 8,  2}, { 8,  3}, { 9,  2}, { 9,  3},
    {10,  0}, {10,  1}, {11,  0}, {11,  1}, {10,  2}, {10,  3}, {11,  2}, {11,  3},
    { 8,  4}, { 8,  5}, { 9,  4}, { 9,  5}, { 8,  6}, { 8,  7}, { 9,  6}, { 9,  7},
    {10,  4}, {10,  5}, {11,  4}, {11,  5}, {10,  6}, {10,  7}, {11,  6}, {11,  7},
  },
  {
    {12,  0}, {12,  1}, {13,  0}, {13,  1}, {12,  2}, {12,  3}, {13,  2}, {13,  3},
    {14,  0}, {14,  1}, {15,  0}, {15,  1}, {14,  2}, {14,  3}, {15,  2}, {15,  3},
    {12,  4}, {12,  5}, {13,  4}, {13,  5}, {12,  6}, {12,  7}, {13,  6}, {13,  7},
    {14,  4}, {14,  5}, {15,  4}, {15,  5}, {14,  6}, {14,  7}, {15,  6}, {15,  7},
  },
  {
    { 8,  8}, { 8,  9}, { 9,  8}, { 9,  9}, { 8, 10}, { 8, 11}, { 9, 10}, { 9, 11},
    {10,  8}, {10,  9}, {11,  8}, {11,  9}, {10, 10}, {10, 11}, {11, 10}, {11, 11},
    { 8, 12}, { 8, 13}, { 9, 12}, { 9, 13}, { 8, 14}, { 8, 15}, { 9, 14}, { 9, 15},
    {10, 12}, {10, 13}, {11, 12}, {11, 13}, {10, 14}, {10, 15}, {11, 14}, {11, 15},
  },
  {
    {12,  8}, {12,  9}, {13,  8}, {13,  9}, {12, 10}, {12, 11}, {13, 10}, {13, 11},
    {14,  8}, {14,  9}, {15,  8}, {15,  9}, {14, 10}, {14, 11}, {15, 10}, {15, 11},
    {12, 12}, {12, 13}, {13, 12}, {13, 13}, {12, 14}, {12, 15}, {13, 14}, {13, 15},
    {14, 12}, {14, 13}, {15, 12}, {15, 13}, {14, 14}, {14, 15}, {15, 14}, {15, 15},
  },
  {
    { 0, 16}, { 0, 17}, { 1, 16}, { 1, 17}, { 0, 18}, { 0, 19}, { 1, 18}, { 1, 19},
    { 2, 16}, { 2, 17}, { 3, 16}, { 3, 17}, { 2, 18}, { 2, 19}, { 3, 18}, { 3, 19},
    { 0, 20}, { 0, 21}, { 1, 20}, { 1, 21}, { 0, 22}, { 0, 23}, { 1, 22}, { 1, 23},
    { 2, 20}, { 2, 21}, { 3, 20}, { 3, 21}, { 2, 22}, { 2, 23}, { 3, 22}, { 3, 23},
  },
  {
    { 4, 16}, { 4, 17}, { 5, 16}, { 5, 17}, { 4, 18}, { 4, 19}, { 5, 18}, { 5, 19},
    { 6, 16}, { 6, 17}, { 7, 16}, { 7, 17}, { 6, 18}, { 6, 19}, { 7, 18}, { 7, 19},
    { 4, 20}, { 4, 21}, { 5, 20}, { 5, 21}, { 4, 22}, { 4, 23}, { 5, 22}, { 5, 23},
    { 6, 20}, { 6, 21}, { 7, 20}, { 7, 21}, { 6, 22}, { 6, 23}, { 7, 22}, { 7, 23},
  },
  {
    { 0, 24}, { 0, 25}, { 1, 24}, { 1, 25}, { 0, 26}, { 0, 27}, { 1, 26}, { 1, 27},
    { 2, 24}, { 2, 25}, { 3, 24}, { 3, 25}, { 2, 26}, { 2, 27}, { 3, 26}, { 3, 27},
    { 0, 28}, { 0, 29}, { 1, 28}, { 1, 29}, { 0, 30}, { 0, 31}, { 1, 30}, { 1, 31},
    { 2, 28}, { 2, 29}, { 3, 28}, { 3, 29}, { 2, 30}, { 2, 31}, { 3, 30}, { 3, 31},
  },
  {
    { 4, 24}, { 4, 25}, { 5, 24}, { 5, 25}, { 4, 26}, { 4, 27}, { 5, 26}, { 5, 27},
    { 6, 24}, { 6, 25}, { 7, 24}, { 7, 25}, { 6, 26}, { 6, 27}, { 7, 26}, { 7, 27},
    { 4, 28}, { 4, 29}, { 5, 28}, { 5, 29}, { 4, 30}, { 4, 31}, { 5, 30}, { 5, 31},
    { 6, 28}, { 6, 29}, { 7, 28}, { 7, 29}, { 6, 30}, { 6, 31}, { 7, 30}, { 7, 31},
  },
  {
    { 8, 16}, { 8, 17}, { 9, 16}, { 9, 17}, { 8, 18}, { 8, 19}, { 9, 18}, { 9, 19},
    {10, 16}, {10, 17}, {11, 16}, {11, 17}, {10, 18}, {10, 19}, {11, 18}, {11, 19},
    { 8, 20}, { 8, 21}, { 9, 20}, { 9, 21}, { 8, 22}, { 8, 23}, { 9, 22}, { 9, 23},
    {10, 20}, {10, 21}, {11, 20}, {11, 21}, {10, 22}, {10, 23}, {11, 22}, {11, 23},
  },
  {
    {12, 16}, {12, 17}, {13, 16}, {13, 17}, {12, 18}, {12, 19}, {13, 18}, {13, 19},
    {14, 16}, {14, 17}, {15, 16}, {15, 17}, {14, 18}, {14, 19}, {15, 18}, {15, 19},
    {12, 20}, {12, 21}, {13, 20}, {13, 21}, {12, 22}, {12, 23}, {13, 22}, {13, 23},
    {14, 20}, {14, 21}, {15, 20}, {15, 21}, {14, 22}, {14, 23}, {15, 22}, {15, 23},
  },
  {
    { 8, 24}, { 8, 25}, { 9, 24}, { 9, 25}, { 8, 26}, { 8, 27}, { 9, 26}, { 9, 27},
    {10, 24}, {10, 25}, {11, 24}, {11, 25}, {10, 26}, {10, 27}, {11, 26}, {11, 27},
    { 8, 28}, { 8, 29}, { 9, 28}, { 9, 29}, { 8, 30}, { 8, 31}, { 9, 30}, { 9, 31},
    {10, 28}, {10, 29}, {11, 28}, {11, 29}, {10, 30}, {10, 31}, {11, 30}, {11, 31},
  },
  {
    {12, 24}, {12, 25}, {13, 24}, {13, 25}, {12, 26}, {12, 27}, {13, 26}, {13, 27},
    {14, 24}, {14, 25}, {15, 24}, {15, 25}, {14, 26}, {14, 27}, {15, 26}, {15, 27},
    {12, 28}, {12, 29}, {13, 28}, {13, 29}, {12, 30}, {12, 31}, {13, 30}, {13, 31},
    {14, 28}, {14, 29}, {15, 28}, {15, 29}, {14, 30}, {14, 31}, {15, 30}, {15, 31},
  },
  {
    {16,  0}, {16,  1}, {17,  0}, {17,  1}, {16,  2}, {16,  3}, {17,  2}, {17,  3},
    {18,  0}, {18,  1}, {19,  0}, {19,  1}, {18,  2}, {18,  3}, {19,  2}, {19,  3},
    {16,  4}, {16,  5}, {17,  4}, {17,  5}, {16,  6}, {16,  7}, {17,  6}, {17,  7},
    {18,  4}, {18,  5}, {19,  4}, {19,  5}, {18,  6}, {18,  7}, {19,  6}, {19,  7},
  },
  {
    {20,  0}, {20,  1}, {21,  0}, {21,  1}, {20,  2}, {20,  3}, {21,  2}, {21,  3},
    {22,  0}, {22,  1}, {23,  0}, {23,  1}, {22,  2}, {22,  3}, {23,  2}, {23,  3},
    {20,  4}, {20,  5}, {21,  4}, {21,  5}, {20,  6}, {20,  7}, {21,  6}, {21,  7},
    {22,  4}, {22,  5}, {23,  4}, {23,  5}, {22,  6}, {22,  7}, {23,  6}, {23,  7},
  },
  {
    {16,  8}, {16,  9}, {17,  8}, {17,  9}, {16, 10}, {16, 11}, {17, 10}, {17, 11},
    {18,  8}, {18,  9}, {19,  8}, {19,  9}, {18, 10}, {18, 11}, {19, 10}, {19, 11},
    {16, 12}, {16, 13}, {17, 12}, {17, 13}, {16, 14}, {16, 15}, {17, 14}, {17, 15},
    {18, 12}, {18, 13}, {19, 12}, {19, 13}, {18, 14}, {18, 15}, {19, 14}, {19, 15},
  },
  {
    {20,  8}, {20,  9}, {21,  8}, {21,  9}, {20, 10}, {20, 11}, {21, 10}, {21, 11},
    {22,  8}, {22,  9}, {23,  8}, {23,  9}, {22, 10}, {22, 11}, {23, 10}, {23, 11},
    {20, 12}, {20, 13}, {21, 12}, {21, 13}, {20, 14}, {20, 15}, {21, 14}, {21, 15},
    {22, 12}, {22, 13}, {23, 12}, {23, 13}, {22, 14}, {22, 15}, {23, 14}, {23, 15},
  },
  {
    {24,  0}, {24,  1}, {25,  0}, {25,  1}, {24,  2}, {24,  3}, {25,  2}, {25,  3},
    {26,  0}, {26,  1}, {27,  0}, {27,  1}, {26,  2}, {26,  3}, {27,  2}, {27,  3},
    {24,  4}, {24,  5}, {25,  4}, {25,  5}, {24,  6}, {24,  7}, {25,  6}, {25,  7},
    {26,  4}, {26,  5}, {27,  4}, {27,  5}, {26,  6}, {26,  7}, {27,  6}, {27,  7},
  },
  {
    {28,  0}, {28,  1}, {29,  0}, {29,  1}, {28,  2}, {28,  3}, {29,  2}, {29,  3},
    {30,  0}, {30,  1}, {31,  0}, {31,  1}, {30,  2}, {30,  3}, {31,  2}, {31,  3},
    {28,  4}, {28,  5}, {29,  4}, {29,  5}, {28,  6}, {28,  7}, {29,  6}, {29,  7},
    {30,  4}, {30,  5}, {31,  4}, {31,  5}, {30,  6}, {30,  7}, {31,  6}, {31,  7},
  },
  {
    {24,  8}, {24,  9}, {25,  8}, {25,  9}, {24, 10}, {24, 11}, {25, 10}, {25, 11},
    {26,  8}, {26,  9}, {27,  8}, {27,  9}, {26, 10}, {26, 11}, {27, 10}, {27, 11},
    {24, 12}, {24, 13}, {25, 12}, {25, 13}, {24, 14}, {24, 15}, {25, 14}, {25, 15},
    {26, 12}, {26, 13}, {27, 12}, {27, 13}, {26, 14}, {26, 15}, {27, 14}, {27, 15},
  },
  {
    {28,  8}, {28,  9}, {29,  8}, {29,  9}, {28, 10}, {28, 11}, {29, 10}, {29, 11},
    {30,  8}, {30,  9}, {31,  8}, {31,  9}, {30, 10}, {30, 11}, {31, 10}, {31, 11},
    {28, 12}, {28, 13}, {29, 12}, {29, 13}, {28, 14}, {28, 15}, {29, 14}, {29, 15},
    {30, 12}, {30, 13}, {31, 12}, {31, 13}, {30, 14}, {30, 15}, {31, 14}, {31, 15},
  },
  {
    {16, 16}, {16, 17}, {17, 16}, {17, 17}, {16, 18}, {16, 19}, {17, 18}, {17, 19},
    {18, 16}, {18, 17}, {19, 16}, {19, 17}, {18, 18}, {18, 19}, {19, 18}, {19, 19},
    {16, 20}, {16, 21}, {17, 20}, {17, 21}, {16, 22}, {16, 23}, {17, 22}, {17, 23},
    {18, 20}, {18, 21}, {19, 20}, {19, 21}, {18, 22}, {18, 23}, {19, 22}, {19, 23},
  },
  {
    {20, 16}, {20, 17}, {21, 16}, {21, 17}, {20, 18}, {20, 19}, {21, 18}, {21, 19},
    {22, 16}, {22, 17}, {23, 16}, {23, 17}, {22, 18}, {22, 19}, {23, 18}, {23, 19},
    {20, 20}, {20, 21}, {21, 20}, {21, 21}, {20, 22}, {20, 23}, {21, 22}, {21, 23},
    {22, 20}, {22, 21}, {23, 20}, {23, 21}, {22, 22}, {22, 23}, {23, 22}, {23, 23},
  },
  {
    {16, 24}, {16, 25}, {17, 24}, {17, 25}, {16, 26}, {16, 27}, {17, 26}, {17, 27},
    {18, 24}, {18, 25}, {19, 24}, {19, 25}, {18, 26}, {18, 27}, {19, 26}, {19, 27},
    {16, 28}, {16, 29}, {17, 28}, {17, 29}, {16, 30}, {16, 31}, {17, 30}, {17, 31},
    {18, 28}, {18, 29}, {19, 28}, {19, 29}, {18, 30}, {18, 31}, {19, 30}, {19, 31},
  },
  {
    {20, 24}, {20, 25}, {21, 24}, {21, 25}, {20, 26}, {20, 27}, {21, 26}, {21, 27},
    {22, 24}, {22, 25}, {23, 24}, {23, 25}, {22, 26}, {22, 27}, {23, 26}, {23, 27},
    {20, 28}, {20, 29}, {21, 28}, {21, 29}, {20, 30}, {20, 31}, {21, 30}, {21, 31},
    {22, 28}, {22, 29}, {23, 28}, {23, 29}, {22, 30}, {22, 31}, {23, 30}, {23, 31},
  },
  {
    {24, 16}, {24, 17}, {25, 16}, {25, 17}, {24, 18}, {24, 19}, {25, 18}, {25, 19},
    {26, 16}, {26, 17}, {27, 16}, {27, 17}, {26, 18}, {26, 19}, {27, 18}, {27, 19},
    {24, 20}, {24, 21}, {25, 20}, {25, 21}, {24, 22}, {24, 23}, {25, 22}, {25, 23},
    {26, 20}, {26, 21}, {27, 20}, {27, 21}, {26, 22}, {26, 23}, {27, 22}, {27, 23},
  },
  {
    {28, 16}, {28, 17}, {29, 16}, {29, 17}, {28, 18}, {28, 19}, {29, 18}, {29, 19},
    {30, 16}, {30, 17}, {31, 16}, {31, 17}, {30, 18}, {30, 19}, {31, 18}, {31, 19},
    {28, 20}, {28, 21}, {29, 20}, {29, 21}, {28, 22}, {28, 23}, {29, 22}, {29, 23},
    {30, 20}, {30, 21}, {31, 20}, {31, 21}, {30, 22}, {30, 23}, {31, 22}, {31, 23},
  },
  {
    {24, 24}, {24, 25}, {25, 24}, {25, 25}, {24, 26}, {24, 27}, {25, 26}, {25, 27},
    {26, 24}, {26, 25}, {27, 24}, {27, 25}, {26, 26}, {26, 27}, {27, 26}, {27, 27},
    {24, 28}, {24, 29}, {25, 28}, {25, 29}, {24, 30}, {24, 31}, {25, 30}, {25, 31},
    {26, 28}, {26, 29}, {27, 28}, {27, 29}, {26, 30}, {26, 31}, {27, 30}, {27, 31},
  },
  {
    {28, 24}, {28, 25}, {29, 24}, {29, 25}, {28, 26}, {28, 27}, {29, 26}, {29, 27},
    {30, 24}, {30, 25}, {31, 24}, {31, 25}, {30, 26}, {30, 27}, {31, 26}, {31, 27},
    {28, 28}, {28, 29}, {29, 28}, {29, 29}, {28, 30}, {28, 31}, {29, 30}, {29, 31},
    {30, 28}, {30, 29}, {31, 28}, {31, 29}, {30, 30}, {30, 31}, {31, 30}, {31, 31},
  }
};

static const int centeroffx[9] = {0, 1, 2, 0, 1, 2, 0, 1, 2};
static const int centeroffy[9] = {0, 0, 0, 1, 1, 1, 2, 2, 2};

static const char nbhd_nm[9][10] = {
  "southwest", "south", "southeast",
       "west",  "self",      "east",
  "northwest", "north", "northeast"
};

#include "geohash.h"
/*
Approach/Logic for Geohash Neighbors

Geohash is simultaneously base 32 and (base 8)x(base 4):
 __________________________________
 | GH | base-32 | base-8 | base-4 |
 |----+---------+--------+--------|
 |  0 |   00000 |    000 |     00 |
 |  1 |   00001 |    001 |     00 |
 |  2 |   00010 |    000 |     01 |
 |  3 |   00011 |    001 |     01 |
 |  4 |   00100 |    010 |     00 |
 |  5 |   00101 |    011 |     00 |
 |  6 |   00110 |    010 |     01 |
 |  7 |   00111 |    011 |     01 |
 |  8 |   01000 |    000 |     10 |
 |  9 |   01001 |    001 |     10 |
 |  b |   01010 |    000 |     11 |
 |  c |   01011 |    001 |     11 |
 |  d |   01100 |    010 |     10 |
 |  e |   01101 |    011 |     11 |    01101 <--> 0 1 1 base 8
 |  f |   01110 |    010 |     11 |  base 32       1 0  base 4
 |  g |   01111 |    011 |     11 |
 |  h |   10000 |    100 |     00 |
 |  j |   10001 |    101 |     00 |
 |  k |   10010 |    100 |     01 |
 |  m |   10011 |    101 |     01 |
 |  n |   10100 |    110 |     00 |
 |  p |   10101 |    111 |     00 |
 |  q |   10110 |    110 |     01 |
 |  r |   10111 |    111 |     01 |
 |  s |   11000 |    100 |     10 |
 |  t |   11001 |    101 |     10 |
 |  u |   11010 |    100 |     11 |
 |  v |   11011 |    101 |     11 |
 |  w |   11100 |    110 |     10 |
 |  x |   11101 |    111 |     11 |
 |  y |   11110 |    110 |     11 |
 |  z |   11111 |    111 |     11 |
 ``````````````````````````````````
The base-8 value gives the coordinate in the "wide" direction
  (east-west for 0-indexed even precisions, north-south for odd precisions)
The base-4 value gives the coordinate in the "narrow" direction (opposite)

To find the neighbor to the west, we have to subtract 1 from the
  accumulated binary longitude coordinate. This works across & within
  geohash boundaries, like so:

Easy for an "internal" geohash whose neighbors share all but the last character:

s6 =   s   -   6
   = 11000 - 00110
   = 1 0 0 -  0 1  | longitude
      1 0    0 1 0 | latitude
  -> 1 0 0 -  0 0  | reduce longitude by 1
      1 0    0 1 0
   = 01101 - 00100 | reconstitute
   =   s   -   4

This also applies to "border" geohashes whose neighbors look totally different:

s0 =   s   -   0
   = 11000 - 00000
   = 1 0 0 -  0 0  | longitude
      1 0    0 0 0 | latitude
  -> 0 1 1 -  1 1  | reduce longitude by 1
      1 0    0 0 0
   = 01101 - 01010 | reconstitute
   =   e   -   b

Corner geohashes will be all 0 or all 1 in that dimension:

bpbp =   b   -   p   -   b   -   p
     = 01010 - 10101 - 01010 - 10101
     = 0 0 0 -  0 0  - 0 0 0 -  0 0  | <- all 0 --> no western neighbor
     =  1 1  - 1 1 1 -  1 1  - 1 1 1 | <- all 1 --> no northern neighbor

In terms of storage, to track the lat/lon binary components, we need
  5 bits for every 2 units of precision, which means we can use this
  approach for up to 25 units of precision --> 62 bits latitude, 63 longitude
  TODO: mostly (up to 12 units precision) we would be fine with 4-byte storage
*/
SEXP gh_neighbors(SEXP gh, SEXP self_arg) {
  const int n = length(gh);

  int nprotect=0, coli=0;
  bool self = LOGICAL(self_arg)[0];

  SEXP out = PROTECT(allocVector(VECSXP, self ? 9 : 8)); nprotect++;
  SEXP outNm = PROTECT(allocVector(STRSXP, self ? 9 : 8)); nprotect++;
  if (self) {
    SET_VECTOR_ELT(out, coli, gh);
    SET_STRING_ELT(outNm, coli++, mkChar("self"));
  }
  SEXP nbhd[9];
  for (int m=0; m<9; m++) {
    // skip the cell corresponding to "self"
    if (m == 4) continue;
    nbhd[m] = PROTECT(allocVector(STRSXP, n)); nprotect++;
    SET_VECTOR_ELT(out, coli, nbhd[m]);
    SET_STRING_ELT(outNm, coli++, mkChar(nbhd_nm[m]));
  }
  setAttrib(out, R_NamesSymbol, outNm);

  for (int i=0; i<n; i++) {
    SEXP ghis = STRING_ELT(gh, i);
    const char * ghi = CHAR(ghis);
    int k=strlen(ghi);
    if (ghis == NA_STRING || k==0) {
      for (int m=0; m<9; m++) {
        if (m == 4) continue;
        SET_STRING_ELT(nbhd[m], i, NA_STRING);
      }
      continue;
    }

    char gh_elt[k+1];
    gh_elt[k]='\0';

    // checking is_southern is easy (val=0), is_northern is a bit
    //   more of a pain (all of the _set_ bits are 1, but a bit involved
    //   to take the end value and decide which were set/unset... instead,
    //   update it as we go along checking at each component)
    bool is_northern=true;

    // initialize compx 1 so that we can always subtract 1 (left-hand boundary
    //   wraps around the international date line)
    uint64_t compx=1, compy=0, nbx, nby; // comp->component, nb->neighbor
    for (int p=0; p<k; p+=2){
      int idx0 = char_idx(&ghi[p]),
          idx1 = p+1==k ? 0 : char_idx(&ghi[p+1]);
      if (idx0 == NA_INTEGER || idx1 == NA_INTEGER) {
        UNPROTECT(nprotect);
        error("Invalid geohash; check '%s' at index %d.\nValid characters: [0123456789bcdefghjkmnpqrstuvwxyz]", ghi, i+1);
      }

      compx <<= 5;
      compy <<= 5;

      compx += offset[idx0][idx1][0];
      compy += offset[idx0][idx1][1];
      is_northern = is_northern && (offset[idx0][idx1][1]==31);
    }
    // also tried: double loop to try and save double-calculating
    //   nby all 3 times, but conflicts with manipulating it in
    //   the precision (p) loop, so that approach would require more storage
    for (int m=0; m<9; m++) {
      if (m == 4) continue;
      if (compy==0 && m/3==0) {
        SET_STRING_ELT(nbhd[m], i, NA_STRING); continue;
      }
      if (is_northern && m/3==2) {
        SET_STRING_ELT(nbhd[m], i, NA_STRING); continue;
      }
      nby = compy + (m/3)-1;
      nbx = compx + (m%3)-1;
      for (int p=k; p>0; p--) {
        // NB: flipped the branches since they apply to p-1
        if (p % 2) {
          gh_elt[p-1] = map[nby&3][nbx&7];
          nby >>= 2;
          nbx >>= 3;
        } else {
          gh_elt[p-1] = map[nbx&3][nby&7];
          nby >>= 3;
          nbx >>= 2;
        }
      }
      SET_STRING_ELT(nbhd[m], i, mkChar(gh_elt));
    }
  }

  UNPROTECT(nprotect);
  return out;
}

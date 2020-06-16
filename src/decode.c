#include "geohash.h"

SEXP gh_decode(SEXP gh, SEXP include_delta_arg, SEXP coord_loc_arg) {
  const int n = LENGTH(gh);

  int nprotect = 0;
  const bool include_delta = LOGICAL(include_delta_arg)[0] == TRUE;
  const int coord_loc = INTEGER(coord_loc_arg)[0];
  SEXP out = PROTECT(allocVector(VECSXP, include_delta ? 4 : 2)); nprotect++;
  SEXP outNm = PROTECT(allocVector(STRSXP, include_delta? 4 : 2)); nprotect++;

  SEXP y = PROTECT(allocVector(REALSXP, n)); nprotect++;
  SET_VECTOR_ELT(out, 0, y);
  SET_STRING_ELT(outNm, 0, mkChar("latitude"));

  SEXP x = PROTECT(allocVector(REALSXP, n)); nprotect++;
  SET_VECTOR_ELT(out, 1, x);
  SET_STRING_ELT(outNm, 1, mkChar("longitude"));

  SEXP deltay, deltax;
  if (include_delta) {
    deltay = PROTECT(allocVector(REALSXP, n)); nprotect++;
    deltax = PROTECT(allocVector(REALSXP, n)); nprotect++;
    SET_VECTOR_ELT(out, 2, deltay);
    SET_STRING_ELT(outNm, 2, mkChar("delta_latitude"));
    SET_VECTOR_ELT(out, 3, deltax);
    SET_STRING_ELT(outNm, 3, mkChar("delta_longitude"));
  }
  setAttrib(out, R_NamesSymbol, outNm);

  if (!n) {
    UNPROTECT(nprotect);
    return out;
  }

  double * yp = REAL(y);
  double * xp = REAL(x);
  double *dyp, *dxp;
  if (include_delta) {
    dyp = REAL(deltay);
    dxp = REAL(deltax);
  }

  for (int i=0; i<n; i++) {
    SEXP ghis = STRING_ELT(gh, i);
    const char * ghi = CHAR(ghis);
    int k=strlen(ghi);
    if (ghis == NA_STRING || k==0) {
      xp[i] = NA_REAL;
      yp[i] = NA_REAL;
      if (include_delta) {
        dxp[i] = NA_REAL;
        dyp[i] = NA_REAL;
      }
      continue;
    }

    xp[i]=-180.0, yp[i]=-90.0;

    int offsetx, offsety;
    union {
      double d;
      uint64_t i64;
    } deltax, deltay;
    deltax.d = 360.0;
    deltay.d = 180.0;

    for (int p=0; p<k; p++) {
      unsigned char ghip = (unsigned char)ghi[p];
      if (check_range(&ghip)) {
        error("Non-ASCII character at index %d. If this is surprising, use charToRaw('%s') and look for values outside 00-7f", i+1, ghi);
      }
      int O4=offset4[ghip];
      if (O4 == NA_INTEGER) {
        error("Invalid geohash; check '%s' at index %d.\nValid characters: [0123456789bcdefghjkmnpqrstuvwxyz]", ghi, i+1);
      }
      int O8=offset8[ghip];
      if (p % 2) { // even in 1-indexed gh precision
        offsetx = O4;
        offsety = O8;

        deltax.i64-=mult4;
        deltay.i64-=mult8;
      } else { // odd in 1-indexed gh precision
        offsetx = O8;
        offsety = O4;

        deltax.i64-=mult8;
        deltay.i64-=mult4;
      }

      xp[i]+=offsetx*deltax.d;
      yp[i]+=offsety*deltay.d;
    }
    // now apply final offset
    xp[i]+=centeroffx[coord_loc]*deltax.d/2;
    yp[i]+=centeroffy[coord_loc]*deltay.d/2;
    if (include_delta) {
      dyp[i] = deltay.d/2;
      dxp[i] = deltax.d/2;
    }

  }

  UNPROTECT(nprotect);
  return out;
}

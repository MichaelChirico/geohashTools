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

    union {
      double d;
      uint64_t i64;
    } deltax, deltay;
    deltax.d = 360.0;
    deltay.d = 180.0;

    for (int p=0; p<k; p+=2) {
      int idx0 = char_idx(&ghi[p]),
          idx1 = p+1==k ? 0 : char_idx(&ghi[p+1]);
      if (idx0 == NA_INTEGER || idx1 == NA_INTEGER) {
        error("Invalid geohash; check '%s' at index %d.\nValid characters: [0123456789bcdefghjkmnpqrstuvwxyz]", ghi, i+1);
      }
      deltax.i64-=mult32;
      deltay.i64-=mult32;

      xp[i]+=offset[idx0][idx1][0]*deltax.d;
      yp[i]+=offset[idx0][idx1][1]*deltay.d;
    }
    // now apply final offset (value depends on parity of precision)
    if (k % 2) {
      deltax.i64+=mult2;
      deltay.i64+=mult4;
    } else {
      deltax.i64-=mult2;
      deltay.i64-=mult2;
    }
    xp[i]+=centeroffx[coord_loc]*deltax.d;
    yp[i]+=centeroffy[coord_loc]*deltay.d;
    if (include_delta) {
      dyp[i] = deltay.d;
      dxp[i] = deltax.d;
    }
  }

  UNPROTECT(nprotect);
  return out;
}

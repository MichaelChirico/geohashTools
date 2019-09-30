#include "geohash.h"
#include <math.h> // for fmod

SEXP gh_encode(SEXP y, SEXP x, SEXP k_arg) {
  int n = LENGTH(y);
  if (LENGTH(x) != n)
    error("Inputs must be the same size.");
  int k = INTEGER(k_arg)[0];
  char gh_elt[k+1];
  gh_elt[k]='\0';

  int nprotect = 0;
  SEXP gh = PROTECT(allocVector(STRSXP, n)); nprotect++;

  if (!n) {
    UNPROTECT(nprotect);
    return gh;
  }

  if (TYPEOF(y) != REALSXP) {
    y = PROTECT(coerceVector(y, REALSXP)); nprotect++;
  }
  if (TYPEOF(x) != REALSXP) {
    x = PROTECT(coerceVector(x, REALSXP)); nprotect++;
  }

  double *yp = REAL(y);
  double *xp = REAL(x);

  // using type punning to manipulate the binary IEEE 754
  //   representation of the (8-bit double) inputs in order to do encoding.
  //   NB: {seven31} package provides a handy function reveal for
  //   quickly inspecting how a given number looks as 64-bit integer
  union {
    double d;
    uint64_t i64;
  } zx, zy;
  int xidx, yidx; // which cell did we land in?
  for (int i=0; i<n; i++) {
    if (!R_FINITE(xp[i]) || !R_FINITE(yp[i])) {
      SET_STRING_ELT(gh, i, NA_STRING);
      continue;
    }
    if (yp[i] >= 90 || yp[i] < -90) {
      error("Invalid latitude at index %d; must be in [-90, 90)", i + 1);
    }
    // re-scale lat/lon space into [0,1]^2
    // NB: since .5 might be on a totally different base-2 scale from
    //   xp[i], addition here can ruin the precision of xp.
    //   So I eschew trying to get maximally precise answers (e.g.
    //   at .Machine$double.eps levels); roughly 100*.Machine$double.eps
    //   already seems to do fine
    if (xp[i] >= 180 || xp[i] < -180) {
      zx.d = fmod(xp[i] + 180.0, 360.0)/360.0;
    } else {
      zx.d = xp[i]/360.0+0.5;
    }
    zy.d = yp[i]/180.0+0.5;

    for (int p=0; p<k; p++) {
      if (p % 2) { // even in 1-indexed gh precision
        // divide by .25 or .5 to find which interval in [0,1] is matched;
        //   don't need to worry about overflowing the power because
        //   we're already between 0 and 1
        zx.i64 += mult4; // multiply by 4; now on [0, 4]
        zy.i64 += mult8; // multiply by 8; now on [0, 8]

        xidx = (short int)zx.d; // to lattice {0, ..., 4}
        yidx = (short int)zy.d; // to lattice {0, ..., 8}
        gh_elt[p] = map[xidx][yidx];
      } else { // odd in 1-indexed gh precision

        zx.i64 += mult8;
        zy.i64 += mult4;

        xidx = (short int)zx.d;
        yidx = (short int)zy.d;
        // (int) handles the border cases correctly (left closed, right open)
        gh_elt[p] = map[yidx][xidx];
      }
      zx.d-=xidx; // "zoom in" to [0,1]^2 again
      zy.d-=yidx;
    }
    SET_STRING_ELT(gh, i, mkChar(gh_elt));
  }

  UNPROTECT(nprotect);
  return gh;
}

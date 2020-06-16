#include "geohash.h"
#include <R_ext/Rdynload.h>

// .Calls
SEXP gh_encode();
SEXP gh_decode();
SEXP gh_neighbors();

static const
R_CallMethodDef callMethods[] = {
  {"Cgh_encode", (DL_FUNC) &gh_encode, -1},
  {"Cgh_decode", (DL_FUNC) &gh_decode, -1},
  {"Cgh_neighbors", (DL_FUNC) &gh_neighbors, -1},
  {NULL, NULL, 0}
};

void R_init_geohashTools(DllInfo *info) {
  R_useDynamicSymbols(info, FALSE);
  R_registerRoutines(info, NULL, callMethods, NULL, NULL);
}

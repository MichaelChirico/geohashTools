#include "geohash.h"
#include <R_ext/Rdynload.h>

static const
R_CallMethodDef callMethods[] = {
  {"Cgh_encode", (DL_FUNC) &gh_encode, -1},
  {"Cgh_decode", (DL_FUNC) &gh_decode, -1},
  {"Cgh_neighbors", (DL_FUNC) &gh_neighbors, -1},
  {NULL, NULL, 0}
};

void R_init_geohashTools(DllInfo *info) {
  R_registerRoutines(
      info,
      /*.C*/ NULL,
      /*.Call*/ callMethods,
      /*.Fortran*/ NULL,
      /*.External*/NULL);
  R_useDynamicSymbols(info, FALSE);
  R_forceSymbols(info, TRUE);
}

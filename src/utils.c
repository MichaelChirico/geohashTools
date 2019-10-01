#include "geohash.h"

// map characters to 0-31; INT_MIN means invalid character
int char_idx(const char * ch) {
  //Rprintf("encountered %x\n", (int)*ch);
  if (*ch >= 0x7b) return(INT_MIN);
  if (*ch >= 0x70) return(*ch - 'p' + 21); // p-z mapped to 21-31
  if (*ch == 0x6f) return(INT_MIN); // o
  if (*ch >= 0x6d) return(*ch - 'm' + 19); // mn mapped to 19-20
  if (*ch == 0x6c) return(INT_MIN); // l
  if (*ch >= 0x6a) return(*ch - 'j' + 17); // jk mapped to 18-19
  if (*ch == 0x69) return(INT_MIN); // i
  if (*ch >= 0x62) return(*ch - 'b' + 10); // b-h mapped to 10-17
  if (*ch >= 0x5b) return(INT_MIN);
  if (*ch >= 0x50) return(*ch - 'P' + 21); // P-Z mapped to 21-31
  if (*ch == 0x4f) return(INT_MIN); // O
  if (*ch >= 0x4d) return(*ch - 'M' + 19); // MN mapped to 19-20
  if (*ch == 0x4c) return(INT_MIN); // L
  if (*ch >= 0x4a) return(*ch - 'J' + 17); // JK mapped to 18-19
  if (*ch == 0x49) return(INT_MIN); // I
  if (*ch >= 0x42) return(*ch - 'B' + 10); // B-H mapped to 10-17
  if (*ch >= 0x3a) return(INT_MIN);
  if (*ch >= 0x30) return(*ch - '0');      // 0-9 mapped to 0-9
  return(INT_MIN);
}

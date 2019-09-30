// need to ensure character is in ASCII range to prevent out-of-memory access error
int check_range(unsigned char * ch) {
  return *ch > 127 ? 1 : 0;
}

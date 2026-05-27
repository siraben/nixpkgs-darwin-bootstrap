#include <gmp.h>
int main(void) {
  mpz_t a;
  mpz_init(a);
  mpz_set_ui(a, 42);
  unsigned long v = mpz_get_ui(a);
  mpz_clear(a);
  return v == 42 ? 0 : 1;
}

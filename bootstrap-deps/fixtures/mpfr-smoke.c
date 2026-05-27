#include <mpfr.h>
int main(void) {
  mpfr_t x;
  mpfr_init2(x, 53);
  mpfr_set_d(x, 1.5, MPFR_RNDN);
  double v = mpfr_get_d(x, MPFR_RNDN);
  mpfr_clear(x);
  return (v == 1.5) ? 0 : 1;
}

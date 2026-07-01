#include <mpc.h>
int main(void) {
  mpc_t z;
  mpc_init2(z, 53);
  mpc_set_d_d(z, 1.0, 2.0, MPC_RNDNN);
  mpc_clear(z);
  return 0;
}

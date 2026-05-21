static long x;
static long *p = &x;
int main(void) { return p == &x && x == 0 ? 0 : 3; }

int f(int x) { return x + 1; }
int (*fp)(int) = f;
struct entry { const char *name; int (*fn)(int); };
struct entry table[] = { { "f", f }, { 0, 0 } };
int main(void) { if (fp(41) != 42) return 1; if (table[0].fn(41) != 42) return 2; return 0; }

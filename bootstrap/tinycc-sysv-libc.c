typedef unsigned long size_t;
typedef long FILE;

int errno;

extern long write(int fd, const void *buf, unsigned long n);
extern long read(int fd, void *buf, unsigned long n);
extern long open(const char *path, int flags, int mode);
extern long close(int fd);
extern long lseek(int fd, long off, int whence);
extern long unlink(const char *path);
extern void _exit(int code);
extern void *mmap(void *addr, unsigned long len, int prot, int flags, int fd, long off);

void exit(int code) { _exit(code); }
void __assert_fail(const char *a, const char *b, unsigned int c, const char *d) { write(2, "assert\n", 7); _exit(1); }
void *__va_start(void *ap, void *last) { return ap; }

void *malloc(size_t n) { size_t sz = (n + 4095 + 16) & ~4095; unsigned long *p = mmap(0, sz, 3, 0x1002, -1, 0); if ((long)p < 0) return 0; p[0] = sz - 16; p[1] = 0; return p + 2; }
void free(void *p) { }

void *memcpy(void *d, const void *s, size_t n) { char *dd = d; const char *ss = s; while (n--) *dd++ = *ss++; return d; }
void *memmove(void *d, const void *s, size_t n) { char *dd = d; const char *ss = s; if (dd < ss) while (n--) *dd++ = *ss++; else { dd += n; ss += n; while (n--) *--dd = *--ss; } return d; }
void *memset(void *d, int c, size_t n) { unsigned char *p = d; while (n--) *p++ = (unsigned char)c; return d; }
int memcmp(const void *a, const void *b, size_t n) { const unsigned char *x = a, *y = b; while (n--) { if (*x != *y) return *x - *y; x++; y++; } return 0; }
void *realloc(void *p, size_t n) { void *q = malloc(n); if (p && q) { size_t old = ((unsigned long *)p)[-2]; memcpy(q, p, old < n ? old : n); } return q; }
size_t strlen(const char *s) { const char *p = s; while (*p) p++; return p - s; }
char *strcpy(char *d, const char *s) { char *r = d; while ((*d++ = *s++)); return r; }
int strcmp(const char *a, const char *b) { while (*a && *a == *b) { a++; b++; } return *(unsigned char *)a - *(unsigned char *)b; }
int strncmp(const char *a, const char *b, size_t n) { while (n && *a && *a == *b) { a++; b++; n--; } return n ? *(unsigned char *)a - *(unsigned char *)b : 0; }
char *strchr(const char *s, int c) { while (*s) { if (*s == c) return (char *)s; s++; } return c ? 0 : (char *)s; }
char *strrchr(const char *s, int c) { const char *r = 0; do { if (*s == c) r = s; } while (*s++); return (char *)r; }
char *strstr(const char *h, const char *n) { size_t l = strlen(n); if (!l) return (char *)h; while (*h) { if (!memcmp(h, n, l)) return (char *)h; h++; } return 0; }

long strtol(const char *s, char **e, int base) { long neg = 0, v = 0; if (*s == '-') { neg = 1; s++; } if (base == 0) base = 10; while ((*s >= '0' && *s <= '9') || (*s >= 'a' && *s <= 'f') || (*s >= 'A' && *s <= 'F')) { int d = (*s <= '9') ? *s - '0' : ((*s <= 'F') ? *s - 'A' + 10 : *s - 'a' + 10); if (d >= base) break; v = v * base + d; s++; } if (e) *e = (char *)s; return neg ? -v : v; }
unsigned long strtoul(const char *s, char **e, int b) { return (unsigned long)strtol(s, e, b); }
unsigned long long strtoull(const char *s, char **e, int b) { return (unsigned long long)strtoul(s, e, b); }
int atoi(const char *s) { return (int)strtol(s, 0, 10); }

static void putnum(int fd, long v, int base) { char b[32]; int i = 0, neg = 0; unsigned long x; if (v < 0 && base == 10) { neg = 1; x = -v; } else x = v; do { int d = x % base; b[i++] = d < 10 ? '0' + d : 'a' + d - 10; x /= base; } while (x); if (neg) b[i++] = '-'; while (i--) write(fd, b + i, 1); }
static int fmt_fd(int fd, const char *fmt, long a, long b, long c, long d) { long args[4]; int ai = 0; args[0] = a; args[1] = b; args[2] = c; args[3] = d; while (*fmt) { if (*fmt != '%') { write(fd, fmt, 1); fmt++; continue; } fmt++; if (*fmt == 'l') fmt++; if (*fmt == 'l') fmt++; if (*fmt == 's') { char *s = (char *)args[ai++]; if (!s) s = "(null)"; write(fd, s, strlen(s)); } else if (*fmt == 'd' || *fmt == 'i') putnum(fd, args[ai++], 10); else if (*fmt == 'x' || *fmt == 'p') putnum(fd, args[ai++], 16); else if (*fmt == 'c') { char ch = args[ai++]; write(fd, &ch, 1); } else if (*fmt == '%') write(fd, "%", 1); fmt++; } return 0; }
int printf(const char *fmt, long a, long b, long c, long d) { return fmt_fd(1, fmt, a, b, c, d); }
int fprintf(FILE *f, const char *fmt, long a, long b, long c, long d) { long fd = (long)f - 1; if (fd < 0) fd = 2; return fmt_fd(fd, fmt, a, b, c, d); }

int fputs(const char *s, FILE *f) { long fd = (long)f - 1; if (fd < 0) fd = 1; return write(fd, s, strlen(s)); }
int fputc(int c, FILE *f) { char ch = c; long fd = (long)f - 1; if (fd < 0) fd = 1; return write(fd, &ch, 1); }
size_t fwrite(const void *p, size_t z, size_t n, FILE *f) { long fd = (long)f - 1; long r = write(fd, p, z * n); return r < 0 ? 0 : r / z; }
size_t fread(void *p, size_t z, size_t n, FILE *f) { long fd = (long)f - 1; long r = read(fd, p, z * n); return r < 0 ? 0 : r / z; }
FILE *fdopen(int fd, const char *m) { return (FILE *)(long)(fd + 1); }
FILE *fopen(const char *p, const char *m) { int flags = 0; if (m && m[0] == 'w') flags = 0x601; long fd = open(p, flags, 0666); return fd < 0 ? 0 : (FILE *)(fd + 1); }
int fclose(FILE *f) { return close((long)f - 1); }
int fflush(FILE *f) { return 0; }
int fseek(FILE *f, long o, int w) { return lseek((long)f - 1, o, w) < 0 ? -1 : 0; }
long ftell(FILE *f) { return lseek((long)f - 1, 0, 1); }

int remove(const char *p) { return unlink(p); }
char *getenv(const char *n) { return 0; }
char *getcwd(char *b, size_t n) { if (n >= 2) { b[0] = '.'; b[1] = 0; return b; } return 0; }
int execvp(const char *f, char *const a[]) { return -1; }
long time(long *t) { if (t) *t = 0; return 0; }
void *localtime(const long *t) { return 0; }
float strtof(const char *s, char **e) { if (e) *e = (char *)s; return 0; }
double ldexp(double x, int e) { return x; }
int sscanf(const char *s, const char *f, long a, long b) { return 0; }
int sprintf(char *b, const char *f, long a, long c, long d, long e) { return 0; }
int snprintf(char *b, size_t n, const char *f, long a, long c, long d) { if (n) b[0] = 0; return 0; }
int vsnprintf(char *b, size_t n, const char *f, void *ap) { if (n) b[0] = 0; return 0; }
void longjmp(void *env, int val) { _exit(2); }

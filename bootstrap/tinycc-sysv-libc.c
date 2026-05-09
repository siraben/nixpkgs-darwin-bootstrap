typedef unsigned long size_t;
typedef long FILE;

int errno;
FILE *stdin = (FILE *)0;
FILE *stdout = (FILE *)1;
FILE *stderr = (FILE *)2;
static int ungot_fd = -1;
static int ungot_ch = -1;

extern long write(int fd, const void *buf, unsigned long n);
extern long read(int fd, void *buf, unsigned long n);
extern long open(const char *path, int flags, int mode);
extern long close(int fd);
extern long lseek(int fd, long off, int whence);
extern long unlink(const char *path);
extern void _exit(int code);
extern void *mmap(void *addr, unsigned long len, int prot, int flags, int fd, long off);

static long file_fd(FILE *f) { long v = (long)f; return v <= 2 ? v : v - 3; }

void exit(int code) { _exit(code); }
void abort(void) { _exit(1); }
void __assert_fail(const char *a, const char *b, unsigned int c, const char *d) { write(2, "assert\n", 7); _exit(1); }
void *__va_start(void *ap, void *last) { return ap; }

void *malloc(size_t n) { size_t sz = (n + 4095 + 16) & ~4095; unsigned long *p = mmap(0, sz, 3, 0x1002, -1, 0); if ((long)p < 0) return 0; p[0] = sz - 16; p[1] = 0; return p + 2; }
void free(void *p) { }

void *memcpy(void *d, const void *s, size_t n) { char *dd = d; const char *ss = s; while (n--) *dd++ = *ss++; return d; }
void *memmove(void *d, const void *s, size_t n) { char *dd = d; const char *ss = s; if (dd < ss) while (n--) *dd++ = *ss++; else { dd += n; ss += n; while (n--) *--dd = *--ss; } return d; }
void *memset(void *d, int c, size_t n) { unsigned char *p = d; while (n--) *p++ = (unsigned char)c; return d; }
void *calloc(size_t n, size_t z) { size_t bytes = n * z; void *p = malloc(bytes); if (p) memset(p, 0, bytes); return p; }
int memcmp(const void *a, const void *b, size_t n) { const unsigned char *x = a, *y = b; while (n--) { if (*x != *y) return *x - *y; x++; y++; } return 0; }
void *memchr(const void *s, int c, size_t n) { const unsigned char *p = s; while (n--) { if (*p == (unsigned char)c) return (void *)p; p++; } return 0; }
void *realloc(void *p, size_t n) { void *q = malloc(n); if (p && q) { size_t old = ((unsigned long *)p)[-2]; memcpy(q, p, old < n ? old : n); } return q; }
size_t strlen(const char *s) { const char *p = s; while (*p) p++; return p - s; }
char *strcpy(char *d, const char *s) { char *r = d; while ((*d++ = *s++)); return r; }
char *strcat(char *d, const char *s) { char *r = d; while (*d) d++; while ((*d++ = *s++)); return r; }
int strcmp(const char *a, const char *b) { while (*a && *a == *b) { a++; b++; } return *(unsigned char *)a - *(unsigned char *)b; }
int strncmp(const char *a, const char *b, size_t n) { while (n && *a && *a == *b) { a++; b++; n--; } return n ? *(unsigned char *)a - *(unsigned char *)b : 0; }
char *strncpy(char *d, const char *s, size_t n) { char *r = d; while (n && *s) { *d++ = *s++; n--; } while (n--) *d++ = 0; return r; }
char *strchr(const char *s, int c) { while (*s) { if (*s == c) return (char *)s; s++; } return c ? 0 : (char *)s; }
char *strrchr(const char *s, int c) { const char *r = 0; do { if (*s == c) r = s; } while (*s++); return (char *)r; }
char *strstr(const char *h, const char *n) { size_t l = strlen(n); if (!l) return (char *)h; while (*h) { if (!memcmp(h, n, l)) return (char *)h; h++; } return 0; }
char *strdup(const char *s) { size_t n = strlen(s) + 1; char *d = malloc(n); if (d) memcpy(d, s, n); return d; }
char *strerror(int e) { return "error"; }
int bcmp(const void *a, const void *b, unsigned long n) { return memcmp(a, b, n); }
void bcopy(const void *s, void *d, unsigned long n) { memmove(d, s, n); }
void bzero(void *d, unsigned long n) { memset(d, 0, n); }
char *index(const char *s, int c) { return strchr(s, c); }
char *rindex(const char *s, int c) { return strrchr(s, c); }

long strtol(const char *s, char **e, int base) { long neg = 0, v = 0; if (*s == '-') { neg = 1; s++; } if (base == 0) base = 10; while ((*s >= '0' && *s <= '9') || (*s >= 'a' && *s <= 'f') || (*s >= 'A' && *s <= 'F')) { int d = (*s <= '9') ? *s - '0' : ((*s <= 'F') ? *s - 'A' + 10 : *s - 'a' + 10); if (d >= base) break; v = v * base + d; s++; } if (e) *e = (char *)s; return neg ? -v : v; }
unsigned long strtoul(const char *s, char **e, int b) { return (unsigned long)strtol(s, e, b); }
unsigned long long strtoull(const char *s, char **e, int b) { return (unsigned long long)strtoul(s, e, b); }
int atoi(const char *s) { return (int)strtol(s, 0, 10); }
int abs(int x) { return x < 0 ? -x : x; }
void qsort(void *base, size_t n, size_t size, int (*cmp)(const void *, const void *)) { }

static int append_char(char *b, size_t n, size_t *pos, int c) { if (*pos + 1 < n) b[*pos] = c; (*pos)++; return 1; }
static int append_str(char *b, size_t n, size_t *pos, const char *s) { int count = 0; if (!s) s = "(null)"; if ((unsigned long)s < 4096) s = "(bad)"; while (*s) { append_char(b, n, pos, *s++); count++; } return count; }
static int append_num(char *b, size_t n, size_t *pos, long v, int base) { char tmp[32]; int i = 0, neg = 0, count = 0; unsigned long x; if (v < 0 && base == 10) { neg = 1; x = -v; } else x = v; do { int d = x % base; tmp[i++] = d < 10 ? '0' + d : 'a' + d - 10; x /= base; } while (x); if (neg) tmp[i++] = '-'; while (i--) { append_char(b, n, pos, tmp[i]); count++; } return count; }
static int format_buffer(char *b, size_t n, const char *fmt, long *args) { size_t pos = 0; while (*fmt) { if (*fmt != '%') { append_char(b, n, &pos, *fmt++); continue; } fmt++; if (*fmt == 'l') fmt++; if (*fmt == 'l') fmt++; if (*fmt == 's') append_str(b, n, &pos, (char *)*args++); else if (*fmt == 'd' || *fmt == 'i') append_num(b, n, &pos, *args++, 10); else if (*fmt == 'x' || *fmt == 'p') append_num(b, n, &pos, *args++, 16); else if (*fmt == 'c') append_char(b, n, &pos, *args++); else if (*fmt == '%') append_char(b, n, &pos, '%'); else append_char(b, n, &pos, *fmt); fmt++; } if (n) b[pos < n ? pos : n - 1] = 0; return pos; }
static void putnum(int fd, long v, int base) { char b[32]; size_t pos = 0; append_num(b, sizeof(b), &pos, v, base); write(fd, b, pos); }
static int fmt_fd(int fd, const char *fmt, long a, long b, long c, long d) { long args[4]; int ai = 0; args[0] = a; args[1] = b; args[2] = c; args[3] = d; while (*fmt) { if (*fmt != '%') { write(fd, fmt, 1); fmt++; continue; } fmt++; if (*fmt == 'l') fmt++; if (*fmt == 'l') fmt++; if (*fmt == 's') { char *s = (char *)args[ai++]; if (!s) s = "(null)"; write(fd, s, strlen(s)); } else if (*fmt == 'd' || *fmt == 'i') putnum(fd, args[ai++], 10); else if (*fmt == 'x' || *fmt == 'p') putnum(fd, args[ai++], 16); else if (*fmt == 'c') { char ch = args[ai++]; write(fd, &ch, 1); } else if (*fmt == '%') write(fd, "%", 1); fmt++; } return 0; }
int printf(const char *fmt, long a, long b, long c, long d) { return fmt_fd(1, fmt, a, b, c, d); }
int fprintf(FILE *f, const char *fmt, long a, long b, long c, long d) { return fmt_fd(file_fd(f), fmt, a, b, c, d); }
int vfprintf(FILE *f, const char *fmt, void *ap) { char b[4096]; int n = format_buffer(b, sizeof(b), fmt, (long *)ap); write(file_fd(f), b, n); return n; }
void perror(const char *s) { if (s) { write(2, s, strlen(s)); write(2, ": ", 2); } write(2, "error\n", 6); }

int fputs(const char *s, FILE *f) { return write(file_fd(f), s, strlen(s)); }
int puts(const char *s) { int r = write(1, s, strlen(s)); write(1, "\n", 1); return r + 1; }
int fputc(int c, FILE *f) { char ch = c; return write(file_fd(f), &ch, 1); }
int putc(int c, FILE *f) { return fputc(c, f); }
int putchar(int c) { return fputc(c, stdout); }
int getc(FILE *f) { unsigned char ch; int fd = file_fd(f); if (ungot_fd == fd && ungot_ch >= 0) { ch = ungot_ch; ungot_ch = -1; return ch; } return read(fd, &ch, 1) == 1 ? ch : -1; }
int ungetc(int c, FILE *f) { ungot_fd = file_fd(f); ungot_ch = c; return c; }
size_t fwrite(const void *p, size_t z, size_t n, FILE *f) { long r = write(file_fd(f), p, z * n); return r < 0 ? 0 : r / z; }
size_t fread(void *p, size_t z, size_t n, FILE *f) { long r = read(file_fd(f), p, z * n); return r < 0 ? 0 : r / z; }
FILE *fdopen(int fd, const char *m) { return (FILE *)(long)(fd + 3); }
FILE *fopen(const char *p, const char *m) { int flags = 0; if (m && m[0] == 'w') flags = 0x601; long fd = open(p, flags, 0666); return fd < 0 ? 0 : (FILE *)(fd + 3); }
FILE *fopen_unlocked(const char *p, const char *m) { return fopen(p, m); }
FILE *freopen(const char *p, const char *m, FILE *f) { if (f) close(file_fd(f)); return fopen(p, m); }
int fclose(FILE *f) { return close(file_fd(f)); }
int fflush(FILE *f) { return 0; }
int feof(FILE *f) { return 0; }
int ferror(FILE *f) { return 0; }
int fseek(FILE *f, long o, int w) { return lseek(file_fd(f), o, w) < 0 ? -1 : 0; }
long ftell(FILE *f) { return lseek(file_fd(f), 0, 1); }

int remove(const char *p) { return unlink(p); }
int fstat(int fd, void *st) { return -1; }
int stat(const char *p, void *st) { return -1; }
char *mktemp(char *template) { return template; }
char *getenv(const char *n) { return 0; }
char *getcwd(char *b, size_t n) { if (n >= 2) { b[0] = '.'; b[1] = 0; return b; } return 0; }
int execvp(const char *f, char *const a[]) { return -1; }
int fork(void) { return -1; }
int wait(int *status) { if (status) *status = -1; return -1; }
long time(long *t) { if (t) *t = 0; return 0; }
long clock(void) { return 0; }
void *localtime(const long *t) { return 0; }
float strtof(const char *s, char **e) { if (e) *e = (char *)s; return 0; }
double atof(const char *s) { return 0; }
double ldexp(double x, int e) { return x; }
double frexp(double x, int *e) { if (e) *e = 0; return x; }
double __floatundidf(unsigned long x) { return (double)x; }
double __floatdidf(long x) { return (double)x; }
unsigned long __fixunsdfdi(double x) { return (unsigned long)x; }
long __fixdfdi(double x) { return (long)x; }
int sscanf(const char *s, const char *f, long a, long b) { return 0; }
int sprintf(char *b, const char *f, long a, long c, long d, long e) { long args[4]; args[0] = a; args[1] = c; args[2] = d; args[3] = e; return format_buffer(b, (size_t)-1, f, args); }
int snprintf(char *b, size_t n, const char *f, long a, long c, long d) { long args[3]; args[0] = a; args[1] = c; args[2] = d; return format_buffer(b, n, f, args); }
int vsprintf(char *b, const char *f, void *ap) { return format_buffer(b, (size_t)-1, f, (long *)ap); }
int vsnprintf(char *b, size_t n, const char *f, void *ap) { return format_buffer(b, n, f, (long *)ap); }
int vasprintf(char **out, const char *f, void *ap) { *out = malloc(4096); return *out ? vsnprintf(*out, 4096, f, ap) : -1; }
void unlock_std_streams(void) { }
void longjmp(void *env, int val) { _exit(2); }

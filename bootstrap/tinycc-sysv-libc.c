typedef unsigned long size_t;
typedef long FILE;

int errno;
int sys_nerr;
char *sys_errlist[1];
char *empty_environ[1];
char **environ = empty_environ;
FILE *stdin = (FILE *)0;
FILE *stdout = (FILE *)1;
FILE *stderr = (FILE *)2;
/* Darwin's <stdio.h> maps stdin/stdout/stderr to these; libstdc++ references
 * them (debug.o, ios_init.o, vterminate.o).  Same FILE* sentinels. */
FILE *__stdinp = (FILE *)0;
FILE *__stdoutp = (FILE *)1;
FILE *__stderrp = (FILE *)2;
static int ungot_fd = -1;
static int ungot_ch = -1;
static char *malloc_cur = (char *)-1;
static char *malloc_end = (char *)-1;

extern long write(int fd, const void *buf, unsigned long n);
extern long read(int fd, void *buf, unsigned long n);
extern long sys_open(const char *path, int flags, int mode);
/* open() must translate the kernel's -errno return into -1 + errno, like
 * stat()/execve() do.  Without this, a failed open() returns e.g. -2 with
 * errno=0, which breaks callers (notably cpp's include search, which relies
 * on errno==ENOENT to keep scanning the next -I dir instead of erroring). */
int open(const char *path, int flags, int mode) { long r = sys_open(path, flags, mode); if (r < 0) { errno = -r; return -1; } return r; }
extern long close(int fd);
extern long lseek(int fd, long off, int whence);
extern long unlink(const char *path);
extern long sys_rename(const char *old, const char *new);
extern long sys_execve(const char *path, char *const argv[], char *const envp[]);
extern long sys_fork(void);
extern long sys_wait4(int pid, int *status, int options, void *rusage);
extern long sys_pipe(int *fds);
extern long sys_dup(int fd);
extern long sys_dup2(int oldfd, int newfd);
extern long sys_fcntl(int fd, int cmd, long arg);
extern void _exit(int code);
extern void *mmap(void *addr, unsigned long len, int prot, int flags, int fd, long off);
void *memcpy(void *d, const void *s, size_t n);
void *memmove(void *d, const void *s, size_t n);
void *memset(void *d, int c, size_t n);
double __floatundidf(unsigned long x);
double __floatdidf(long x);
long double __floatundixf(unsigned long x);
unsigned long __fixunsdfdi(double x);
long __fixdfdi(double x);
unsigned long __fixunsxfdi(long double x);

static long file_fd(FILE *f) { long v = (long)f; return v <= 2 ? v : v - 3; }

void exit(int code) { _exit(code); }
void abort(void) { _exit(1); }
void __assert_fail(const char *a, const char *b, unsigned int c, const char *d) { write(2, "assert\n", 7); _exit(1); }

enum __va_arg_type { __va_gen_reg, __va_float_reg, __va_stack };
typedef struct {
    unsigned int gp_offset;
    unsigned int fp_offset;
    union {
        unsigned int overflow_offset;
        char *overflow_arg_area;
    };
    char *reg_save_area;
} __va_list_struct;

void __va_start(__va_list_struct *ap, void *fp)
{
    memset(ap, 0, sizeof(__va_list_struct));
    *ap = *(__va_list_struct *)((char *)fp - 16);
    ap->overflow_arg_area = (char *)fp + ap->overflow_offset;
    ap->reg_save_area = (char *)fp - 192;
}

void *__va_arg(__va_list_struct *ap, enum __va_arg_type arg_type, int size, int align)
{
    size = (size + 7) & ~7;
    align = (align + 7) & ~7;
    if (arg_type == __va_gen_reg && ap->gp_offset + size <= 48) {
        ap->gp_offset += size;
        return ap->reg_save_area + ap->gp_offset - size;
    }
    if (arg_type == __va_float_reg && ap->fp_offset < 176) {
        ap->fp_offset += 16;
        return ap->reg_save_area + ap->fp_offset - 16;
    }
    ap->overflow_arg_area = (char *)(((unsigned long)(ap->overflow_arg_area + align - 1)) & -align);
    ap->overflow_arg_area += size;
    return ap->overflow_arg_area - size;
}

void *malloc(size_t n) { size_t need = (n + 31) & ~15; if (malloc_cur == (char *)-1 || malloc_cur + need > malloc_end) { size_t chunk = need > 16777216 ? need : 16777216; char *mem = mmap(0, chunk, 3, 0x1002, -1, 0); if ((long)mem < 0) return 0; malloc_cur = mem; malloc_end = mem + chunk; } unsigned long *p = (unsigned long *)malloc_cur; malloc_cur += need; p[0] = need - 16; p[1] = 0; return p + 2; }
void free(void *p) { }

void *memcpy(void *, const void *, size_t);
void *memmove(void *, const void *, size_t);
void *memset(void *, int, size_t);
void *calloc(size_t n, size_t z) { size_t bytes = n * z; void *p = malloc(bytes); if (p) memset(p, 0, bytes); return p; }
int memcmp(const void *, const void *, size_t);
void *memchr(const void *, int, size_t);
void *realloc(void *p, size_t n) { void *q = malloc(n); if (p && q) { size_t old = ((unsigned long *)p)[-2]; memcpy(q, p, old < n ? old : n); } return q; }
void *bsearch(const void *key, const void *base, size_t n, size_t size, int (*cmp)(const void *, const void *)) { const char *b = base; while (n) { size_t mid = n / 2; const void *p = b + mid * size; int c = cmp(key, p); if (c == 0) return (void *)p; if (c > 0) { b = (const char *)p + size; n -= mid + 1; } else n = mid; } return 0; }
size_t strlen(const char *s) { const char *p = s; while (*p) p++; return p - s; }
char *strcpy(char *d, const char *s) { char *r = d; while ((*d++ = *s++)); return r; }
char *strcat(char *d, const char *s) { char *r = d; while (*d) d++; while ((*d++ = *s++)); return r; }
char *strncat(char *d, const char *s, size_t n) { char *r = d; while (*d) d++; while (n && *s) { *d++ = *s++; n--; } *d = 0; return r; }
int strcmp(const char *a, const char *b) { while (*a && *a == *b) { a++; b++; } return *(unsigned char *)a - *(unsigned char *)b; }
int strncmp(const char *a, const char *b, size_t n) { while (n && *a && *a == *b) { a++; b++; n--; } return n ? *(unsigned char *)a - *(unsigned char *)b : 0; }
char *strncpy(char *d, const char *s, size_t n) { char *r = d; while (n && *s) { *d++ = *s++; n--; } while (n--) *d++ = 0; return r; }
char *strchr(const char *s, int c) { while (*s) { if (*s == c) return (char *)s; s++; } return c ? 0 : (char *)s; }
char *strrchr(const char *s, int c) { const char *r = 0; do { if (*s == c) r = s; } while (*s++); return (char *)r; }
char *strpbrk(const char *s, const char *accept) { while (*s) { const char *a = accept; while (*a) { if (*s == *a++) return (char *)s; } s++; } return 0; }
size_t strspn(const char *s, const char *accept) { size_t n = 0; while (s[n]) { const char *a = accept; int ok = 0; while (*a) if (s[n] == *a++) { ok = 1; break; } if (!ok) return n; n++; } return n; }
size_t strcspn(const char *s, const char *reject) { size_t n = 0; while (s[n]) { const char *r = reject; while (*r) if (s[n] == *r++) return n; n++; } return n; }
char *strtok(char *s, const char *delim) { static char *save; char *end; if (!s) s = save; if (!s) return 0; s += strspn(s, delim); if (!*s) { save = 0; return 0; } end = s + strcspn(s, delim); if (*end) { *end = 0; save = end + 1; } else save = 0; return s; }
char *strstr(const char *h, const char *n) { size_t l = strlen(n); if (!l) return (char *)h; while (*h) { if (!memcmp(h, n, l)) return (char *)h; h++; } return 0; }
char *strdup(const char *s) { size_t n = strlen(s) + 1; char *d = malloc(n); if (d) memcpy(d, s, n); return d; }
char *strerror(int e) { return "error"; }
int bcmp(const void *a, const void *b, unsigned long n) { return memcmp(a, b, n); }
void bcopy(const void *s, void *d, unsigned long n) { memmove(d, s, n); }
void bzero(void *d, unsigned long n) { memset(d, 0, n); }
char *index(const char *s, int c) { return strchr(s, c); }
char *rindex(const char *s, int c) { return strrchr(s, c); }

int isalpha(int c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }
int isdigit(int c) { return c >= '0' && c <= '9'; }
int isalnum(int c) { return isalpha(c) || isdigit(c); }
int islower(int c) { return c >= 'a' && c <= 'z'; }
int isspace(int c) { return c == ' ' || c == '\n' || c == '\t' || c == '\r' || c == '\f' || c == '\v'; }
int isupper(int c) { return c >= 'A' && c <= 'Z'; }
int isxdigit(int c) { return isdigit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'); }
int iscntrl(int c) { return (c >= 0 && c < 32) || c == 127; }
int isprint(int c) { return c >= 32 && c < 127; }
int ispunct(int c) { return isprint(c) && !isalnum(c) && c != ' '; }
int isascii(int c) { return (c & ~0x7f) == 0; }
int tolower(int c) { return isupper(c) ? c - 'A' + 'a' : c; }
int toupper(int c) { return islower(c) ? c - 'a' + 'A' : c; }
int strcasecmp(const char *a, const char *b) { while (*a && tolower(*a) == tolower(*b)) { a++; b++; } return tolower(*(unsigned char *)a) - tolower(*(unsigned char *)b); }
int strncasecmp(const char *a, const char *b, unsigned long n) { while (n && *a && tolower(*a) == tolower(*b)) { a++; b++; n--; } return n ? tolower(*(unsigned char *)a) - tolower(*(unsigned char *)b) : 0; }

long strtol(const char *s, char **e, int base) { long neg = 0, v = 0; if (*s == '-') { neg = 1; s++; } else if (*s == '+') { s++; } if ((base == 0 || base == 16) && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) { base = 16; s += 2; } else if (base == 0 && s[0] == '0') { base = 8; } else if (base == 0) { base = 10; } while ((*s >= '0' && *s <= '9') || (*s >= 'a' && *s <= 'f') || (*s >= 'A' && *s <= 'F')) { int d = (*s <= '9') ? *s - '0' : ((*s <= 'F') ? *s - 'A' + 10 : *s - 'a' + 10); if (d >= base) break; v = v * base + d; s++; } if (e) *e = (char *)s; return neg ? -v : v; }
unsigned long strtoul(const char *s, char **e, int b) { return (unsigned long)strtol(s, e, b); }
long long strtoll(const char *s, char **e, int b) { return (long long)strtol(s, e, b); }
unsigned long long strtoull(const char *s, char **e, int b) { return (unsigned long long)strtoul(s, e, b); }
int atoi(const char *s) { return (int)strtol(s, 0, 10); }
long atol(const char *s) { return strtol(s, 0, 10); }
long long atoll(const char *s) { return strtoll(s, 0, 10); }
int abs(int x) { return x < 0 ? -x : x; }
int ffs(int x) { int i; if (x == 0) return 0; for (i = 1; !(x & 1); i++) x = (int)((unsigned)x >> 1); return i; }
int ffsl(long x) { int i; if (x == 0) return 0; for (i = 1; !(x & 1); i++) x = (long)((unsigned long)x >> 1); return i; }
int ffsll(long long x) { int i; if (x == 0) return 0; for (i = 1; !(x & 1); i++) x = (long long)((unsigned long long)x >> 1); return i; }
long labs(long x) { return x < 0 ? -x : x; }
long long llabs(long long x) { return x < 0 ? -x : x; }
void qsort(void *base, size_t n, size_t size, int (*cmp)(const void *, const void *))
{
    char *b = base, *tmp;
    size_t gap, i, j;
    if (!base || n < 2 || !size || !cmp) return;
    tmp = malloc(size);
    if (!tmp) return;
    for (gap = n / 2; gap; gap /= 2) {
        for (i = gap; i < n; i++) {
            memcpy(tmp, b + i * size, size);
            j = i;
            while (j >= gap && cmp(b + (j - gap) * size, tmp) > 0) {
                memcpy(b + j * size, b + (j - gap) * size, size);
                j -= gap;
            }
            memcpy(b + j * size, tmp, size);
        }
    }
    free(tmp);
}

static int append_char(char *b, size_t n, size_t *pos, int c) { if (*pos + 1 < n) b[*pos] = c; (*pos)++; return 1; }
static int append_repeat(char *b, size_t n, size_t *pos, int c, int count) { int done = 0; while (done < count) { append_char(b, n, pos, c); done++; } return done; }
static int append_strn(char *b, size_t n, size_t *pos, const char *s, int max) { int count = 0; if (!s) s = "(null)"; if ((unsigned long)s < 4096) s = "(bad)"; while (*s && (max < 0 || count < max)) { append_char(b, n, pos, *s++); count++; } return count; }
static int append_str(char *b, size_t n, size_t *pos, const char *s) { return append_strn(b, n, pos, s, -1); }
static int append_num_raw(char *b, size_t n, size_t *pos, unsigned long x, int base, int upper) { char tmp[32]; int i = 0, count = 0; do { int d = x % base; tmp[i++] = d < 10 ? '0' + d : (upper ? 'A' : 'a') + d - 10; x /= base; } while (x); while (i--) { append_char(b, n, pos, tmp[i]); count++; } return count; }
static int append_num(char *b, size_t n, size_t *pos, long v, int base) { int count = 0; unsigned long x; if (v < 0 && base == 10) { append_char(b, n, pos, '-'); count++; x = -v; } else x = v; return count + append_num_raw(b, n, pos, x, base, 0); }
static int append_double(char *b, size_t n, size_t *pos, double v, int precision) { unsigned long whole; int count = 0, i; if (precision < 0) precision = 6; if (v < 0) { append_char(b, n, pos, '-'); count++; v = -v; } whole = (unsigned long)v; count += append_num(b, n, pos, whole, 10); append_char(b, n, pos, '.'); count++; v -= (double)whole; for (i = 0; i < precision; i++) { int digit; v *= 10.0; digit = (int)v; append_char(b, n, pos, '0' + digit); count++; v -= digit; } return count; }
static long next_va_long(__va_list_struct *ap) { return *(long *)__va_arg(ap, __va_gen_reg, 8, 8); }
static double next_va_double(__va_list_struct *ap) { return *(double *)__va_arg(ap, __va_float_reg, 8, 8); }
static int append_formatted(char *b, size_t n, size_t *pos, int left, int zero, int alt, int width, int precision, int spec, long value, double dbl)
{
    char tmp[256]; size_t tmp_pos = 0; int len, pad, sign = 0;
    if (spec == 's') {
        const char *s = (char *)value;
        int count = 0;
        if (!s) s = "(null)";
        if ((unsigned long)s < 4096) s = "(bad)";
        while (s[count] && (precision < 0 || count < precision)) count++;
        if (width < 0) { left = 1; width = -width; }
        pad = width > count ? width - count : 0;
        if (!left) append_repeat(b, n, pos, zero ? '0' : ' ', pad);
        append_strn(b, n, pos, s, count);
        if (left) append_repeat(b, n, pos, ' ', pad);
        return count + pad;
    }
    else if (spec == 'c') len = append_char(tmp, sizeof(tmp), &tmp_pos, value);
    else if (spec == 'f') len = append_double(tmp, sizeof(tmp), &tmp_pos, dbl, precision);
    else if (spec == 'd' || spec == 'i') { unsigned long x; if (value < 0) { sign = '-'; x = -value; } else x = value; if (sign) append_char(tmp, sizeof(tmp), &tmp_pos, sign); len = (sign ? 1 : 0) + append_num_raw(tmp, sizeof(tmp), &tmp_pos, x, 10, 0); }
    else if (spec == 'u') len = append_num_raw(tmp, sizeof(tmp), &tmp_pos, (unsigned long)value, 10, 0);
    else if (spec == 'o') { if (alt && value != 0) append_char(tmp, sizeof(tmp), &tmp_pos, '0'); len = tmp_pos + append_num_raw(tmp, sizeof(tmp), &tmp_pos, (unsigned long)value, 8, 0); }
    else if (spec == 'X') { if (alt) { append_str(tmp, sizeof(tmp), &tmp_pos, "0X"); } len = tmp_pos + append_num_raw(tmp, sizeof(tmp), &tmp_pos, (unsigned long)value, 16, 1); }
    else { if (alt || spec == 'p') { append_str(tmp, sizeof(tmp), &tmp_pos, "0x"); } len = tmp_pos + append_num_raw(tmp, sizeof(tmp), &tmp_pos, (unsigned long)value, 16, 0); }
    tmp[tmp_pos < sizeof(tmp) ? tmp_pos : sizeof(tmp) - 1] = 0;
    if (width < 0) { left = 1; width = -width; }
    pad = width > len ? width - len : 0;
    if (!left && zero && sign) { append_char(b, n, pos, sign); append_repeat(b, n, pos, '0', pad); append_strn(b, n, pos, tmp + 1, len - 1); return len + pad; }
    if (!left) append_repeat(b, n, pos, zero ? '0' : ' ', pad);
    append_strn(b, n, pos, tmp, len);
    if (left) append_repeat(b, n, pos, ' ', pad);
    return len + pad;
}
static int format_buffer_words(char *b, size_t n, const char *fmt, long *args) { size_t pos = 0; while (*fmt) { int left = 0, zero = 0, alt = 0, width = 0, precision = -1, spec; if (*fmt != '%') { append_char(b, n, &pos, *fmt++); continue; } fmt++; while (*fmt == '-' || *fmt == '+' || *fmt == ' ' || *fmt == '#' || *fmt == '0') { if (*fmt == '-') left = 1; if (*fmt == '0') zero = 1; if (*fmt == '#') alt = 1; fmt++; } if (*fmt == '*') { width = *args++; fmt++; } else while (*fmt >= '0' && *fmt <= '9') { width = width * 10 + *fmt - '0'; fmt++; } if (*fmt == '.') { precision = 0; fmt++; if (*fmt == '*') { precision = *args++; fmt++; } else while (*fmt >= '0' && *fmt <= '9') { precision = precision * 10 + *fmt - '0'; fmt++; } } while (*fmt == 'h' || *fmt == 'l' || *fmt == 'L' || *fmt == 'z' || *fmt == 't' || *fmt == 'j') fmt++; spec = *fmt; if (spec == '%') append_char(b, n, &pos, '%'); else if (spec == 'f') append_formatted(b, n, &pos, left, zero, alt, width, precision, spec, 0, 0.0); else if (spec == 's' || spec == 'd' || spec == 'i' || spec == 'u' || spec == 'x' || spec == 'X' || spec == 'p' || spec == 'o' || spec == 'c') append_formatted(b, n, &pos, left, zero, alt, width, precision, spec, *args++, 0.0); else append_char(b, n, &pos, spec); if (*fmt) fmt++; } if (n) b[pos < n ? pos : n - 1] = 0; return pos; }
static int format_buffer_va(char *b, size_t n, const char *fmt, __va_list_struct *ap)
{
    size_t pos = 0;
    while (*fmt) {
        int left = 0, zero = 0, alt = 0, width = 0, precision = -1, spec, longflag = 0;
        long value;
        if (*fmt != '%') { append_char(b, n, &pos, *fmt++); continue; }
        fmt++;
        while (*fmt == '-' || *fmt == '+' || *fmt == ' ' || *fmt == '#' || *fmt == '0') { if (*fmt == '-') left = 1; if (*fmt == '0') zero = 1; if (*fmt == '#') alt = 1; fmt++; }
        if (*fmt == '*') { width = (int)next_va_long(ap); fmt++; }
        else while (*fmt >= '0' && *fmt <= '9') { width = width * 10 + *fmt - '0'; fmt++; }
        if (*fmt == '.') {
            precision = 0;
            fmt++;
            if (*fmt == '*') { precision = (int)next_va_long(ap); fmt++; }
            else while (*fmt >= '0' && *fmt <= '9') { precision = precision * 10 + *fmt - '0'; fmt++; }
        }
        while (*fmt == 'h' || *fmt == 'l' || *fmt == 'L' || *fmt == 'z' || *fmt == 't' || *fmt == 'j') {
            if (*fmt == 'l' || *fmt == 'L' || *fmt == 'z' || *fmt == 't' || *fmt == 'j') longflag = 1;
            fmt++;
        }
        spec = *fmt;
        if (spec == '%') append_char(b, n, &pos, '%');
        else if (spec == 'f') append_formatted(b, n, &pos, left, zero, alt, width, precision, spec, 0, next_va_double(ap));
        else if (spec == 's' || spec == 'p') append_formatted(b, n, &pos, left, zero, alt, width, precision, spec, next_va_long(ap), 0.0);
        else if (spec == 'd' || spec == 'i') { value = next_va_long(ap); if (!longflag) value = (int)value; append_formatted(b, n, &pos, left, zero, alt, width, precision, spec, value, 0.0); }
        else if (spec == 'u' || spec == 'x' || spec == 'X' || spec == 'o') { value = next_va_long(ap); if (!longflag) value = (unsigned int)value; append_formatted(b, n, &pos, left, zero, alt, width, precision, spec, value, 0.0); }
        else if (spec == 'c') append_formatted(b, n, &pos, left, zero, alt, width, precision, spec, (int)next_va_long(ap), 0.0);
        else append_char(b, n, &pos, spec);
        if (*fmt) fmt++;
    }
    if (n) b[pos < n ? pos : n - 1] = 0;
    return pos;
}
int printf(const char *fmt, ...) { char out[4096]; __va_list_struct ap; int n; __va_start(&ap, __builtin_frame_address(0)); n = format_buffer_va(out, sizeof(out), fmt, &ap); write(1, out, n); return n; }
int fprintf(FILE *f, const char *fmt, ...) { char out[4096]; __va_list_struct ap; int n; __va_start(&ap, __builtin_frame_address(0)); n = format_buffer_va(out, sizeof(out), fmt, &ap); write(file_fd(f), out, n); return n; }
int vfprintf(FILE *f, const char *fmt, void *ap) { char b[4096]; int n = format_buffer_va(b, sizeof(b), fmt, (__va_list_struct *)ap); write(file_fd(f), b, n); return n; }
void perror(const char *s) { if (s) { write(2, s, strlen(s)); write(2, ": ", 2); } write(2, "error\n", 6); }

int fputs(const char *s, FILE *f) { return write(file_fd(f), s, strlen(s)); }
int puts(const char *s) { int r = write(1, s, strlen(s)); write(1, "\n", 1); return r + 1; }
int fputc(int c, FILE *f) { char ch = c; return write(file_fd(f), &ch, 1); }
int putc(int c, FILE *f) { return fputc(c, f); }
int putchar(int c) { return fputc(c, stdout); }
int getc(FILE *f) { unsigned char ch; int fd = file_fd(f); if (ungot_fd == fd && ungot_ch >= 0) { ch = ungot_ch; ungot_ch = -1; return ch; } return read(fd, &ch, 1) == 1 ? ch : -1; }
int fgetc(FILE *f) { return getc(f); }
int getchar(void) { return getc(stdin); }
char *fgets(char *s, int n, FILE *f) { int i = 0, c; if (n <= 0) return 0; while (i + 1 < n && (c = getc(f)) >= 0) { s[i++] = c; if (c == '\n') break; } if (i == 0) return 0; s[i] = 0; return s; }
int ungetc(int c, FILE *f) { ungot_fd = file_fd(f); ungot_ch = c; return c; }
size_t fwrite(const void *p, size_t z, size_t n, FILE *f) { long r = write(file_fd(f), p, z * n); return r < 0 ? 0 : r / z; }
size_t fread(void *p, size_t z, size_t n, FILE *f) { long r = read(file_fd(f), p, z * n); return r < 0 ? 0 : r / z; }
FILE *fdopen(int fd, const char *m) { return (FILE *)(long)(fd + 3); }
int fileno(FILE *f) { return file_fd(f); }
FILE *fopen(const char *p, const char *m) { int flags = 0; if (m && m[0] == 'w') flags = 0x601; long fd = open(p, flags, 0666); return fd < 0 ? 0 : (FILE *)(fd + 3); }
FILE *fopen_unlocked(const char *p, const char *m) { return fopen(p, m); }
FILE *freopen(const char *p, const char *m, FILE *f) { if (f) close(file_fd(f)); return fopen(p, m); }
int fclose(FILE *f) { return close(file_fd(f)); }
int fflush(FILE *f) { return 0; }
void setbuf(FILE *f, char *b) { }
void clearerr(FILE *f) { }
int feof(FILE *f) { return 0; }
int ferror(FILE *f) { return 0; }
void clearerr_unlocked(FILE *f) { clearerr(f); }
int feof_unlocked(FILE *f) { return feof(f); }
int ferror_unlocked(FILE *f) { return ferror(f); }
int fflush_unlocked(FILE *f) { return fflush(f); }
int fgetc_unlocked(FILE *f) { return fgetc(f); }
char *fgets_unlocked(char *s, int n, FILE *f) { return fgets(s, n, f); }
int fileno_unlocked(FILE *f) { return fileno(f); }
int fputc_unlocked(int c, FILE *f) { return fputc(c, f); }
int fputs_unlocked(const char *s, FILE *f) { return fputs(s, f); }
size_t fread_unlocked(void *p, size_t z, size_t n, FILE *f) { return fread(p, z, n, f); }
size_t fwrite_unlocked(const void *p, size_t z, size_t n, FILE *f) { return fwrite(p, z, n, f); }
int getchar_unlocked(void) { return getchar(); }
int getc_unlocked(FILE *f) { return getc(f); }
int putchar_unlocked(int c) { return putchar(c); }
int putc_unlocked(int c, FILE *f) { return putc(c, f); }
int setvbuf(FILE *f, char *b, int mode, size_t size) { return 0; }
int fseek(FILE *f, long o, int w) { return lseek(file_fd(f), o, w) < 0 ? -1 : 0; }
int fseeko(FILE *f, long o, int w) { return fseek(f, o, w); }
long ftell(FILE *f) { return lseek(file_fd(f), 0, 1); }
void rewind(FILE *f) { fseek(f, 0, 0); }
FILE *popen(const char *cmd, const char *mode) { return 0; }
int pclose(FILE *f) { return -1; }

static int scan_space(int c) { return c == ' ' || c == '\n' || c == '\t' || c == '\r' || c == '\f' || c == '\v'; }
static int scan_set_has(const char *set, int set_len, int c) { int i; for (i = 0; i < set_len; i++) if (set[i] == c) return 1; return 0; }
static int scan_fail_result(int matched, int c) { return c < 0 && matched == 0 ? -1 : matched; }
static int scan_digit_value(int ch) { if (ch >= '0' && ch <= '9') return ch - '0'; if (ch >= 'a' && ch <= 'f') return ch - 'a' + 10; if (ch >= 'A' && ch <= 'F') return ch - 'A' + 10; return -1; }
static int scan_int_file(FILE *f, int spec, int width, int *last_ch, long *out)
{
    int ch, neg = 0, digits = 0, base = 10, value_digit;
    unsigned long value = 0;
    do ch = getc(f); while (scan_space(ch));
    if (width > 0 && (ch == '-' || ch == '+')) { neg = ch == '-'; width--; ch = getc(f); }
    if (spec == 'o') base = 8;
    if (spec == 'x' || spec == 'X') base = 16;
    if (spec == 'i') {
        base = 10;
        if (width > 0 && ch == '0') {
            digits = 1;
            width--;
            ch = getc(f);
            if (width > 0 && (ch == 'x' || ch == 'X')) { base = 16; digits = 0; width--; ch = getc(f); }
            else { base = 8; value = 0; }
        }
    }
    while (width > 0 && (value_digit = scan_digit_value(ch)) >= 0 && value_digit < base) {
        value = value * base + value_digit;
        digits++;
        width--;
        ch = getc(f);
    }
    if (ch >= 0) ungetc(ch, f);
    *last_ch = ch;
    if (!digits) return 0;
    *out = neg ? -(long)value : (long)value;
    return 1;
}
int fscanf(FILE *f, const char *fmt, long a, long b, long c_arg, long d)
{
    long args[4]; int ai = 0, matched = 0, ch;
    args[0] = a; args[1] = b; args[2] = c_arg; args[3] = d;
    while (*fmt) {
        if (scan_space(*fmt)) {
            while (scan_space(*fmt)) fmt++;
            do ch = getc(f); while (scan_space(ch));
            if (ch >= 0) ungetc(ch, f);
            continue;
        }
        if (*fmt != '%') {
            ch = getc(f);
            if (ch != *fmt) { if (ch >= 0) ungetc(ch, f); return scan_fail_result(matched, ch); }
            fmt++;
            continue;
        }
        fmt++;
        int suppress = 0, width = 0, count = 0;
        if (*fmt == '*') { suppress = 1; fmt++; }
        while (*fmt >= '0' && *fmt <= '9') { width = width * 10 + *fmt - '0'; fmt++; }
        if (width == 0) width = 0x7fffffff;
        if (*fmt == 's') {
            char *out = suppress ? 0 : (char *)args[ai++];
            do ch = getc(f); while (scan_space(ch));
            while (ch >= 0 && !scan_space(ch) && count < width) {
                if (!suppress) out[count] = ch;
                count++;
                ch = getc(f);
            }
            if (ch >= 0) ungetc(ch, f);
            if (count == 0) return scan_fail_result(matched, ch);
            if (!suppress) { out[count] = 0; matched++; }
            fmt++;
            continue;
        }
        if (*fmt == 'c') {
            char *out = suppress ? 0 : (char *)args[ai++];
            if (width == 0x7fffffff) width = 1;
            while (count < width && (ch = getc(f)) >= 0) {
                if (!suppress) out[count] = ch;
                count++;
            }
            if (count == 0) return scan_fail_result(matched, ch);
            if (!suppress) matched++;
            fmt++;
            continue;
        }
        if (*fmt == '[') {
            char set[64]; int set_len = 0, negate = 0;
            fmt++;
            if (*fmt == '^') { negate = 1; fmt++; }
            while (*fmt && *fmt != ']') {
                if (set_len < (int)sizeof(set)) set[set_len++] = *fmt;
                fmt++;
            }
            if (*fmt == ']') fmt++;
            char *out = suppress ? 0 : (char *)args[ai++];
            ch = getc(f);
            while (ch >= 0 && (scan_set_has(set, set_len, ch) ? !negate : negate) && count < width) {
                if (!suppress) out[count] = ch;
                count++;
                ch = getc(f);
            }
            if (ch >= 0) ungetc(ch, f);
            if (count == 0) return scan_fail_result(matched, ch);
            if (!suppress) { out[count] = 0; matched++; }
            continue;
        }
        int long_mod = 0;
        while (*fmt == 'h' || *fmt == 'l' || *fmt == 'L' || *fmt == 'z' || *fmt == 't' || *fmt == 'j') { if (*fmt == 'l') long_mod = 1; fmt++; }
        if (*fmt == 'd' || *fmt == 'i' || *fmt == 'u' || *fmt == 'o' || *fmt == 'x' || *fmt == 'X') {
            long value = 0;
            if (!scan_int_file(f, *fmt, width, &ch, &value)) return scan_fail_result(matched, ch);
            if (!suppress) {
                if (long_mod) *(long *)args[ai++] = value;
                else *(int *)args[ai++] = (int)value;
                matched++;
            }
            fmt++;
            continue;
        }
        if (*fmt == 'n') {
            if (!suppress) *(int *)args[ai++] = 0;
            fmt++;
            continue;
        }
        return matched;
    }
    return matched;
}

int remove(const char *p) { return unlink(p); }
int creat(const char *p, int mode) { return open(p, 0x601, mode); }
int rename(const char *old, const char *new) { char buf[4096]; long n; int in, out; if (sys_rename(old, new) == 0) return 0; in = open(old, 0, 0); if (in < 0) return -1; unlink(new); out = open(new, 0x601, 0666); if (out < 0) { close(in); return -1; } while ((n = read(in, buf, sizeof(buf))) > 0) if (write(out, buf, n) != n) { close(in); close(out); return -1; } close(in); close(out); if (n < 0) return -1; unlink(old); return 0; }
int sys_stat64(const char *p, void *st);
int sys_fstat64(int fd, void *st);
int sys_lstat64(const char *p, void *st);
long sys_getdirentries64(int fd, char *buf, unsigned long nbytes, long *basep);
int sys_mkdir(const char *p, int mode);
int sys_rmdir(const char *p);
int sys_chdir(const char *p);
struct boot_timespec { long tv_sec; long tv_nsec; };
struct boot_stat { int st_dev; unsigned int st_ino; unsigned short st_mode; unsigned short st_nlink; unsigned int st_uid; unsigned int st_gid; int st_rdev; struct boot_timespec st_atimespec; struct boot_timespec st_mtimespec; struct boot_timespec st_ctimespec; struct boot_timespec st_birthtimespec; long st_size; long st_blocks; int st_blksize; unsigned int st_flags; unsigned int st_gen; int st_lspare; long st_qspare[2]; };
struct darwin_stat64 { int st_dev; unsigned short st_mode; unsigned short st_nlink; unsigned long st_ino; unsigned int st_uid; unsigned int st_gid; int st_rdev; int __pad0; long st_atime; long st_atimensec; long st_mtime; long st_mtimensec; long st_ctime; long st_ctimensec; long st_birthtime; long st_birthtimensec; long st_size; long st_blocks; int st_blksize; unsigned int st_flags; unsigned int st_gen; int st_lspare; long st_qspare[2]; };
static int stat_result(int r) { if (r < 0) { errno = -r; return -1; } return 0; }
static int copy_stat_result(int r, void *st, struct darwin_stat64 *k) { struct boot_stat *s = st; if (stat_result(r) < 0) return -1; if (s) { memset(s, 0, sizeof(*s)); s->st_dev = k->st_dev; s->st_ino = k->st_ino; s->st_mode = k->st_mode; s->st_nlink = k->st_nlink; s->st_uid = k->st_uid; s->st_gid = k->st_gid; s->st_rdev = k->st_rdev; s->st_atimespec.tv_sec = k->st_atime; s->st_atimespec.tv_nsec = k->st_atimensec; s->st_mtimespec.tv_sec = k->st_mtime; s->st_mtimespec.tv_nsec = k->st_mtimensec; s->st_ctimespec.tv_sec = k->st_ctime; s->st_ctimespec.tv_nsec = k->st_ctimensec; s->st_birthtimespec.tv_sec = k->st_birthtime; s->st_birthtimespec.tv_nsec = k->st_birthtimensec; s->st_size = k->st_size; s->st_blocks = k->st_blocks; s->st_blksize = k->st_blksize; s->st_flags = k->st_flags; s->st_gen = k->st_gen; s->st_lspare = k->st_lspare; s->st_qspare[0] = k->st_qspare[0]; s->st_qspare[1] = k->st_qspare[1]; } return 0; }
int fstat(int fd, void *st) { struct darwin_stat64 k; return copy_stat_result(sys_fstat64(fd, &k), st, &k); }
int stat(const char *p, void *st) { struct darwin_stat64 k; return copy_stat_result(sys_stat64(p, &k), st, &k); }
int lstat(const char *p, void *st) { struct darwin_stat64 k; return copy_stat_result(sys_lstat64(p, &k), st, &k); }
int access(const char *p, int mode) { struct boot_stat st; return stat(p, &st); }
int chmod(const char *p, int mode) { return 0; }
int chown(const char *p, unsigned int uid, unsigned int gid) { return 0; }
int lchown(const char *p, unsigned int uid, unsigned int gid) { return chown(p, uid, gid); }
int fchown(int fd, unsigned int uid, unsigned int gid) { return 0; }
int mkdir(const char *p, int mode) { return stat_result(sys_mkdir(p, mode)); }
int utime(const char *p, const void *times) { return 0; }
int utimes(const char *p, const void *times) { return 0; }
char *mktemp(char *template) { return template; }
char *getenv(const char *n) { size_t len; char **e; if (!n || !*n) return 0; len = strlen(n); for (e = environ; e && *e; e++) if (!strncmp(*e, n, len) && (*e)[len] == '=') return *e + len + 1; return 0; }
char *getcwd(char *b, size_t n) { if (n >= 2) { b[0] = '.'; b[1] = 0; return b; } return 0; }
char *getwd(char *b) { return getcwd(b, 1024); }
int chdir(const char *p) { return stat_result(sys_chdir(p)); }
int fchdir(int fd) { return 0; }
char *getlogin(void) { return 0; }
int geteuid(void) { return 0; }
int getuid(void) { return 0; }
int getegid(void) { return 0; }
int getgid(void) { return 0; }
int getpid(void) { return 1; }
int isatty(int fd) { return 0; }
char *ttyname(int fd) { return 0; }
int sleep(unsigned int seconds) { return 0; }
int nanosleep(const void *req, void *rem) { return 0; }
unsigned int alarm(unsigned int seconds) { return 0; }
int umask(int mask) { return 0; }
int rmdir(const char *path) { return stat_result(sys_rmdir(path)); }
long readlink(const char *path, char *buf, unsigned long size) { return -1; }
void *getpwnam(const char *name) { return 0; }
void *getpwuid(unsigned int uid) { return 0; }
void *getgrnam(const char *name) { return 0; }
void *getgrgid(unsigned int gid) { return 0; }
struct boot_dirent { unsigned long d_ino; unsigned long d_seekoff; unsigned short d_reclen; unsigned short d_namlen; unsigned char d_type; char d_name[1024]; };
struct boot_DIR { int fd; long base; long size; long pos; char buf[8192]; struct boot_dirent ent; };
void *opendir(const char *name) { struct boot_DIR *d; int fd = open(name, 0, 0); if (fd < 0) return 0; d = malloc(sizeof(*d)); if (!d) { close(fd); return 0; } d->fd = fd; d->base = 0; d->size = 0; d->pos = 0; return d; }
void *readdir(void *dir) { struct boot_DIR *d = dir; struct boot_dirent *src; int i; long n; if (!d) return 0; if (d->pos >= d->size) { n = sys_getdirentries64(d->fd, d->buf, sizeof(d->buf), &d->base); if (n <= 0) return 0; d->size = n; d->pos = 0; } src = (struct boot_dirent *)(d->buf + d->pos); if (src->d_reclen == 0) return 0; d->pos += src->d_reclen; d->ent.d_ino = src->d_ino; d->ent.d_seekoff = src->d_seekoff; d->ent.d_reclen = src->d_reclen; d->ent.d_namlen = src->d_namlen; d->ent.d_type = src->d_type; for (i = 0; i < 1023 && i < d->ent.d_namlen; i++) d->ent.d_name[i] = src->d_name[i]; d->ent.d_name[i] = 0; return &d->ent; }
int closedir(void *dir) { struct boot_DIR *d = dir; int r; if (!d) return -1; r = close(d->fd); free(d); return r; }
int dirfd(void *dir) { return -1; }
int execve(const char *path, char *const argv[], char *const envp[]) { long r = sys_execve(path, argv, envp); if (r < 0) { errno = -r; return -1; } return r; }
int execv(const char *path, char *const argv[]) { return execve(path, argv, environ); }
int execl(const char *path, const char *arg, ...) { char *argv[2]; argv[0] = (char *)arg; argv[1] = 0; return execv(path, argv); }
int execlp(const char *file, const char *arg, ...) { char *argv[2]; argv[0] = (char *)arg; argv[1] = 0; return execvp(file, argv); }
int execvp(const char *f, char *const a[]) { char path[1024]; const char *dirs[3]; int i; if (strchr(f, '/')) return execve(f, a, environ); dirs[0] = "/bin/"; dirs[1] = "/usr/bin/"; dirs[2] = 0; for (i = 0; dirs[i]; i++) { strcpy(path, dirs[i]); strcat(path, f); execve(path, a, environ); } return -1; }
int fork(void) { long r = sys_fork(); if (r < 0) { errno = -r; return -1; } return r; }
int pipe(int *fds) { long r = sys_pipe(fds); if (r < 0) { errno = -r; return -1; } return r; }
int dup(int fd) { long r = sys_dup(fd); if (r < 0) { errno = -r; return -1; } return r; }
int dup2(int oldfd, int newfd) { long r = sys_dup2(oldfd, newfd); if (r < 0) { errno = -r; return -1; } return r; }
int fsync(int fd) { return 0; }
int fdatasync(int fd) { return 0; }
int ftruncate(int fd, long length) { return 0; }
int wait4(int pid, int *status, int options, void *rusage) { long r = sys_wait4(pid, status, options, rusage); if (r < 0) { errno = -r; return -1; } return r; }
int wait(int *status) { return wait4(-1, status, 0, 0); }
int waitpid(int pid, int *status, int options) { return wait4(pid, status, options, 0); }
int kill(int pid, int sig) { return -1; }
int sigemptyset(long *set) { if (set) *set = 0; return 0; }
int sigaddset(long *set, int sig) { if (set) *set |= 1L << sig; return 0; }
int sigprocmask(int how, const long *set, long *oldset) { if (oldset) *oldset = 0; return 0; }
int fcntl(int fd, int cmd, long arg) { long r = sys_fcntl(fd, cmd, arg); if (r < 0) { errno = -r; return -1; } return r; }
void sync(void) { }
int gettimeofday(void *tv, void *tz) { if (tv) { long *p = tv; p[0] = 0; p[1] = 0; } return 0; }
int settimeofday(const void *tv, const void *tz) { return 0; }
struct boot_tm { int tm_sec; int tm_min; int tm_hour; int tm_mday; int tm_mon; int tm_year; int tm_wday; int tm_yday; int tm_isdst; };
struct boot_lconv { char *decimal_point; char *thousands_sep; char *grouping; char *int_curr_symbol; char *currency_symbol; char *mon_decimal_point; char *mon_thousands_sep; char *mon_grouping; char *positive_sign; char *negative_sign; char int_frac_digits; char frac_digits; char p_cs_precedes; char p_sep_by_space; char n_cs_precedes; char n_sep_by_space; char p_sign_posn; char n_sign_posn; };
static struct boot_tm epoch_tm = { 0, 0, 0, 1, 0, 70, 4, 0, 0 };
static struct boot_lconv c_lconv = { ".", "", "", "", "", "", "", "", "", "", 127, 127, 127, 127, 127, 127, 127, 127 };
long time(long *t) { if (t) *t = 0; return 0; }
char *ctime(const long *t) { return "Thu Jan  1 00:00:00 1970\n"; }
char *asctime(const void *tm) { return "Thu Jan  1 00:00:00 1970\n"; }
size_t strftime(char *s, size_t max, const char *fmt, const void *tm) { if (max) s[0] = 0; return 0; }
long clock(void) { return 0; }
void *localtime(const long *t) { return &epoch_tm; }
void *gmtime(const long *t) { return &epoch_tm; }
long mktime(void *tm) { return 0; }
char *setlocale(int category, const char *locale) { return "C"; }
struct boot_lconv *localeconv(void) { return &c_lconv; }
void *signal(int sig, void *handler) { return handler; }
int sigaction(int sig, const void *act, void *oldact) { if (oldact) memset(oldact, 0, sizeof(long) * 4); return 0; }
int raise(int sig) { return 0; }
int atexit(void (*fn)(void)) { return 0; }
int putenv(char *s) { return 0; }
int system(const char *s) { return -1; }
float strtof(const char *s, char **e) { if (e) *e = (char *)s; return 0; }
double atof(const char *s) { return 0; }
double strtod(const char *s, char **e) { if (e) *e = (char *)s; return 0; }
double ldexp(double x, int e) { return x; }
double frexp(double x, int *e) { if (e) *e = 0; return x; }
double fabs(double x) { return x < 0 ? -x : x; }
double log(double x) { double y, y2, term, sum; int k = 0, n; if (x <= 0) return 0; while (x > 1.5) { x *= 0.5; k++; } while (x < 0.75) { x *= 2.0; k--; } y = (x - 1.0) / (x + 1.0); y2 = y * y; term = y; sum = 0.0; for (n = 1; n < 60; n += 2) { sum += term / (double)n; term *= y2; } return 2.0 * sum + (double)k * 0.69314718055994530942; }
double exp(double x) { double term = 1.0, sum = 1.0, factor = 1.0; int halve_count = 0, iter; if (x < 0) return 1.0 / exp(-x); while (x > 1.0) { x *= 0.5; halve_count++; } for (iter = 1; iter < 40; iter++) { term *= x / (double)iter; sum += term; } while (halve_count--) { factor = sum; sum = factor * factor; } return sum; }
/* NOTE: a 64-bit unsigned<->float cast (e.g. (double)x where x is unsigned
   long) is lowered by tcc into a call to the very runtime helper being
   defined here, which would make these functions recurse into themselves
   forever.  tcc emits *inline* hardware conversions only for the *signed*
   64-bit and the 32-bit casts, so we implement the unsigned 64-bit helpers
   in terms of signed 64-bit casts plus the standard shift/sticky-bit trick.
   The signed helpers (__floatdidf/__fixdfdi) compile to inline cvtsi2sd /
   cvttsd2si and are safe as plain casts. */
double __floatundidf(unsigned long x) {
    if ((long)x >= 0) return (double)(long)x;
    return (double)(long)((x >> 1) | (x & 1)) * 2.0;
}
double __floatdidf(long x) { return (double)x; }
long double __floatundixf(unsigned long x) {
    if ((long)x >= 0) return (long double)(long)x;
    return (long double)(long)((x >> 1) | (x & 1)) * 2.0L;
}
unsigned long __fixunsdfdi(double x) {
    if (x < 0) return 0;
    if (x < 9223372036854775808.0) return (unsigned long)(long)x;
    return (unsigned long)(long)(x - 9223372036854775808.0)
         + 0x8000000000000000UL;
}
long __fixdfdi(double x) { return (long)x; }
unsigned long __fixunsxfdi(long double x) {
    if (x < 0) return 0;
    if (x < 9223372036854775808.0L) return (unsigned long)(long)x;
    return (unsigned long)(long)(x - 9223372036854775808.0L)
         + 0x8000000000000000UL;
}
int sscanf(const char *s, const char *fmt, long a, long b, long c_arg, long d)
{
    long args[4];
    int assigned = 0, argi = 0;
    args[0] = a; args[1] = b; args[2] = c_arg; args[3] = d;
    while (*fmt) {
        if (isspace(*fmt)) {
            while (isspace(*fmt)) fmt++;
            while (isspace(*s)) s++;
            continue;
        }
        if (*fmt != '%') {
            if (*s != *fmt) return assigned;
            s++; fmt++;
            continue;
        }
        fmt++;
        if (*fmt == '%') {
            if (*s != '%') return assigned;
            s++; fmt++;
            continue;
        }
        int longflag = 0;
        while (*fmt == 'h' || *fmt == 'l' || *fmt == 'L' || *fmt == 'z' || *fmt == 't' || *fmt == 'j') {
            if (*fmt == 'l' || *fmt == 'L' || *fmt == 'z' || *fmt == 't' || *fmt == 'j') longflag = 1;
            fmt++;
        }
        if (argi >= 4) return assigned;
        if (*fmt == 'd' || *fmt == 'i' || *fmt == 'u' || *fmt == 'x') {
            char *end;
            int base = *fmt == 'x' ? 16 : 10;
            long value;
            while (isspace(*s)) s++;
            if (base == 16 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) s += 2;
            value = strtol(s, &end, base);
            if (end == s) return assigned;
            if (longflag) *(long *)args[argi++] = value;
            else *(int *)args[argi++] = (int)value;
            assigned++;
            s = end;
        } else if (*fmt == 's') {
            char *out = (char *)args[argi++];
            while (isspace(*s)) s++;
            if (!*s) return assigned;
            while (*s && !isspace(*s)) *out++ = *s++;
            *out = 0;
            assigned++;
        } else if (*fmt == 'c') {
            *(char *)args[argi++] = *s++;
            assigned++;
        } else return assigned;
        if (*fmt) fmt++;
    }
    return assigned;
}
int sprintf(char *b, const char *f, ...) { __va_list_struct ap; __va_start(&ap, __builtin_frame_address(0)); return format_buffer_va(b, (size_t)-1, f, &ap); }
int snprintf(char *b, size_t n, const char *f, ...) { __va_list_struct ap; __va_start(&ap, __builtin_frame_address(0)); return format_buffer_va(b, n, f, &ap); }
int vsprintf(char *b, const char *f, void *ap) { return format_buffer_va(b, (size_t)-1, f, (__va_list_struct *)ap); }
int vsnprintf(char *b, size_t n, const char *f, void *ap) { return format_buffer_va(b, n, f, (__va_list_struct *)ap); }
int vasprintf(char **out, const char *f, void *ap) { *out = malloc(4096); return *out ? vsnprintf(*out, 4096, f, ap) : -1; }
void unlock_std_streams(void) { }
int setjmp(void *env) { return 0; }
void longjmp(void *env, int val) { _exit(2); }

/* libgcc unwinder stubs.  This toolchain does not implement DWARF exception
 * unwinding (the as-filter drops .eh_frame/.gcc_except_tab), so C++ exceptions
 * cannot propagate.  These symbols are referenced by libstdc++'s cleanup paths
 * but are only reached when an exception is actually thrown; provide stubs so
 * non-throwing C++ programs link.  If reached, abort loudly. */
void _Unwind_Resume(void *exc) { fputs("_Unwind_Resume: C++ exceptions unsupported\n", stderr); _exit(134); }
long _Unwind_Resume_or_Rethrow(void *exc) { fputs("_Unwind_Resume_or_Rethrow: C++ exceptions unsupported\n", stderr); _exit(134); return 0; }
long _Unwind_RaiseException(void *exc) { fputs("_Unwind_RaiseException: C++ exceptions unsupported\n", stderr); _exit(134); return 0; }
void _Unwind_DeleteException(void *exc) { }
long _Unwind_GetLanguageSpecificData(void *ctx) { return 0; }
long _Unwind_GetRegionStart(void *ctx) { return 0; }
long _Unwind_GetIPInfo(void *ctx, int *ip_before) { if (ip_before) *ip_before = 0; return 0; }
long _Unwind_GetIP(void *ctx) { return 0; }
void _Unwind_SetIP(void *ctx, long v) { }
long _Unwind_GetGR(void *ctx, int i) { return 0; }
void _Unwind_SetGR(void *ctx, int i, long v) { }
long _Unwind_GetTextRelBase(void *ctx) { return 0; }
long _Unwind_GetDataRelBase(void *ctx) { return 0; }
long _Unwind_GetCFA(void *ctx) { return 0; }

/* fnmatch(3): shell glob matching.  gcc-10's genattrtab uses fnmatch(pat, name,
 * 0) for define_bypass patterns.  libiberty ships a fallback fnmatch.c but it
 * compiles to nothing once configure sees our <fnmatch.h> (HAVE_FNMATCH), so we
 * must provide the symbol here.  Returns 0 on match, 1 (FNM_NOMATCH) otherwise.
 * Supports * ? [..] ranges/negation and backslash escapes; honours FNM_NOESCAPE
 * (0x01) and FNM_PATHNAME (0x02). */
int fnmatch(const char *p, const char *s, int flags) {
  for (;;) {
    char pc = *p;
    p = p + 1;
    if (pc == 0) {
      return (*s == 0) ? 0 : 1;
    } else if (pc == '?') {
      if (*s == 0) return 1;
      if ((flags & 0x02) && *s == '/') return 1;
      s = s + 1;
    } else if (pc == '*') {
      while (*p == '*') p = p + 1;
      if (*p == 0) {
        if (flags & 0x02) {
          const char *t = s;
          while (*t) { if (*t == '/') return 1; t = t + 1; }
        }
        return 0;
      }
      while (*s) {
        if (fnmatch(p, s, flags) == 0) return 0;
        if ((flags & 0x02) && *s == '/') break;
        s = s + 1;
      }
      return fnmatch(p, s, flags);
    } else if (pc == '[') {
      int neg = 0;
      int matched = 0;
      int first = 1;
      char sc = *s;
      if (sc == 0) return 1;
      if ((flags & 0x02) && sc == '/') return 1;
      if (*p == '!' || *p == '^') { neg = 1; p = p + 1; }
      while (*p && (*p != ']' || first)) {
        char lo = *p;
        if (lo == '\\' && !(flags & 0x01) && p[1]) { lo = p[1]; p = p + 2; }
        else p = p + 1;
        if (*p == '-' && p[1] != ']' && p[1] != 0) {
          char hi = p[1];
          if (hi == '\\' && !(flags & 0x01) && p[2]) { hi = p[2]; p = p + 3; }
          else p = p + 2;
          if ((unsigned char)sc >= (unsigned char)lo &&
              (unsigned char)sc <= (unsigned char)hi) matched = 1;
        } else {
          if (sc == lo) matched = 1;
        }
        first = 0;
      }
      if (*p == ']') p = p + 1;
      if (matched == neg) return 1;
      s = s + 1;
    } else if (pc == '\\' && !(flags & 0x01)) {
      char lit = *p;
      p = p + 1;
      if (lit == 0) return 1;
      if (*s != lit) return 1;
      s = s + 1;
    } else {
      if (*s != pc) return 1;
      s = s + 1;
    }
  }
}

/* libgcc helper: gcc-10's cc1 emits a call to __popcountdi2 for
   __builtin_popcountll when the target has no popcnt insn (we build with
   -mno-sse3 and no -mpopcnt).  Simple bit loop — correctness over speed,
   and it avoids the 64-bit multiply/magic-constant trick. */
int __popcountdi2(long long a) {
  unsigned long long x = (unsigned long long)a;
  int count = 0;
  while (x) { count = count + (int)(x & 1); x = x >> 1; }
  return count;
}

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
static int ungot_fd = -1;
static int ungot_ch = -1;

extern long write(int fd, const void *buf, unsigned long n);
extern long read(int fd, void *buf, unsigned long n);
extern long open(const char *path, int flags, int mode);
extern long close(int fd);
extern long lseek(int fd, long off, int whence);
extern long unlink(const char *path);
extern long sys_rename(const char *old, const char *new);
extern long execve(const char *path, char *const argv[], char *const envp[]);
extern long fork(void);
extern long wait4(int pid, int *status, int options, void *rusage);
extern void _exit(int code);
extern void *mmap(void *addr, unsigned long len, int prot, int flags, int fd, long off);
void *memcpy(void *d, const void *s, size_t n);
void *memmove(void *d, const void *s, size_t n);
void *memset(void *d, int c, size_t n);

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
char *strpbrk(const char *s, const char *accept) { while (*s) { const char *a = accept; while (*a) { if (*s == *a++) return (char *)s; } s++; } return 0; }
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
int tolower(int c) { return isupper(c) ? c - 'A' + 'a' : c; }
int toupper(int c) { return islower(c) ? c - 'a' + 'A' : c; }
int strcasecmp(const char *a, const char *b) { while (*a && tolower(*a) == tolower(*b)) { a++; b++; } return tolower(*(unsigned char *)a) - tolower(*(unsigned char *)b); }
int strncasecmp(const char *a, const char *b, unsigned long n) { while (n && *a && tolower(*a) == tolower(*b)) { a++; b++; n--; } return n ? tolower(*(unsigned char *)a) - tolower(*(unsigned char *)b) : 0; }

long strtol(const char *s, char **e, int base) { long neg = 0, v = 0; if (*s == '-') { neg = 1; s++; } if (base == 0) base = 10; while ((*s >= '0' && *s <= '9') || (*s >= 'a' && *s <= 'f') || (*s >= 'A' && *s <= 'F')) { int d = (*s <= '9') ? *s - '0' : ((*s <= 'F') ? *s - 'A' + 10 : *s - 'a' + 10); if (d >= base) break; v = v * base + d; s++; } if (e) *e = (char *)s; return neg ? -v : v; }
unsigned long strtoul(const char *s, char **e, int b) { return (unsigned long)strtol(s, e, b); }
long long strtoll(const char *s, char **e, int b) { return (long long)strtol(s, e, b); }
unsigned long long strtoull(const char *s, char **e, int b) { return (unsigned long long)strtoul(s, e, b); }
int atoi(const char *s) { return (int)strtol(s, 0, 10); }
int abs(int x) { return x < 0 ? -x : x; }
void qsort(void *base, size_t n, size_t size, int (*cmp)(const void *, const void *)) { }

static int append_char(char *b, size_t n, size_t *pos, int c) { if (*pos + 1 < n) b[*pos] = c; (*pos)++; return 1; }
static int append_str(char *b, size_t n, size_t *pos, const char *s) { int count = 0; if (!s) s = "(null)"; if ((unsigned long)s < 4096) s = "(bad)"; while (*s) { append_char(b, n, pos, *s++); count++; } return count; }
static int append_num(char *b, size_t n, size_t *pos, long v, int base) { char tmp[32]; int i = 0, neg = 0, count = 0; unsigned long x; if (v < 0 && base == 10) { neg = 1; x = -v; } else x = v; do { int d = x % base; tmp[i++] = d < 10 ? '0' + d : 'a' + d - 10; x /= base; } while (x); if (neg) tmp[i++] = '-'; while (i--) { append_char(b, n, pos, tmp[i]); count++; } return count; }
static int format_buffer_words(char *b, size_t n, const char *fmt, long *args) { size_t pos = 0; while (*fmt) { if (*fmt != '%') { append_char(b, n, &pos, *fmt++); continue; } fmt++; if (*fmt == 'l') fmt++; if (*fmt == 'l') fmt++; if (*fmt == 's') append_str(b, n, &pos, (char *)*args++); else if (*fmt == 'd' || *fmt == 'i') append_num(b, n, &pos, *args++, 10); else if (*fmt == 'x' || *fmt == 'p') append_num(b, n, &pos, *args++, 16); else if (*fmt == 'c') append_char(b, n, &pos, *args++); else if (*fmt == '%') append_char(b, n, &pos, '%'); else append_char(b, n, &pos, *fmt); fmt++; } if (n) b[pos < n ? pos : n - 1] = 0; return pos; }
static long next_va_long(__va_list_struct *ap) { return *(long *)__va_arg(ap, __va_gen_reg, 8, 8); }
static int format_buffer_va(char *b, size_t n, const char *fmt, __va_list_struct *ap) { size_t pos = 0; while (*fmt) { if (*fmt != '%') { append_char(b, n, &pos, *fmt++); continue; } fmt++; if (*fmt == 'l') fmt++; if (*fmt == 'l') fmt++; if (*fmt == 's') append_str(b, n, &pos, (char *)next_va_long(ap)); else if (*fmt == 'd' || *fmt == 'i') append_num(b, n, &pos, next_va_long(ap), 10); else if (*fmt == 'x' || *fmt == 'p') append_num(b, n, &pos, next_va_long(ap), 16); else if (*fmt == 'c') append_char(b, n, &pos, next_va_long(ap)); else if (*fmt == '%') append_char(b, n, &pos, '%'); else append_char(b, n, &pos, *fmt); fmt++; } if (n) b[pos < n ? pos : n - 1] = 0; return pos; }
static void putnum(int fd, long v, int base) { char b[32]; size_t pos = 0; append_num(b, sizeof(b), &pos, v, base); write(fd, b, pos); }
static int fmt_fd(int fd, const char *fmt, long a, long b, long c, long d) { long args[4]; int ai = 0; args[0] = a; args[1] = b; args[2] = c; args[3] = d; while (*fmt) { if (*fmt != '%') { write(fd, fmt, 1); fmt++; continue; } fmt++; if (*fmt == 'l') fmt++; if (*fmt == 'l') fmt++; if (*fmt == 's') { char *s = (char *)args[ai++]; if (!s) s = "(null)"; write(fd, s, strlen(s)); } else if (*fmt == 'd' || *fmt == 'i') putnum(fd, args[ai++], 10); else if (*fmt == 'x' || *fmt == 'p') putnum(fd, args[ai++], 16); else if (*fmt == 'c') { char ch = args[ai++]; write(fd, &ch, 1); } else if (*fmt == '%') write(fd, "%", 1); fmt++; } return 0; }
int printf(const char *fmt, long a, long b, long c, long d) { return fmt_fd(1, fmt, a, b, c, d); }
int fprintf(FILE *f, const char *fmt, long a, long b, long c, long d) { return fmt_fd(file_fd(f), fmt, a, b, c, d); }
int vfprintf(FILE *f, const char *fmt, void *ap) { char b[4096]; int n = format_buffer_va(b, sizeof(b), fmt, (__va_list_struct *)ap); write(file_fd(f), b, n); return n; }
void perror(const char *s) { if (s) { write(2, s, strlen(s)); write(2, ": ", 2); } write(2, "error\n", 6); }

int fputs(const char *s, FILE *f) { return write(file_fd(f), s, strlen(s)); }
int puts(const char *s) { int r = write(1, s, strlen(s)); write(1, "\n", 1); return r + 1; }
int fputc(int c, FILE *f) { char ch = c; return write(file_fd(f), &ch, 1); }
int putc(int c, FILE *f) { return fputc(c, f); }
int putchar(int c) { return fputc(c, stdout); }
int getc(FILE *f) { unsigned char ch; int fd = file_fd(f); if (ungot_fd == fd && ungot_ch >= 0) { ch = ungot_ch; ungot_ch = -1; return ch; } return read(fd, &ch, 1) == 1 ? ch : -1; }
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
int feof(FILE *f) { return 0; }
int ferror(FILE *f) { return 0; }
int setvbuf(FILE *f, char *b, int mode, size_t size) { return 0; }
int fseek(FILE *f, long o, int w) { return lseek(file_fd(f), o, w) < 0 ? -1 : 0; }
long ftell(FILE *f) { return lseek(file_fd(f), 0, 1); }
FILE *popen(const char *cmd, const char *mode) { return 0; }
int pclose(FILE *f) { return -1; }

static int scan_space(int c) { return c == ' ' || c == '\n' || c == '\t' || c == '\r' || c == '\f' || c == '\v'; }
static int scan_set_has(const char *set, int set_len, int c) { int i; for (i = 0; i < set_len; i++) if (set[i] == c) return 1; return 0; }
static int scan_fail_result(int matched, int c) { return c < 0 && matched == 0 ? -1 : matched; }
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
        return matched;
    }
    return matched;
}

int remove(const char *p) { return unlink(p); }
int creat(const char *p, int mode) { return open(p, 0x601, mode); }
int rename(const char *old, const char *new) { char buf[4096]; long n; int in, out; if (sys_rename(old, new) == 0) return 0; in = open(old, 0, 0); if (in < 0) return -1; unlink(new); out = open(new, 0x601, 0666); if (out < 0) { close(in); return -1; } while ((n = read(in, buf, sizeof(buf))) > 0) if (write(out, buf, n) != n) { close(in); close(out); return -1; } close(in); close(out); if (n < 0) return -1; unlink(old); return 0; }
struct boot_stat { unsigned long st_dev; unsigned long st_ino; unsigned int st_mode; unsigned int st_nlink; unsigned int st_uid; unsigned int st_gid; unsigned long st_rdev; long st_size; long st_atime; long st_mtime; long st_ctime; };
static void fill_regular_stat(void *st, long size) { struct boot_stat *s = st; if (s) { memset(s, 0, sizeof(*s)); s->st_mode = 0100000 | 0644; s->st_nlink = 1; s->st_size = size; } }
int fstat(int fd, void *st) { long cur, end; if (fd <= 2) { errno = 9; return -1; } cur = lseek(fd, 0, 1); end = lseek(fd, 0, 2); if (cur >= 0) lseek(fd, cur, 0); fill_regular_stat(st, end < 0 ? 0 : end); return 0; }
int stat(const char *p, void *st) { int fd = open(p, 0, 0); int r; if (fd < 0) { errno = 2; return -1; } r = fstat(fd, st); close(fd); return r; }
int access(const char *p, int mode) { struct boot_stat st; return stat(p, &st); }
int chmod(const char *p, int mode) { return 0; }
int chown(const char *p, unsigned int uid, unsigned int gid) { return 0; }
int mkdir(const char *p, int mode) { return 0; }
int utime(const char *p, const void *times) { return 0; }
char *mktemp(char *template) { return template; }
char *getenv(const char *n) { return 0; }
char *getcwd(char *b, size_t n) { if (n >= 2) { b[0] = '.'; b[1] = 0; return b; } return 0; }
int chdir(const char *p) { return 0; }
char *getlogin(void) { return 0; }
int geteuid(void) { return 0; }
int getpid(void) { return 1; }
int isatty(int fd) { return 0; }
char *ttyname(int fd) { return 0; }
int sleep(unsigned int seconds) { return 0; }
unsigned int alarm(unsigned int seconds) { return 0; }
int umask(int mask) { return 0; }
int rmdir(const char *path) { return 0; }
long readlink(const char *path, char *buf, unsigned long size) { return -1; }
void *getpwnam(const char *name) { return 0; }
void *getpwuid(unsigned int uid) { return 0; }
void *getgrnam(const char *name) { return 0; }
void *getgrgid(unsigned int gid) { return 0; }
void *opendir(const char *name) { return 0; }
void *readdir(void *dir) { return 0; }
int closedir(void *dir) { return 0; }
int execvp(const char *f, char *const a[]) { char path[1024]; const char *dirs[3]; int i; if (strchr(f, '/')) return execve(f, a, environ); dirs[0] = "/bin/"; dirs[1] = "/usr/bin/"; dirs[2] = 0; for (i = 0; dirs[i]; i++) { strcpy(path, dirs[i]); strcat(path, f); execve(path, a, environ); } return -1; }
int pipe(int *fds) { return -1; }
int dup(int fd) { return fd; }
int dup2(int oldfd, int newfd) { return newfd; }
int wait(int *status) { return wait4(-1, status, 0, 0); }
int waitpid(int pid, int *status, int options) { return wait4(pid, status, options, 0); }
int kill(int pid, int sig) { return -1; }
int sigemptyset(long *set) { if (set) *set = 0; return 0; }
int sigaddset(long *set, int sig) { if (set) *set |= 1L << sig; return 0; }
int sigprocmask(int how, const long *set, long *oldset) { if (oldset) *oldset = 0; return 0; }
int fcntl(int fd, int cmd, long arg) { return 0; }
int gettimeofday(void *tv, void *tz) { if (tv) { long *p = tv; p[0] = 0; p[1] = 0; } return 0; }
struct boot_tm { int tm_sec; int tm_min; int tm_hour; int tm_mday; int tm_mon; int tm_year; int tm_wday; int tm_yday; int tm_isdst; };
static struct boot_tm epoch_tm = { 0, 0, 0, 1, 0, 70, 4, 0, 0 };
long time(long *t) { if (t) *t = 0; return 0; }
char *ctime(const long *t) { return "Thu Jan  1 00:00:00 1970\n"; }
long clock(void) { return 0; }
void *localtime(const long *t) { return &epoch_tm; }
void *gmtime(const long *t) { return &epoch_tm; }
long mktime(void *tm) { return 0; }
char *setlocale(int category, const char *locale) { return "C"; }
void *signal(int sig, void *handler) { return handler; }
int sigaction(int sig, const void *act, void *oldact) { if (oldact) memset(oldact, 0, sizeof(long) * 4); return 0; }
int raise(int sig) { return 0; }
int atexit(void (*fn)(void)) { return 0; }
int putenv(char *s) { return 0; }
int system(const char *s) { return -1; }
float strtof(const char *s, char **e) { if (e) *e = (char *)s; return 0; }
double atof(const char *s) { return 0; }
double ldexp(double x, int e) { return x; }
double frexp(double x, int *e) { if (e) *e = 0; return x; }
double __floatundidf(unsigned long x) { return (double)x; }
double __floatdidf(long x) { return (double)x; }
unsigned long __fixunsdfdi(double x) { return (unsigned long)x; }
long __fixdfdi(double x) { return (long)x; }
int sscanf(const char *s, const char *f, long a, long b) { return 0; }
int sprintf(char *b, const char *f, long a, long c, long d, long e) { long args[4]; args[0] = a; args[1] = c; args[2] = d; args[3] = e; return format_buffer_words(b, (size_t)-1, f, args); }
int snprintf(char *b, size_t n, const char *f, long a, long c, long d) { long args[3]; args[0] = a; args[1] = c; args[2] = d; return format_buffer_words(b, n, f, args); }
int vsprintf(char *b, const char *f, void *ap) { return format_buffer_va(b, (size_t)-1, f, (__va_list_struct *)ap); }
int vsnprintf(char *b, size_t n, const char *f, void *ap) { return format_buffer_va(b, n, f, (__va_list_struct *)ap); }
int vasprintf(char **out, const char *f, void *ap) { *out = malloc(4096); return *out ? vsnprintf(*out, 4096, f, ap) : -1; }
void unlock_std_streams(void) { }
void longjmp(void *env, int val) { _exit(2); }

#ifndef _DARWIN_BOOTSTRAP_STDLIB_H
#define _DARWIN_BOOTSTRAP_STDLIB_H
typedef unsigned long size_t;
#ifndef __cplusplus
typedef int wchar_t;
#endif
#ifndef NULL
#ifdef __cplusplus
/* __null (not bare 0): an int 0 is passed as 32 bits in a variadic call, so
 * a `foo(..., NULL)` sentinel leaves the high 4 bytes of the arg slot as stack
 * garbage -> the callee reads a bogus 8-byte pointer.  __null is pointer-width. */
#define NULL __null
#else
#define NULL ((void *)0)
#endif
#endif
typedef struct { int quot; int rem; } div_t;
typedef struct { long quot; long rem; } ldiv_t;
#ifdef __cplusplus
extern "C" {
#endif
void abort(void);
#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1
#ifndef RAND_MAX
#define RAND_MAX 2147483647
#endif
#ifndef MB_CUR_MAX
#define MB_CUR_MAX 1
#endif
#ifndef MB_CUR_MAX_L
#define MB_CUR_MAX_L(x) (1)
#endif
int system(const char *);
void exit(int);
void _exit(int);
int atexit(void (*)(void));
void free(void *);
char *getenv(const char *);
void *malloc(size_t);
void *aligned_alloc(size_t, size_t);
int posix_memalign(void **, size_t, size_t);
void *calloc(size_t, size_t);
void *realloc(void *, size_t);
int abs(int);
long labs(long);
long long llabs(long long);
div_t div(int, int);
ldiv_t ldiv(long, long);
int rand(void);
void srand(unsigned int);
int mblen(const char *, size_t);
size_t mbstowcs(wchar_t *, const char *, size_t);
int mbtowc(wchar_t *, const char *, size_t);
long strtol(const char *, char **, int);
unsigned long strtoul(const char *, char **, int);
long long strtoll(const char *, char **, int);
unsigned long long strtoull(const char *, char **, int);
double strtod(const char *, char **);
double atof(const char *);
int atoi(const char *);
long atol(const char *);
long long atoll(const char *);
int putenv(char *);
char *mktemp(char *);
void *bsearch(const void *, const void *, size_t, size_t, int (*)(const void *, const void *));
void qsort(void *, size_t, size_t, int (*)(const void *, const void *));
#ifdef __cplusplus
}
#endif
#endif

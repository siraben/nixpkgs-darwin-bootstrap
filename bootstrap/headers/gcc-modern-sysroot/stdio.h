#ifndef _DARWIN_BOOTSTRAP_STDIO_H
#define _DARWIN_BOOTSTRAP_STDIO_H
#define _STDIO_H 1
#define EOF (-1)
#define BUFSIZ 1024
#define _IONBF 0
#define _IOLBF 1
#define _IOFBF 2
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
struct __sbuf { unsigned char *_base; int _size; };
struct __sFILE { unsigned char *_p; int _r; int _w; short _flags; short _file; struct __sbuf _bf; int _lbfsize; void *_cookie; int (*_close)(void *); int (*_read)(void *, char *, int); long (*_seek)(void *, long, int); int (*_write)(void *, const char *, int); struct __sbuf _ub; void *_extra; int _ur; unsigned char _ubuf[3]; unsigned char _nbuf[1]; struct __sbuf _lb; int _blksize; long _offset; };
typedef struct __sFILE FILE;
#define __sferror(p) (((p)->_flags & 0x0040) != 0)
typedef long fpos_t;
typedef unsigned long size_t;
#ifndef NULL
#ifdef __cplusplus
#define NULL 0
#else
#define NULL ((void *)0)
#endif
#endif
#include <stdarg.h>
#if defined(__TINYC__) && !defined(TCC_DARWIN_REAL_STDIO_GLOBALS)
#define stdin ((FILE *)0)
#define stdout ((FILE *)1)
#define stderr ((FILE *)2)
#else
extern FILE *__stdinp;
extern FILE *__stdoutp;
extern FILE *__stderrp;
#define stdin __stdinp
#define stdout __stdoutp
#define stderr __stderrp
#endif
#ifdef __cplusplus
extern "C" {
#endif
int printf(const char *, ...);
int fprintf(FILE *, const char *, ...);
int vfprintf(FILE *, const char *, va_list);
void perror(const char *);
int fscanf(FILE *, const char *, ...);
int scanf(const char *, ...);
int sscanf(const char *, const char *, ...);
int sprintf(char *, const char *, ...);
int vprintf(const char *, va_list);
int snprintf(char *, size_t, const char *, ...);
int vsprintf(char *, const char *, va_list);
int vsnprintf(char *, size_t, const char *, va_list);
int vasprintf(char **, const char *, va_list);
FILE *fopen(const char *, const char *);
FILE *fopen_unlocked(const char *, const char *);
FILE *freopen(const char *, const char *, FILE *);
FILE *fdopen(int, const char *);
int fclose(FILE *);
int ferror(FILE *);
int fputs(const char *, FILE *);
int puts(const char *);
int fputc(int, FILE *);
int fgetc(FILE *);
int putchar(int);
int getchar(void);
void setbuf(FILE *, char *);
int getc(FILE *);
char *fgets(char *, int, FILE *);
char *gets(char *);
int fgetpos(FILE *, fpos_t *);
int fsetpos(FILE *, const fpos_t *);
int ungetc(int, FILE *);
int putc(int, FILE *);
int fflush(FILE *);
void clearerr(FILE *);
void clearerr_unlocked(FILE *);
int feof_unlocked(FILE *);
int ferror_unlocked(FILE *);
int fflush_unlocked(FILE *);
int fgetc_unlocked(FILE *);
char *fgets_unlocked(char *, int, FILE *);
int fileno_unlocked(FILE *);
int fputc_unlocked(int, FILE *);
int fputs_unlocked(const char *, FILE *);
size_t fread_unlocked(void *, size_t, size_t, FILE *);
size_t fwrite_unlocked(const void *, size_t, size_t, FILE *);
int getchar_unlocked(void);
int getc_unlocked(FILE *);
int putchar_unlocked(int);
int putc_unlocked(int, FILE *);
size_t fread(void *, size_t, size_t, FILE *);
size_t fwrite(const void *, size_t, size_t, FILE *);
int feof(FILE *);
int fseek(FILE *, long, int);
int fseeko(FILE *, long, int);
long ftell(FILE *);
void rewind(FILE *);
int fileno(FILE *);
int remove(const char *);
int rename(const char *, const char *);
int setvbuf(FILE *, char *, int, size_t);
FILE *tmpfile(void);
char *tmpnam(char *);
FILE *popen(const char *, const char *);
int pclose(FILE *);
#ifdef __cplusplus
}
#endif
#endif

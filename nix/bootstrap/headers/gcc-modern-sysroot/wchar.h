#ifndef _DARWIN_BOOTSTRAP_WCHAR_H
#define _DARWIN_BOOTSTRAP_WCHAR_H
#include <stddef.h>
typedef int wchar_t;
typedef int wint_t;
typedef struct { unsigned char __opaque[16]; } mbstate_t;
#ifndef WEOF
#define WEOF ((wint_t)-1)
#endif
size_t mbsrtowcs(wchar_t *, const char **, size_t, mbstate_t *);
int wprintf(const wchar_t *, ...);
int wcwidth(wchar_t);
#endif

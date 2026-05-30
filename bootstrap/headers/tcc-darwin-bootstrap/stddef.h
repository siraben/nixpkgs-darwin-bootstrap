#ifndef _DARWIN_BOOTSTRAP_STDDEF_H
#define _DARWIN_BOOTSTRAP_STDDEF_H
typedef unsigned long size_t;
typedef long ptrdiff_t;
typedef long ssize_t;
typedef long intptr_t;
typedef unsigned long uintptr_t;
#ifndef __cplusplus
typedef int wchar_t;
#endif
#ifndef _WINT_T
#define _WINT_T
typedef int wint_t;   /* Darwin: __darwin_wint_t == int; needed by mpfr vasprintf */
#endif
#ifndef NULL
#ifdef __cplusplus
#define NULL 0
#else
#define NULL ((void *)0)
#endif
#endif
#define offsetof(type, field) ((size_t)&((type *)0)->field)
#endif

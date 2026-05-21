#ifndef _DARWIN_BOOTSTRAP_STDDEF_H
#define _DARWIN_BOOTSTRAP_STDDEF_H
typedef unsigned long size_t;
typedef long ptrdiff_t;
typedef long ssize_t;
typedef long intptr_t;
typedef unsigned long uintptr_t;
typedef int wchar_t;
#ifndef NULL
#ifdef __cplusplus
#define NULL 0
#else
#define NULL ((void *)0)
#endif
#endif
#define offsetof(type, field) ((size_t)&((type *)0)->field)
#endif

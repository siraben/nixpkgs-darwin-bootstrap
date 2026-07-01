#ifndef _DARWIN_BOOTSTRAP_WCTYPE_H
#define _DARWIN_BOOTSTRAP_WCTYPE_H
#include <ctype.h>
#include <wchar.h>
typedef unsigned long wctype_t;
typedef int wctrans_t;
static inline int __darwin_bootstrap_wchar_byte(wint_t wc) { return wc >= 0 && wc <= 255; }
static inline int iswalnum(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isalnum((int)wc) : 0; }
static inline int iswalpha(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isalpha((int)wc) : 0; }
static inline int iswblank(wint_t wc) { return wc == ' ' || wc == '\t'; }
static inline int iswcntrl(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? iscntrl((int)wc) : 0; }
static inline int iswdigit(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isdigit((int)wc) : 0; }
static inline int iswgraph(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isgraph((int)wc) : 0; }
static inline int iswlower(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? islower((int)wc) : 0; }
static inline int iswprint(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isprint((int)wc) : 0; }
static inline int iswpunct(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? ispunct((int)wc) : 0; }
static inline int iswspace(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isspace((int)wc) : 0; }
static inline int iswupper(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isupper((int)wc) : 0; }
static inline int iswxdigit(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isxdigit((int)wc) : 0; }
static inline wint_t towlower(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? tolower((int)wc) : wc; }
static inline wint_t towupper(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? toupper((int)wc) : wc; }
static inline wctype_t wctype(const char *name) { (void)name; return 0; }
static inline int iswctype(wint_t wc, wctype_t desc) { (void)wc; (void)desc; return 0; }
static inline wctrans_t wctrans(const char *name) { (void)name; return 0; }
static inline wint_t towctrans(wint_t wc, wctrans_t desc) { (void)desc; return wc; }
#endif

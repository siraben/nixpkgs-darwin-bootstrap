#ifndef _DARWIN_BOOTSTRAP_XLOCALE_H
#define _DARWIN_BOOTSTRAP_XLOCALE_H
typedef void *locale_t;
#define LC_GLOBAL_LOCALE ((locale_t)-1)
#define LC_C_LOCALE ((locale_t)0)
#define LC_ALL_MASK 0x3f
#ifndef MB_CUR_MAX_L
#define MB_CUR_MAX_L(x) (1)
#endif
locale_t newlocale(int, const char *, locale_t);
void freelocale(locale_t);
locale_t uselocale(locale_t);
#endif

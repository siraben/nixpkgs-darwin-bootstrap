#ifndef _DARWIN_BOOTSTRAP_INTTYPES_H
#define _DARWIN_BOOTSTRAP_INTTYPES_H
#include <stdint.h>
/* printf/scanf format macros.  int32_t==int, int64_t==long long,
 * intptr_t==long, intmax_t==long long (see stdint.h). */
#define PRId8  "d"
#define PRIi8  "i"
#define PRIu8  "u"
#define PRIx8  "x"
#define PRId16 "d"
#define PRIi16 "i"
#define PRIu16 "u"
#define PRIx16 "x"
#define PRId32 "d"
#define PRIi32 "i"
#define PRIu32 "u"
#define PRIo32 "o"
#define PRIx32 "x"
#define PRIX32 "X"
#define PRId64 "lld"
#define PRIi64 "lli"
#define PRIu64 "llu"
#define PRIo64 "llo"
#define PRIx64 "llx"
#define PRIX64 "llX"
#define PRIdPTR "ld"
#define PRIiPTR "li"
#define PRIuPTR "lu"
#define PRIxPTR "lx"
#define PRIdMAX "lld"
#define PRIiMAX "lli"
#define PRIuMAX "llu"
#define PRIxMAX "llx"
#define PRIXMAX "llX"
#define SCNd64 "lld"
#define SCNi64 "lli"
#define SCNu64 "llu"
#define SCNx64 "llx"
typedef struct { intmax_t quot; intmax_t rem; } imaxdiv_t;
intmax_t strtoimax(const char *, char **, int);
uintmax_t strtoumax(const char *, char **, int);
intmax_t imaxabs(intmax_t);
#endif

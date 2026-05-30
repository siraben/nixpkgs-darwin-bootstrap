#ifndef _DARWIN_BOOTSTRAP_STRINGS_H
#define _DARWIN_BOOTSTRAP_STRINGS_H
#include <string.h>
#ifdef __cplusplus
extern "C" {
#endif
int bcmp(const void *, const void *, unsigned long);
void bcopy(const void *, void *, unsigned long);
void bzero(void *, unsigned long);
char *index(const char *, int);
char *rindex(const char *, int);
int strcasecmp(const char *, const char *);
int strncasecmp(const char *, const char *, unsigned long);
int ffs(int);
int ffsl(long);
int ffsll(long long);
#ifdef __cplusplus
}
#endif
#endif

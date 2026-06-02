#ifndef _DARWIN_BOOTSTRAP_FTW_H
#define _DARWIN_BOOTSTRAP_FTW_H
#ifdef __cplusplus
extern "C" {
#endif
#include <sys/stat.h>
#define FTW_F 0
#define FTW_D 1
#define FTW_DNR 2
#define FTW_NS 3
#define FTW_SL 4
#define FTW_DP 6
#define FTW_SLN 7
#define FTW_PHYS 0x01
#define FTW_MOUNT 0x02
#define FTW_DEPTH 0x04
#define FTW_CHDIR 0x08
struct FTW { int base; int level; };
int ftw(const char *, int (*)(const char *, const struct stat *, int), int);
int nftw(const char *, int (*)(const char *, const struct stat *, int, struct FTW *), int, int);
#ifdef __cplusplus
}
#endif
#endif

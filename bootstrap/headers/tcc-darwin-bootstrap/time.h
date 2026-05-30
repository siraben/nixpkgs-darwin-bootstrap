#ifndef _DARWIN_BOOTSTRAP_TIME_H
#define _DARWIN_BOOTSTRAP_TIME_H
#include <stddef.h>   /* size_t (used by strftime) */
typedef long time_t;
typedef long clock_t;
#ifndef _STRUCT_TIMESPEC
#define _STRUCT_TIMESPEC struct timespec
struct timespec { long tv_sec; long tv_nsec; };
#endif
struct tm { int tm_sec; int tm_min; int tm_hour; int tm_mday; int tm_mon; int tm_year; int tm_wday; int tm_yday; int tm_isdst; };
#ifdef __cplusplus
extern "C" {
#endif
time_t time(time_t *);
clock_t clock(void);
struct tm *localtime(const time_t *);
struct tm *gmtime(const time_t *);
time_t mktime(struct tm *);
double difftime(time_t, time_t);
char *ctime(const time_t *);
char *asctime(const struct tm *);
size_t strftime(char *, size_t, const char *, const struct tm *);
int nanosleep(const struct timespec *, struct timespec *);
#ifndef CLOCK_REALTIME
#define CLOCK_REALTIME 0
#endif
int clock_gettime(int, struct timespec *);
#ifndef TIME_UTC
#define TIME_UTC 1
#endif
int timespec_get(struct timespec *, int);
#ifdef __cplusplus
}
#endif
#endif

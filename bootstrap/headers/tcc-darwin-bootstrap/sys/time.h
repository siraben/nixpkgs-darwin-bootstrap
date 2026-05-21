#ifndef _DARWIN_BOOTSTRAP_SYS_TIME_H
#define _DARWIN_BOOTSTRAP_SYS_TIME_H
struct timeval { long tv_sec; long tv_usec; };
struct timezone { int tz_minuteswest; int tz_dsttime; };
int gettimeofday(struct timeval *, struct timezone *);
int settimeofday(const struct timeval *, const struct timezone *);
int utimes(const char *, const struct timeval *);
#endif

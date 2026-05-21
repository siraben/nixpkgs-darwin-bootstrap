#ifndef _DARWIN_BOOTSTRAP_UTIME_H
#define _DARWIN_BOOTSTRAP_UTIME_H
typedef long time_t;
struct utimbuf { time_t actime; time_t modtime; };
int utime(const char *, const struct utimbuf *);
#endif

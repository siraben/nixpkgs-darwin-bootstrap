#ifndef _DARWIN_BOOTSTRAP_SYS_RESOURCE_H
#define _DARWIN_BOOTSTRAP_SYS_RESOURCE_H
#include <sys/time.h>
#define RUSAGE_SELF 0
#define RUSAGE_CHILDREN -1
#define RLIMIT_CORE 4
#define RLIMIT_NOFILE 8
#define RLIM_INFINITY 9223372036854775807UL
struct rusage { struct timeval ru_utime; struct timeval ru_stime; long ru_maxrss; long ru_ixrss; long ru_idrss; long ru_isrss; long ru_minflt; long ru_majflt; long ru_nswap; long ru_inblock; long ru_oublock; long ru_msgsnd; long ru_msgrcv; long ru_nsignals; long ru_nvcsw; long ru_nivcsw; long ru_reserved[16]; };
struct rlimit { unsigned long rlim_cur; unsigned long rlim_max; };
int getrusage(int, struct rusage *);
int getrlimit(int, struct rlimit *);
int setrlimit(int, const struct rlimit *);
#endif

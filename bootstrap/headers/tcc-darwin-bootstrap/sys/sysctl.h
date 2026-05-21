#ifndef _DARWIN_BOOTSTRAP_SYS_SYSCTL_H
#define _DARWIN_BOOTSTRAP_SYS_SYSCTL_H
#include <sys/types.h>
#define CTL_KERN 1
#define KERN_OSRELEASE 2
int sysctl(int *, unsigned int, void *, size_t *, void *, size_t);
#endif

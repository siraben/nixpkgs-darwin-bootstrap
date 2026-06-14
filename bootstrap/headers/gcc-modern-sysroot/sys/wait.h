#ifndef _DARWIN_BOOTSTRAP_SYS_WAIT_H
#define _DARWIN_BOOTSTRAP_SYS_WAIT_H
#ifdef __cplusplus
extern "C" {
#endif
#include <sys/resource.h>
#define WNOHANG 1
int wait(int *);
int wait4(int, int *, int, struct rusage *);
int waitpid(int, int *, int);
#ifdef __cplusplus
}
#endif
#endif

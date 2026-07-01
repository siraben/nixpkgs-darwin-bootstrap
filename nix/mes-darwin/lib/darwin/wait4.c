#include <mes/lib.h>
#include <darwin/x86_64/syscall.h>
#include <sys/types.h>
#include <sys/resource.h>

pid_t
wait4 (pid_t pid, int *status_ptr, int options, struct rusage *rusage)
{
  return _sys_call4 (SYS_wait4, pid, cast_voidp_to_long (status_ptr), options,
                     cast_voidp_to_long (rusage));
}

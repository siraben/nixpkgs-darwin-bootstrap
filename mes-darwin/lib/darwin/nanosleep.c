#include <darwin/x86_64/syscall.h>
#include <time.h>

int
nanosleep (struct timespec const *requested_time, struct timespec const *remaining)
{
  return _sys_call2 (SYS_nanosleep, requested_time, remaining);
}

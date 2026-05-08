#include <mes/lib.h>
#include <darwin/x86_64/syscall.h>
#include <sys/time.h>

int
gettimeofday (struct timeval *tv, struct timezone *tz)
{
  return _sys_call2 (SYS_gettimeofday, cast_voidp_to_long (tv),
                     cast_voidp_to_long (tz));
}

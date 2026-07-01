#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>

int
pipe (int filedes[2])
{
  return _sys_call1 (SYS_pipe, cast_voidp_to_long (filedes));
}

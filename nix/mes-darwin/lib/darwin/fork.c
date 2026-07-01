#include <darwin/x86_64/syscall.h>

int
fork ()
{
  return _sys_call (SYS_fork);
}

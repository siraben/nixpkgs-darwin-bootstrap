#include <darwin/x86_64/syscall.h>

int
fsync (int filedes)
{
  return _sys_call1 (SYS_fsync, filedes);
}

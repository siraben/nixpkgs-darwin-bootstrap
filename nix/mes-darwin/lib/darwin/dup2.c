#include <darwin/x86_64/syscall.h>

int
dup2 (int old, int new)
{
  return _sys_call2 (SYS_dup2, old, new);
}

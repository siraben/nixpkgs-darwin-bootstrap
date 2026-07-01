#include <darwin/x86_64/syscall.h>

int
dup (int old)
{
  return _sys_call1 (SYS_dup, old);
}

#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>

int
ioctl3 (int filedes, size_t command, long data)
{
  return _sys_call3 (SYS_ioctl, filedes, command, data);
}

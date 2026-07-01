#include <darwin/x86_64/syscall.h>
#include <stdarg.h>

int
fcntl (int filedes, int command, ...)
{
  va_list ap;
  va_start (ap, command);
  int data = va_arg (ap, int);
  int r = _sys_call3 (SYS_fcntl, filedes, command, data);
  va_end (ap);
  return r;
}

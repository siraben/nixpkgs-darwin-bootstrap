#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>

int
close (int filedes)
{
  __ungetc_clear (filedes);
  __buffered_read_clear (filedes);
  return _sys_call1 (SYS_close, filedes);
}

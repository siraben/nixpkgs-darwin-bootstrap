#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>

ssize_t
_read (int filedes, void *buffer, size_t size)
{
  return _sys_call3 (SYS_read, filedes, cast_voidp_to_long (buffer), size);
}

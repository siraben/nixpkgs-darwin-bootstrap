#include <mes/lib.h>
#include <darwin/x86_64/syscall.h>
#include <fcntl.h>

ssize_t
read (int filedes, void *buffer, size_t size)
{
  long long_filedes = filedes;
  long long_buffer = cast_voidp_to_long (buffer);
  return _sys_call3 (SYS_read, long_filedes, long_buffer, size);
}

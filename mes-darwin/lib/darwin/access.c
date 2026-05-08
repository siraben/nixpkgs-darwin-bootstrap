#include <mes/lib.h>
#include <darwin/x86_64/syscall.h>

int
access (char const *file_name, int how)
{
  return _sys_call2 (SYS_access, cast_charp_to_long (file_name), how);
}

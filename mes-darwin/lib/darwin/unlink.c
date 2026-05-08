#include <mes/lib.h>
#include <darwin/x86_64/syscall.h>

int
unlink (char const *file_name)
{
  return _sys_call1 (SYS_unlink, cast_charp_to_long (file_name));
}

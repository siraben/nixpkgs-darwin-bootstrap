#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>

int
rmdir (char const *file_name)
{
  return _sys_call1 (SYS_rmdir, cast_charp_to_long (file_name));
}

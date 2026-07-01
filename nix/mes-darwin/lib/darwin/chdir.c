#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>

int
chdir (char const *file_name)
{
  return _sys_call1 (SYS_chdir, cast_charp_to_long (file_name));
}

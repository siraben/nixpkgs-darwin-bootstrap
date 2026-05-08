#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>

int
rename (char const *old_name, char const *new_name)
{
  return _sys_call2 (SYS_rename, cast_charp_to_long (old_name),
                     cast_charp_to_long (new_name));
}

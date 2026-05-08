#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>
#include <sys/stat.h>

int
mkdir (char const *file_name, mode_t mode)
{
  return _sys_call2 (SYS_mkdir, cast_charp_to_long (file_name), mode);
}

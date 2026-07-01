#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>
#include <sys/stat.h>

int
stat (char const *file_name, struct stat *statbuf)
{
  return _sys_call2 (SYS_stat64, cast_charp_to_long (file_name),
                     cast_voidp_to_long (statbuf));
}

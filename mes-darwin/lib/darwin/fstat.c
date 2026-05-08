#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>
#include <sys/stat.h>

int
fstat (int filedes, struct stat *statbuf)
{
  return _sys_call2 (SYS_fstat64, filedes, cast_voidp_to_long (statbuf));
}

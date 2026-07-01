#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>
#include <sys/types.h>

int
getdents (int filedes, char *buffer, size_t nbytes)
{
  return _sys_call4 (SYS_getdirentries64, filedes, cast_charp_to_long (buffer),
                     nbytes, 0);
}

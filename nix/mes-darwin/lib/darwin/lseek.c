#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>
#include <stdio.h>
#include <sys/types.h>

off_t
_lseek (int filedes, off_t offset, int whence)
{
  return _sys_call3 (SYS_lseek, filedes, offset, whence);
}

off_t
lseek (int filedes, off_t offset, int whence)
{
  size_t skip = __buffered_read_clear (filedes);
  if (whence == SEEK_CUR)
    offset -= skip;
  return _sys_call3 (SYS_lseek, filedes, offset, whence);
}

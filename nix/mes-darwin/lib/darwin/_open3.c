#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>
#include <fcntl.h>
#include <errno.h>

int
__darwin_open_flags (int flags)
{
  int result = flags & 3;
  if (flags & 0x40)
    result = result | 0x200;
  if (flags & 0x80)
    result = result | 0x800;
  if (flags & 0x200)
    result = result | 0x400;
  if (flags & 0x400)
    result = result | 0x8;
  return result;
}

int
_open3 (char const *file_name, int flags, int mask)
{
  long long_file_name = cast_charp_to_long (file_name);
  int r = _sys_call3 (SYS_open, long_file_name, __darwin_open_flags (flags), mask);
  __ungetc_init ();
  if (r > 2)
    {
      if (r >= __FILEDES_MAX)
        {
          errno = EMFILE;
          return -1;
        }
      __ungetc_clear (r);
      __buffered_read_clear (r);
    }
  return r;
}

#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>
#include <fcntl.h>
#include <errno.h>

int __darwin_open_flags (int flags);

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

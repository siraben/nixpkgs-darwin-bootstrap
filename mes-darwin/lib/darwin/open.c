#include <darwin/x86_64/syscall.h>
#include <mes/lib.h>
#include <fcntl.h>
#include <stdarg.h>

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

#if __M2__
int
open (char *file_name, int flags, int mask)
{
  int r = _sys_call3 (SYS_open, file_name, __darwin_open_flags (flags), mask);
  if (r > 2)
    __ungetc_clear (r);
  return r;
}
#else
int
open (char const *file_name, int flags, ...)
{
  va_list ap;
  va_start (ap, flags);
  int mask = va_arg (ap, int);
  int r = _sys_call3 (SYS_open, (long) file_name, __darwin_open_flags (flags), mask);
  va_end (ap);
  if (r > 2)
    __ungetc_clear (r);
  return r;
}
#endif

#include <mes/lib.h>
#include <darwin/x86_64/syscall.h>

char *__darwin_brk;
char *__darwin_brk_end;

long
brk (void *addr)
{
  if (__darwin_brk == 0)
    {
      __darwin_brk = _sys_call6 (SYS_mmap, 0, 536870912, 3, 4098, -1, 0);
      if (__darwin_brk == -1)
        return -1;
      __darwin_brk_end = __darwin_brk + 536870912;
    }
  if (addr == 0)
    return cast_charp_to_long (__darwin_brk);
  if (__darwin_brk_end < addr)
    return -1;
  __darwin_brk = addr;
  return cast_voidp_to_long (addr);
}

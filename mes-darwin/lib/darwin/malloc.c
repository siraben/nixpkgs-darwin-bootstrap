#include <mes/lib.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>

char *__brk = 0;

void *
malloc (size_t size)
{
  if (!__brk)
    __brk = cast_long_to_charp (brk (0));
#if !__M2__
  __brk = (char*) (((uintptr_t) __brk
                    + sizeof (max_align_t) - 1) & -sizeof (max_align_t));
#endif
  if (brk (__brk + size) == -1)
    return 0;
  char *p = __brk;
  __brk = __brk + size;
  return p;
}

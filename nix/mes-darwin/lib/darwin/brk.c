#include <mes/lib.h>
#include <darwin/x86_64/syscall.h>

char *__darwin_brk;
char *__darwin_brk_end;

long
brk (void *addr)
{
  if (__darwin_brk == 0)
    {
      /* The whole mes-m2 heap is this one fixed anonymous mmap; every malloc
       * (this libc's malloc is a non-freeing bump allocator) draws from it,
       * including the GC cell arena AND mescc's compile-time allocations.  2 GB
       * was too small for the from-seed tcc.c compile (it exhausts mid-compile
       * -> malloc returns NULL -> gc.c SIGSEGVs).  Use 4 GB.
       *
       * The size MUST be computed at runtime in 64-bit longs: M2-Planet (which
       * compiles mes-m2) truncates integer literals > 2^31, so writing
       * 4000000000 directly yields a bad (negative) size and a failed mmap.
       * Doubling a sub-2^31 literal in `long` arithmetic stays correct.  The
       * mapping is lazy/zero-fill-on-demand, so only touched pages cost RAM. */
      long size = 1000000000;   /* 1 GB; safely < 2^31 as a literal */
      size = size + size;       /* 2 GB */
      size = size + size;       /* 4 GB */
      long mapped = _sys_call6 (SYS_mmap, 0, size, 3, 4098, -1, 0);
      if (mapped < 0)
        return -1;
      __darwin_brk = cast_long_to_charp (mapped);
      __darwin_brk_end = __darwin_brk + size;
    }
  if (addr == 0)
    return cast_charp_to_long (__darwin_brk);
  if (__darwin_brk_end < addr)
    return -1;
  __darwin_brk = addr;
  return cast_voidp_to_long (addr);
}

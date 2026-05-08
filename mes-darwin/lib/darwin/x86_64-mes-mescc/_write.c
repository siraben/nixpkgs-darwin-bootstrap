#include "mes/lib-mini.h"

void
_write (int filedes, void const *buffer, size_t size)
{
  asm ("mov____0x8(%rbp),%rdi !0x10");
  asm ("mov____0x8(%rbp),%rsi !0x18");
  asm ("mov____0x8(%rbp),%rdx !0x20");
  asm ("mov____$i32,%rax SYS_write");
  asm ("syscall");
}

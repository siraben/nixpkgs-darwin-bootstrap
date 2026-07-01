#include "mes/lib-mini.h"

void
_write (int filedes, void const *buffer, size_t size)
{
  asm ("mov____$i32,%rax SYS_write");
  asm ("mov____0x8(%rbp),%rdi !-8");
  asm ("mov____0x8(%rbp),%rsi !-16");
  asm ("mov____0x8(%rbp),%rdx !-24");
  asm ("syscall");
}

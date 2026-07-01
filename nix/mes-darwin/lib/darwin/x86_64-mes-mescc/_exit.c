#include "mes/lib-mini.h"

void
_exit (int status)
{
  asm ("mov____0x8(%rbp),%rdi !0x10");
  asm ("mov____$i32,%rax SYS_exit");
  asm ("syscall");
}

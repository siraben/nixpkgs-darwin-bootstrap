#include "mes/lib-mini.h"

void
_exit (int status)
{
  asm ("mov____$i32,%rax SYS_exit");
  asm ("mov____0x8(%rbp),%rdi !-8");
  asm ("syscall");
}

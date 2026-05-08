#include <darwin/x86_64/syscall.h>

static long
__sys_call_internal (long sys_call)
{
  asm ("mov____0x8(%rbp),%rax !0x10");
  asm ("syscall");
  asm ("jae32 %__sys_call_internal_ok");
  asm ("neg____%rax");
  asm (":__sys_call_internal_ok");
}

static long
__sys_call2_internal (long sys_call, long one, long two)
{
  asm ("mov____0x8(%rbp),%rax !0x10");
  asm ("mov____0x8(%rbp),%rdi !0x18");
  asm ("mov____0x8(%rbp),%rsi !0x20");
  asm ("syscall");
  asm ("jae32 %__sys_call2_internal_ok");
  asm ("neg____%rax");
  asm (":__sys_call2_internal_ok");
}

int
__raise (int signum)
{
  long pid = __sys_call_internal (SYS_getpid);
  if (pid < 0)
    return pid;
  return __sys_call2_internal (SYS_kill, pid, signum);
}

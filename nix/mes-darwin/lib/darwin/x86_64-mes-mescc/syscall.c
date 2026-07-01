#include <errno.h>
#include <darwin/x86_64/syscall.h>

long
__sys_call (long sys_call)
{
  asm ("mov____0x8(%rbp),%rax !0x10");
  asm ("syscall");
  asm ("jae32 %__sys_call_ok");
  asm ("neg____%rax");
  asm (":__sys_call_ok");
}

long
__sys_call1 (long sys_call, long one)
{
  asm ("mov____0x8(%rbp),%rax !0x10");
  asm ("mov____0x8(%rbp),%rdi !0x18");
  asm ("syscall");
  asm ("jae32 %__sys_call1_ok");
  asm ("neg____%rax");
  asm (":__sys_call1_ok");
}

long
__sys_call2 (long sys_call, long one, long two)
{
  asm ("mov____0x8(%rbp),%rax !0x10");
  asm ("mov____0x8(%rbp),%rdi !0x18");
  asm ("mov____0x8(%rbp),%rsi !0x20");
  asm ("syscall");
  asm ("jae32 %__sys_call2_ok");
  asm ("neg____%rax");
  asm (":__sys_call2_ok");
}

long
__sys_call3 (long sys_call, long one, long two, long three)
{
  asm ("mov____0x8(%rbp),%rax !0x10");
  asm ("mov____0x8(%rbp),%rdi !0x18");
  asm ("mov____0x8(%rbp),%rsi !0x20");
  asm ("mov____0x8(%rbp),%rdx !0x28");
  asm ("syscall");
  asm ("jae32 %__sys_call3_ok");
  asm ("neg____%rax");
  asm (":__sys_call3_ok");
}

long
__sys_call4 (long sys_call, long one, long two, long three, long four)
{
  asm ("mov____0x8(%rbp),%rax !0x10");
  asm ("mov____0x8(%rbp),%rdi !0x18");
  asm ("mov____0x8(%rbp),%rsi !0x20");
  asm ("mov____0x8(%rbp),%rdx !0x28");
  asm ("mov____0x8(%rbp),%r10 !0x30");
  asm ("syscall");
  asm ("jae32 %__sys_call4_ok");
  asm ("neg____%rax");
  asm (":__sys_call4_ok");
}

long
__sys_call5 (long sys_call, long one, long two, long three, long four, long five)
{
  asm ("mov____0x8(%rbp),%rax !0x10");
  asm ("mov____0x8(%rbp),%rdi !0x18");
  asm ("mov____0x8(%rbp),%rsi !0x20");
  asm ("mov____0x8(%rbp),%rdx !0x28");
  asm ("mov____0x8(%rbp),%r10 !0x30");
  asm ("mov____0x8(%rbp),%r8 !0x38");
  asm ("syscall");
  asm ("jae32 %__sys_call5_ok");
  asm ("neg____%rax");
  asm (":__sys_call5_ok");
}

long
__sys_call6 (long sys_call, long one, long two, long three, long four, long five, long six)
{
  asm ("mov____0x8(%rbp),%rax !0x10");
  asm ("mov____0x8(%rbp),%rdi !0x18");
  asm ("mov____0x8(%rbp),%rsi !0x20");
  asm ("mov____0x8(%rbp),%rdx !0x28");
  asm ("mov____0x8(%rbp),%r10 !0x30");
  asm ("mov____0x8(%rbp),%r8 !0x38");
  asm ("lea_r9,[rbp+DWORD] %0x40");
  asm ("mov_r9,[r9]");
  asm ("syscall");
  asm ("jae32 %__sys_call6_ok");
  asm ("neg____%rax");
  asm (":__sys_call6_ok");
}

long
_sys_call (long sys_call)
{
  long r = __sys_call (sys_call);
  errno = 0;
  if (r < 0)
    {
      errno = -r;
      r = -1;
    }
  return r;
}

long
_sys_call1 (long sys_call, long one)
{
  long r = __sys_call1 (sys_call, one);
  errno = 0;
  if (r < 0)
    {
      errno = -r;
      r = -1;
    }
  return r;
}

long
_sys_call2 (long sys_call, long one, long two)
{
  long r = __sys_call2 (sys_call, one, two);
  errno = 0;
  if (r < 0)
    {
      errno = -r;
      r = -1;
    }
  return r;
}

long
_sys_call3 (long sys_call, long one, long two, long three)
{
  long r = __sys_call3 (sys_call, one, two, three);
  errno = 0;
  if (r < 0)
    {
      errno = -r;
      r = -1;
    }
  return r;
}

long
_sys_call4 (long sys_call, long one, long two, long three, long four)
{
  long r = __sys_call4 (sys_call, one, two, three, four);
  errno = 0;
  if (r < 0)
    {
      errno = -r;
      r = -1;
    }
  return r;
}

long
_sys_call5 (long sys_call, long one, long two, long three, long four, long five)
{
  long r = __sys_call5 (sys_call, one, two, three, four, five);
  errno = 0;
  if (r < 0)
    {
      errno = -r;
      r = -1;
    }
  return r;
}

long
_sys_call6 (long sys_call, long one, long two, long three, long four, long five, long six)
{
  long r = __sys_call6 (sys_call, one, two, three, four, five, six);
  errno = 0;
  if (r < 0)
    {
      errno = -r;
      r = -1;
    }
  return r;
}

#include <darwin/x86_64/syscall.h>
#include <unistd.h>

int
kill (pid_t pid, int signum)
{
  return _sys_call2 (SYS_kill, pid, signum);
}

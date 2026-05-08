#include <darwin/x86_64/syscall.h>
#include <unistd.h>

pid_t
getpid ()
{
  return _sys_call (SYS_getpid);
}

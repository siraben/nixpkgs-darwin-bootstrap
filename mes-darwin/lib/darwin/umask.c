#include <darwin/x86_64/syscall.h>
#include <sys/stat.h>

mode_t
umask (mode_t mask)
{
  return _sys_call1 (SYS_umask, mask);
}

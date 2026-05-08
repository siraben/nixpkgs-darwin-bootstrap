#include <darwin/x86_64/syscall.h>

int
execve (char const *file_name, char **argv, char **env)
{
  return _sys_call3 (SYS_execve, file_name, argv, env);
}

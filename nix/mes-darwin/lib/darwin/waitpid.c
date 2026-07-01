#include <sys/types.h>

pid_t
waitpid (pid_t pid, int *status_ptr, int options)
{
  return wait4 (pid, status_ptr, options, 0);
}

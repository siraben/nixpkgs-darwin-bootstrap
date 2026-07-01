#include <mes/lib.h>
#include <darwin/x86_64/syscall.h>
#include <sys/stat.h>

int
chmod (char const *file_name, mode_t mask)
{
  return _sys_call2 (SYS_chmod, cast_charp_to_long (file_name), mask);
}

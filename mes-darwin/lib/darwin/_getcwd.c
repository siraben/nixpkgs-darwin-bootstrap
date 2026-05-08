#include <mes/lib.h>

char *
_getcwd (char *buffer, size_t size)
{
  if (size < 2)
    return 0;
  buffer[0] = '.';
  buffer[1] = 0;
  return buffer;
}

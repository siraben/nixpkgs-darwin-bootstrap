#include <sys/time.h>
#include <time.h>

time_t
time (time_t *result)
{
  struct timeval tv;
  struct timezone tz;
  if (gettimeofday (&tv, &tz) != 0)
    return (time_t) -1;
  if (result)
    *result = tv.tv_sec;
  return tv.tv_sec;
}

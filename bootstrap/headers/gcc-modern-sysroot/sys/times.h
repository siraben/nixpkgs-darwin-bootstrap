#ifndef _DARWIN_BOOTSTRAP_SYS_TIMES_H
#define _DARWIN_BOOTSTRAP_SYS_TIMES_H
#ifdef __cplusplus
extern "C" {
#endif
typedef long clock_t;
struct tms {
  clock_t tms_utime;
  clock_t tms_stime;
  clock_t tms_cutime;
  clock_t tms_cstime;
};
clock_t times(struct tms *);
#ifdef __cplusplus
}
#endif
#endif

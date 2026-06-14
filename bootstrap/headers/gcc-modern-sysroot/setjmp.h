#ifndef _DARWIN_BOOTSTRAP_SETJMP_H
#define _DARWIN_BOOTSTRAP_SETJMP_H
#ifdef __cplusplus
extern "C" {
#endif
typedef long jmp_buf[32];
int setjmp(jmp_buf);
void longjmp(jmp_buf, int);
#ifdef __cplusplus
}
#endif
#endif

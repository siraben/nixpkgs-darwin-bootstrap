#ifndef _DARWIN_BOOTSTRAP_CTYPE_H
#define _DARWIN_BOOTSTRAP_CTYPE_H
#define DARWIN_BOOTSTRAP_CTYPE_BITS 1
#define _CTYPE_B 0x00000001L
#define _CTYPE_A 0x00000100L
#define _CTYPE_C 0x00000200L
#define _CTYPE_D 0x00000400L
#define _CTYPE_G 0x00000800L
#define _CTYPE_L 0x00001000L
#define _CTYPE_P 0x00002000L
#define _CTYPE_S 0x00004000L
#define _CTYPE_U 0x00008000L
#define _CTYPE_X 0x00010000L
#define _CTYPE_R 0x00040000L
#define _A _CTYPE_A
#define _C _CTYPE_C
#define _D _CTYPE_D
#define _G _CTYPE_G
#define _L _CTYPE_L
#define _P _CTYPE_P
#define _S _CTYPE_S
#define _U _CTYPE_U
#define _X _CTYPE_X
#define _R _CTYPE_R
#define _B _CTYPE_B
static inline unsigned long __darwin_bootstrap_ctype_mask(int c) {
  unsigned long m = 0;
  unsigned int u = (unsigned char)c;
  if (u < 32 || u == 127) m |= _CTYPE_C;
  if (u == ' ' || (u >= 9 && u <= 13)) m |= _CTYPE_S;
  if (u >= '0' && u <= '9') m |= _CTYPE_D | _CTYPE_X;
  if (u >= 'A' && u <= 'Z') m |= _CTYPE_U | _CTYPE_A;
  if (u >= 'a' && u <= 'z') m |= _CTYPE_L | _CTYPE_A;
  if ((u >= 'A' && u <= 'F') || (u >= 'a' && u <= 'f')) m |= _CTYPE_X;
  if (u >= 32 && u <= 126) m |= _CTYPE_R;
  if (u >= 33 && u <= 126) m |= _CTYPE_G;
  if ((m & (_CTYPE_A | _CTYPE_D | _CTYPE_S | _CTYPE_C)) == 0 && u >= 33 && u <= 126) m |= _CTYPE_P;
  return m;
}
static inline unsigned long __darwin_bootstrap_maskrune(int c, unsigned long f) { return __darwin_bootstrap_ctype_mask(c) & f; }
#define __maskrune(c, f) __darwin_bootstrap_maskrune((c), (f))
#define __istype(c, f) (__darwin_bootstrap_maskrune((c), (f)) != 0)
#ifdef __cplusplus
extern "C" {
#endif
int isalnum(int);
int isalpha(int);
int iscntrl(int);
int isdigit(int);
int isgraph(int);
int islower(int);
int isprint(int);
int ispunct(int);
int isspace(int);
int isupper(int);
int isxdigit(int);
int isascii(int);
int tolower(int);
int toupper(int);
#ifdef __cplusplus
}
#endif
#endif

#ifndef __MES_DARWIN_X86_64_SIGNAL_H
#define __MES_DARWIN_X86_64_SIGNAL_H 1

typedef long long greg_t;
typedef long long gregset_t[32];

typedef struct
{
  gregset_t gregs;
} mcontext_t;

typedef struct __ucontext
{
  unsigned long uc_flags;
  struct __ucontext *uc_link;
  stack_t uc_stack;
  mcontext_t uc_mcontext;
  sigset_t uc_sigmask;
} ucontext_t;

#endif

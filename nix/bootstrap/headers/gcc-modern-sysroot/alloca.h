#ifndef _DARWIN_BOOTSTRAP_ALLOCA_H
#define _DARWIN_BOOTSTRAP_ALLOCA_H
void *malloc(unsigned long);
#define alloca malloc
#endif

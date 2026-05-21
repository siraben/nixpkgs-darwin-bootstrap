#ifndef _DARWIN_BOOTSTRAP_SYS_MMAN_H
#define _DARWIN_BOOTSTRAP_SYS_MMAN_H
#include <sys/types.h>
#define PROT_NONE 0
#define PROT_READ 1
#define PROT_WRITE 2
#define PROT_EXEC 4
#define MAP_SHARED 1
#define MAP_PRIVATE 2
#define MAP_FIXED 0x10
#define MAP_ANON 0x1000
#define MAP_ANONYMOUS MAP_ANON
#define MAP_FAILED ((void *)-1)
#define MADV_RANDOM 1
void *mmap(void *, size_t, int, int, int, off_t);
int munmap(void *, size_t);
int mprotect(void *, size_t, int);
int madvise(void *, size_t, int);
#endif

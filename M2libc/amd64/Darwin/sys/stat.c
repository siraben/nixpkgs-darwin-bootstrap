/* AMD64 Darwin syscalls for the M2libc POSIX layer. */

#ifndef __DARWIN_AMD64_SYS_STAT_C
#define __DARWIN_AMD64_SYS_STAT_C

#include <sys/types.h>

#define S_IRWXU 00700
#define S_IXUSR 00100
#define S_IWUSR 00200
#define S_IRUSR 00400

#define S_ISUID 04000
#define S_ISGID 02000
#define S_IXGRP 00010
#define S_IXOTH 00001
#define S_IRGRP 00040
#define S_IROTH 00004
#define S_IWGRP 00020
#define S_IWOTH 00002
#define S_IRWXG 00070
#define S_IRWXO 00007

int chmod(char *pathname, int mode)
{
	asm("lea_rdi,[rsp+DWORD] %16"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %8"
	    "mov_rsi,[rsi]"
	    "mov_rax, %0x200000F"
	    "syscall");
}

int fchmod(int a, mode_t b)
{
	asm("lea_rdi,[rsp+DWORD] %16"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %8"
	    "mov_rsi,[rsi]"
	    "mov_rax, %0x200007C"
	    "syscall");
}

int mkdir(char const* a, mode_t b)
{
	asm("lea_rdi,[rsp+DWORD] %16"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %8"
	    "mov_rsi,[rsi]"
	    "mov_rax, %0x2000088"
	    "syscall");
}

int mknod(char const* a, mode_t b, dev_t c)
{
	asm("lea_rdi,[rsp+DWORD] %24"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %16"
	    "mov_rsi,[rsi]"
	    "lea_rdx,[rsp+DWORD] %8"
	    "mov_rdx,[rdx]"
	    "mov_rax, %0x200000E"
	    "syscall");
}

mode_t umask(mode_t m)
{
	asm("lea_rdi,[rsp+DWORD] %8"
	    "mov_rdi,[rdi]"
	    "mov_rax, %0x200003C"
	    "syscall");
}

#endif

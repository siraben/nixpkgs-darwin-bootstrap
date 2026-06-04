/* AMD64 Darwin syscalls for the M2libc POSIX layer. */

#ifndef __DARWIN_AMD64_UNISTD_C
#define __DARWIN_AMD64_UNISTD_C

#include <sys/utsname.h>

#define NULL 0
#define __PATH_MAX 4096

void* malloc(unsigned size);

int access(char* pathname, int mode)
{
	asm("lea_rdi,[rsp+DWORD] %16"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %8"
	    "mov_rsi,[rsi]"
	    "mov_rax, %0x2000021"
	    "syscall");
}

int chdir(char* path)
{
	asm("lea_rdi,[rsp+DWORD] %8"
	    "mov_rdi,[rdi]"
	    "mov_rax, %0x200000C"
	    "syscall");
}

int fchdir(int fd)
{
	asm("lea_rdi,[rsp+DWORD] %8"
	    "mov_rdi,[rdi]"
	    "mov_rax, %0x200000D"
	    "syscall");
}

void _exit(int value);

int fork()
{
	asm("mov_rax, %0x2000002"
	    "syscall");
}

int waitpid(int pid, int* status_ptr, int options)
{
	asm("lea_rdi,[rsp+DWORD] %24"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %16"
	    "mov_rsi,[rsi]"
	    "lea_rdx,[rsp+DWORD] %8"
	    "mov_rdx,[rdx]"
	    "mov_r10, %0"
	    "mov_rax, %0x2000007"
	    "syscall");
}

int execve(char* file_name, char** argv, char** envp)
{
	asm("lea_rdi,[rsp+DWORD] %24"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %16"
	    "mov_rsi,[rsi]"
	    "lea_rdx,[rsp+DWORD] %8"
	    "mov_rdx,[rdx]"
	    "mov_rax, %0x200003B"
	    "syscall");
}

int read(int fd, char* buf, unsigned count)
{
	asm("lea_rdi,[rsp+DWORD] %24"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %16"
	    "mov_rsi,[rsi]"
	    "lea_rdx,[rsp+DWORD] %8"
	    "mov_rdx,[rdx]"
	    "mov_rax, %0x2000003"
	    "syscall");
}

int write(int fd, char* buf, unsigned count)
{
	asm("lea_rdi,[rsp+DWORD] %24"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %16"
	    "mov_rsi,[rsi]"
	    "lea_rdx,[rsp+DWORD] %8"
	    "mov_rdx,[rdx]"
	    "mov_rax, %0x2000004"
	    "syscall");
}

int lseek(int fd, int offset, int whence)
{
	asm("lea_rdi,[rsp+DWORD] %24"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %16"
	    "mov_rsi,[rsi]"
	    "lea_rdx,[rsp+DWORD] %8"
	    "mov_rdx,[rdx]"
	    "mov_rax, %0x20000C7"
	    "syscall");
}

int close(int fd)
{
	asm("lea_rdi,[rsp+DWORD] %8"
	    "mov_rdi,[rdi]"
	    "mov_rax, %0x2000006"
	    "syscall");
}

int unlink(char* filename)
{
	asm("lea_rdi,[rsp+DWORD] %8"
	    "mov_rdi,[rdi]"
	    "mov_rax, %0x200000A"
	    "syscall");
}

int symlink(char *path1, char *path2)
{
	asm("lea_rdi,[rsp+DWORD] %16"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %8"
	    "mov_rsi,[rsi]"
	    "mov_rax, %0x2000039"
	    "syscall");
}

char* getcwd(char* buf, unsigned size)
{
	if(size < 2) return NULL;
	buf[0] = '.';
	buf[1] = 0;
	return buf;
}

char* getwd(char* buf)
{
	return getcwd(buf, __PATH_MAX);
}

char* get_current_dir_name()
{
	return getcwd(malloc(__PATH_MAX), __PATH_MAX);
}

long __darwin_brk_ptr;
long __darwin_brk_end;

void* __darwin_mmap(void* addr, int length, int prot, int flags, int fd, int offset)
{
	asm("lea_rdi,[rsp+DWORD] %48"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %40"
	    "mov_rsi,[rsi]"
	    "lea_rdx,[rsp+DWORD] %32"
	    "mov_rdx,[rdx]"
	    "lea_r10,[rsp+DWORD] %24"
	    "mov_r10,[r10]"
	    "lea_r8,[rsp+DWORD] %16"
	    "mov_r8,[r8]"
	    "lea_r9,[rsp+DWORD] %8"
	    "mov_r9,[r9]"
	    "mov_rax, %0x20000C5"
	    "syscall");
}

int brk(void *addr)
{
	if(NULL == __darwin_brk_ptr)
	{
		/* 4 GB heap.  The gcc-10 cc1 link's combined M1 (~335 MB) plus
		 * m1-to-hex2's label/output tables overflow the old 1.79 GB pool and
		 * malloc would silently return NULL -> the tool crashes mid-link.
		 * Computed at runtime: M2-Planet/cc_* truncate integer literals > 2^31. */
		long brksize = 1000000000;
		brksize = brksize + brksize;
		brksize = brksize + brksize;
		__darwin_brk_ptr = __darwin_mmap(0, brksize, 3, 4098, -1, 0);
		if(-1 == __darwin_brk_ptr) return -1;
		__darwin_brk_end = __darwin_brk_ptr + brksize;
	}

	if(NULL == addr) return __darwin_brk_ptr;
	if(__darwin_brk_end < addr) return -1;
	__darwin_brk_ptr = addr;
	return __darwin_brk_ptr;
}

int uname(struct utsname* unameData)
{
	return -1;
}

int geteuid()
{
	return 0;
}

int getegid()
{
	return 0;
}

#endif

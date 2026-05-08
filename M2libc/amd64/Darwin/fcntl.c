/* AMD64 Darwin syscalls for the M2libc POSIX layer. */

#ifndef __DARWIN_AMD64_FCNTL_C
#define __DARWIN_AMD64_FCNTL_C

#define O_RDONLY 0
#define O_WRONLY 1
#define O_RDWR 2
#define O_APPEND 8
#define O_CREAT 512
#define O_TRUNC 1024
#define O_EXCL 2048

#define S_IXUSR 00100
#define S_IWUSR 00200
#define S_IRUSR 00400
#define S_IRWXU 00700

int _open(char* name, int flag, int mode)
{
	asm("lea_rdi,[rsp+DWORD] %24"
	    "mov_rdi,[rdi]"
	    "lea_rsi,[rsp+DWORD] %16"
	    "mov_rsi,[rsi]"
	    "lea_rdx,[rsp+DWORD] %8"
	    "mov_rdx,[rdx]"
	    "mov_rax, %0x2000005"
	    "syscall");
}

#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2

#endif

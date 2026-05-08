#ifndef __MES_DARWIN_X86_64_SYSCALL_H
#define __MES_DARWIN_X86_64_SYSCALL_H 1

#define SYS_exit 0x2000001
#define SYS_fork 0x2000002
#define SYS_read 0x2000003
#define SYS_write 0x2000004
#define SYS_open 0x2000005
#define SYS_close 0x2000006
#define SYS_wait4 0x2000007
#define SYS_link 0x2000009
#define SYS_unlink 0x200000a
#define SYS_chdir 0x200000c
#define SYS_getpid 0x2000014
#define SYS_setuid 0x2000017
#define SYS_getuid 0x2000018
#define SYS_geteuid 0x2000019
#define SYS_getgid 0x200002f
#define SYS_getegid 0x200002b
#define SYS_getppid 0x2000027
#define SYS_pipe 0x200002a
#define SYS_kill 0x2000025
#define SYS_fchmod 0x200007c
#define SYS_chmod 0x200000f
#define SYS_access 0x2000021
#define SYS_dup 0x2000029
#define SYS_ioctl 0x2000036
#define SYS_symlink 0x2000039
#define SYS_execve 0x200003b
#define SYS_umask 0x200003c
#define SYS_fsync 0x200005f
#define SYS_dup2 0x200005a
#define SYS_fcntl 0x200005c
#define SYS_gettimeofday 0x2000074
#define SYS_rename 0x2000080
#define SYS_mkdir 0x2000088
#define SYS_rmdir 0x2000089
#define SYS_nanosleep 0x20000f0
#define SYS_mmap 0x20000c5
#define SYS_lseek 0x20000c7
#define SYS_stat64 0x2000152
#define SYS_fstat64 0x2000153
#define SYS_lstat64 0x2000154
#define SYS_getdirentries64 0x2000158
#define SYS_openat 0x20001cf
#define SYS_unlinkat 0x20001d8

long _sys_call (long sys_call);
long _sys_call1 (long sys_call, long one);
long _sys_call2 (long sys_call, long one, long two);
long _sys_call3 (long sys_call, long one, long two, long three);
long _sys_call4 (long sys_call, long one, long two, long three, long four);
long _sys_call5 (long sys_call, long one, long two, long three, long four, long five);
long _sys_call6 (long sys_call, long one, long two, long three, long four, long five, long six);

#endif

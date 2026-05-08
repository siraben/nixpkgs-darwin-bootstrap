#ifndef __MES_DARWIN_X86_64_SYSCALL_H
#define __MES_DARWIN_X86_64_SYSCALL_H 1

#define SYS_exit 0x2000001
#define SYS_fork 0x2000002
#define SYS_read 0x2000003
#define SYS_write 0x2000004
#define SYS_open 0x2000005
#define SYS_close 0x2000006
#define SYS_wait4 0x2000007
#define SYS_unlink 0x200000a
#define SYS_chdir 0x200000c
#define SYS_getpid 0x2000014
#define SYS_kill 0x2000025
#define SYS_fchmod 0x200007c
#define SYS_chmod 0x200000f
#define SYS_access 0x2000021
#define SYS_dup 0x2000029
#define SYS_ioctl 0x2000036
#define SYS_execve 0x200003b
#define SYS_umask 0x200003c
#define SYS_dup2 0x200005a
#define SYS_gettimeofday 0x2000074
#define SYS_mmap 0x20000c5
#define SYS_lseek 0x20000c7
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

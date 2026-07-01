#ifndef _DARWIN_BOOTSTRAP_SYS_TYPES_H
#define _DARWIN_BOOTSTRAP_SYS_TYPES_H
typedef unsigned long size_t;
typedef long ssize_t;
typedef long ptrdiff_t;
typedef long intptr_t;
typedef unsigned long uintptr_t;
#ifndef __cplusplus
typedef int wchar_t;   /* wchar_t is a built-in type in C++; only define for C */
#endif
typedef int pid_t;
typedef unsigned int uid_t;
typedef unsigned int gid_t;
typedef long long off_t;
typedef unsigned long long ino_t;
typedef int dev_t;
typedef unsigned short nlink_t;
typedef long blkcnt_t;
typedef int blksize_t;
typedef long time_t;
typedef long clock_t;
typedef unsigned long size_t;
typedef char *caddr_t;
#endif

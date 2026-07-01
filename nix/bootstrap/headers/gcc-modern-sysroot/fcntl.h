#ifndef _DARWIN_BOOTSTRAP_FCNTL_H
#define _DARWIN_BOOTSTRAP_FCNTL_H
#ifdef __cplusplus
extern "C" {
#endif
#define O_RDONLY 0
#define O_WRONLY 1
#define O_RDWR 2
#define O_CREAT 0x0200
#define O_EXCL 0x0800
#define O_TRUNC 0x0400
#define O_APPEND 0x0008
#define O_DIRECTORY 0x100000
#define O_CLOEXEC 0x1000000
#define AT_FDCWD -2
#define F_DUPFD 0
#define F_GETFD 1
#define F_SETFD 2
#define F_GETFL 3
#define F_SETFL 4
#define F_GETOWN 5
#define F_SETOWN 6
#define F_GETLK 7
#define F_SETLK 8
#define F_RDLCK 1
#define F_UNLCK 2
#define F_WRLCK 3
#define F_SETLKW 9
#define F_DUPFD_CLOEXEC 67
#define FD_CLOEXEC 1
typedef long long off_t;
struct flock {
  off_t l_start;
  off_t l_len;
  int l_pid;
  short l_type;
  short l_whence;
};
int open(const char *, int, ...);
int creat(const char *, int);
int fcntl(int, int, ...);
#ifdef __cplusplus
}
#endif
#endif

#ifndef _DARWIN_BOOTSTRAP_ERRNO_H
#define _DARWIN_BOOTSTRAP_ERRNO_H
#ifdef __cplusplus
extern "C" {
#endif
extern int errno;
#ifdef __cplusplus
}
#endif
#define EINVAL 22
#define ENOMEM 12
#define ENOENT 2
#define EPERM 1
#define ESRCH 3
#define EINTR 4
#define EIO 5
#define ENXIO 6
#define E2BIG 7
#define EAGAIN 35
#define EWOULDBLOCK EAGAIN
#define EBADF 9
#define EACCES 13
#define EFAULT 14
#define EBUSY 16
#define EEXIST 17
#define ENOEXEC 8
#define ENOTDIR 20
#define EISDIR 21
#define ENODEV 19
#define ENOTTY 25
#define EPIPE 32
#define ECHILD 10
#define EDEADLK 11
#define EXDEV 18
#define ENFILE 23
#define EMFILE 24
#define EFBIG 27
#define ENOSPC 28
#define ESPIPE 29
#define EROFS 30
#define EMLINK 31
#define EDOM 33
#define ERANGE 34
#define EINPROGRESS 36
#define EALREADY 37
#define ENOTSOCK 38
#define EDESTADDRREQ 39
#define EMSGSIZE 40
#define EPROTOTYPE 41
#define ENOPROTOOPT 42
#define EPROTONOSUPPORT 43
#define EOPNOTSUPP 45
#define ENOTSUP EOPNOTSUPP
#define EAFNOSUPPORT 47
#define EADDRINUSE 48
#define EADDRNOTAVAIL 49
#define ENETDOWN 50
#define ENETUNREACH 51
#define ENETRESET 52
#define ECONNABORTED 53
#define ECONNRESET 54
#define ENOBUFS 55
#define EISCONN 56
#define ENOTCONN 57
#define ETIMEDOUT 60
#define ECONNREFUSED 61
#define ELOOP 62
#define ENAMETOOLONG 63
#define EHOSTUNREACH 65
#define ENOTEMPTY 66
#define ENOLCK 77
#define ENOSYS 78
#define EOVERFLOW 84
#define ECANCELED 89
#define EIDRM 90
#define ENOMSG 91
#define EILSEQ 92
#define EBADMSG 94
#define ENODATA 96
#define ENOLINK 97
#define ENOSR 98
#define ENOSTR 99
#define EPROTO 100
#define ETIME 101
#endif

#ifndef _DARWIN_BOOTSTRAP_SYS_STAT_H
#define _DARWIN_BOOTSTRAP_SYS_STAT_H
typedef long long off_t;
typedef unsigned short mode_t;
typedef int dev_t;
typedef unsigned short nlink_t;
typedef unsigned int uid_t;
typedef unsigned int gid_t;
typedef unsigned int ino_t;
typedef long blkcnt_t;
typedef int blksize_t;
#ifndef _STRUCT_TIMESPEC
#define _STRUCT_TIMESPEC struct timespec
struct timespec { long tv_sec; long tv_nsec; };
#endif
struct stat {
  dev_t st_dev;
  ino_t st_ino;
  mode_t st_mode;
  nlink_t st_nlink;
  uid_t st_uid;
  gid_t st_gid;
  dev_t st_rdev;
  struct timespec st_atimespec;
  struct timespec st_mtimespec;
  struct timespec st_ctimespec;
  struct timespec st_birthtimespec;
  off_t st_size;
  blkcnt_t st_blocks;
  blksize_t st_blksize;
  unsigned int st_flags;
  unsigned int st_gen;
  int st_lspare;
  long st_qspare[2];
};
#define st_atime st_atimespec.tv_sec
#define st_mtime st_mtimespec.tv_sec
#define st_ctime st_ctimespec.tv_sec
int stat(const char *, struct stat *);
int fstat(int, struct stat *);
int fstatat(int, const char *, struct stat *, int);
int lstat(const char *, struct stat *);
int chmod(const char *, mode_t);
int chown(const char *, unsigned int, unsigned int);
int mkdir(const char *, mode_t);
int mknod(const char *, mode_t, dev_t);
#define S_IFMT 0170000
#define S_IFREG 0100000
#define S_IFDIR 0040000
#define S_IFLNK 0120000
#define S_IFIFO 0010000
#define S_IFBLK 0060000
#define S_IFCHR 0020000
#define S_IFSOCK 0140000
#define S_IRWXU 0700
#define S_IRWXG 0070
#define S_IRWXO 0007
#define S_IRUSR 0400
#define S_IWUSR 0200
#define S_IXUSR 0100
#define S_IRGRP 0040
#define S_IWGRP 0020
#define S_IXGRP 0010
#define S_IROTH 0004
#define S_IWOTH 0002
#define S_IXOTH 0001
#define S_ISREG(m) (((m) & S_IFMT) == S_IFREG)
#define S_ISDIR(m) (((m) & S_IFMT) == S_IFDIR)
#define S_ISLNK(m) (((m) & S_IFMT) == S_IFLNK)
#define S_ISFIFO(m) (((m) & S_IFMT) == S_IFIFO)
#define S_ISBLK(m) (((m) & S_IFMT) == S_IFBLK)
#define S_ISCHR(m) (((m) & S_IFMT) == S_IFCHR)
#define S_ISSOCK(m) (((m) & S_IFMT) == S_IFSOCK)
#endif

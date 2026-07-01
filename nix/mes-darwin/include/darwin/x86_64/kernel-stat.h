#ifndef __MES_DARWIN_X86_64_KERNEL_STAT_H
#define __MES_DARWIN_X86_64_KERNEL_STAT_H 1

struct stat
{
  unsigned int st_dev;
  unsigned short st_mode;
  unsigned short st_nlink;
  unsigned long long st_ino;
  unsigned int st_uid;
  unsigned int st_gid;
  unsigned int st_rdev;
  long st_atime;
  long st_atime_nsec;
  long st_mtime;
  long st_mtime_nsec;
  long st_ctime;
  long st_ctime_nsec;
  long st_birthtime;
  long st_birthtime_nsec;
  long st_size;
  long st_blocks;
  int st_blksize;
  unsigned int st_flags;
  unsigned int st_gen;
  int st_lspare;
  long long st_qspare[2];
};

#endif

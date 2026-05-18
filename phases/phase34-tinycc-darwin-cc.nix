args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase34-tinycc-darwin-cc-amd64" { } ''
        mkdir -p $out/bin $out/include/tcc-darwin-bootstrap/sys $out/share/darwin-bootstrap

        cat > $out/include/tcc-darwin-bootstrap/limits.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_LIMITS_H
        #define _DARWIN_BOOTSTRAP_LIMITS_H
        #define CHAR_BIT 8
        #define SCHAR_MIN (-128)
        #define SCHAR_MAX 127
        #define UCHAR_MAX 255
        #define CHAR_MIN SCHAR_MIN
        #define CHAR_MAX SCHAR_MAX
        #define SHRT_MIN (-32768)
        #define SHRT_MAX 32767
        #define USHRT_MAX 65535
        #define INT_MIN (-2147483647 - 1)
        #define INT_MAX 2147483647
        #define UINT_MAX 4294967295U
        #define LONG_MIN (-9223372036854775807L - 1L)
        #define LONG_MAX 9223372036854775807L
        #define ULONG_MAX 18446744073709551615UL
        #define LLONG_MIN (-9223372036854775807LL - 1LL)
        #define LLONG_MAX 9223372036854775807LL
        #define ULLONG_MAX 18446744073709551615ULL
        #define PATH_MAX 1024
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/float.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_FLOAT_H
        #define _DARWIN_BOOTSTRAP_FLOAT_H
        #define FLT_RADIX 2
        #define FLT_MANT_DIG 24
        #define DBL_MANT_DIG 53
        #define LDBL_MANT_DIG 64
        #define FLT_DIG 6
        #define DBL_DIG 15
        #define LDBL_DIG 18
        #define FLT_MIN_EXP (-125)
        #define DBL_MIN_EXP (-1021)
        #define LDBL_MIN_EXP (-16381)
        #define FLT_MAX_EXP 128
        #define DBL_MAX_EXP 1024
        #define LDBL_MAX_EXP 16384
        #define FLT_MAX_10_EXP 38
        #define DBL_MAX_10_EXP 308
        #define LDBL_MAX_10_EXP 4932
        #define FLT_MAX 3.4028234663852886e+38F
        #define DBL_MAX 1.7976931348623157e+308
        #define LDBL_MAX 1.18973149535723176502e+4932L
        #define FLT_MIN 1.1754943508222875e-38F
        #define DBL_MIN 2.2250738585072014e-308
        #define LDBL_MIN 3.36210314311209350626e-4932L
        #define FLT_EPSILON 1.1920928955078125e-7F
        #define DBL_EPSILON 2.2204460492503131e-16
        #define LDBL_EPSILON 1.08420217248550443401e-19L
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/math.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_MATH_H
        #define _DARWIN_BOOTSTRAP_MATH_H
        #ifdef __cplusplus
        extern "C" {
        #endif
        double acos(double);
        double asin(double);
        double atan(double);
        double atan2(double, double);
        double ceil(double);
        double cos(double);
        double cosh(double);
        double ldexp(double, int);
        double frexp(double, int *);
        double fabs(double);
        double floor(double);
        double fmod(double, double);
        double log(double);
        double log10(double);
        double modf(double, double *);
        double pow(double, double);
        double sin(double);
        double sinh(double);
        double sqrt(double);
        double tan(double);
        double tanh(double);
        double exp(double);
        double atof(const char *);
        double strtod(const char *, char **);
        #ifdef __cplusplus
        }
        #endif
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/assert.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_ASSERT_H
        #define _DARWIN_BOOTSTRAP_ASSERT_H
        #define assert(expr) ((void)0)
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/types.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_TYPES_H
        #define _DARWIN_BOOTSTRAP_SYS_TYPES_H
        typedef unsigned long size_t;
        typedef struct { int quot; int rem; } div_t;
        typedef struct { long quot; long rem; } ldiv_t;
        typedef long ssize_t;
        typedef long ptrdiff_t;
        typedef long intptr_t;
        typedef unsigned long uintptr_t;
        typedef int wchar_t;
        typedef int pid_t;
        typedef unsigned int uid_t;
        typedef unsigned int gid_t;
        typedef long off_t;
        typedef unsigned int ino_t;
        typedef int dev_t;
        typedef unsigned short nlink_t;
        typedef long blkcnt_t;
        typedef int blksize_t;
        typedef long time_t;
        typedef long clock_t;
        typedef unsigned long size_t;
        typedef char *caddr_t;
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/stat.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_STAT_H
        #define _DARWIN_BOOTSTRAP_SYS_STAT_H
        typedef long off_t;
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
        H

        cat > $out/include/tcc-darwin-bootstrap/fcntl.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_FCNTL_H
        #define _DARWIN_BOOTSTRAP_FCNTL_H
        #define O_RDONLY 0
        #define O_WRONLY 1
        #define O_RDWR 2
        #define O_CREAT 0x0200
        #define O_EXCL 0x0800
        #define O_TRUNC 0x0400
        #define O_APPEND 0x0008
        #define F_GETFD 1
        #define F_SETFD 2
        #define FD_CLOEXEC 1
        int open(const char *, int, ...);
        int creat(const char *, int);
        int fcntl(int, int, ...);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/dirent.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_DIRENT_H
        #define _DARWIN_BOOTSTRAP_DIRENT_H
        typedef struct DIR DIR;
        struct dirent { unsigned long d_ino; unsigned long d_seekoff; unsigned short d_reclen; unsigned short d_namlen; unsigned char d_type; char d_name[1024]; };
        DIR *opendir(const char *);
        struct dirent *readdir(DIR *);
        int closedir(DIR *);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/time.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_TIME_H
        #define _DARWIN_BOOTSTRAP_TIME_H
        typedef long time_t;
        typedef long clock_t;
        #ifndef _STRUCT_TIMESPEC
        #define _STRUCT_TIMESPEC struct timespec
        struct timespec { long tv_sec; long tv_nsec; };
        #endif
        struct tm { int tm_sec; int tm_min; int tm_hour; int tm_mday; int tm_mon; int tm_year; int tm_wday; int tm_yday; int tm_isdst; };
        #ifdef __cplusplus
        extern "C" {
        #endif
        time_t time(time_t *);
        clock_t clock(void);
        struct tm *localtime(const time_t *);
        struct tm *gmtime(const time_t *);
        time_t mktime(struct tm *);
        double difftime(time_t, time_t);
        char *ctime(const time_t *);
        char *asctime(const struct tm *);
        size_t strftime(char *, size_t, const char *, const struct tm *);
        int nanosleep(const struct timespec *, struct timespec *);
        #ifdef __cplusplus
        }
        #endif
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/time.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_TIME_H
        #define _DARWIN_BOOTSTRAP_SYS_TIME_H
        struct timeval { long tv_sec; long tv_usec; };
        struct timezone { int tz_minuteswest; int tz_dsttime; };
        int gettimeofday(struct timeval *, struct timezone *);
        int settimeofday(const struct timeval *, const struct timezone *);
        int utimes(const char *, const struct timeval *);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/utime.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_UTIME_H
        #define _DARWIN_BOOTSTRAP_UTIME_H
        typedef long time_t;
        struct utimbuf { time_t actime; time_t modtime; };
        int utime(const char *, const struct utimbuf *);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/wait.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_WAIT_H
        #define _DARWIN_BOOTSTRAP_SYS_WAIT_H
        #include <sys/resource.h>
        #define WNOHANG 1
        int wait(int *);
        int wait4(int, int *, int, struct rusage *);
        int waitpid(int, int *, int);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/file.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_FILE_H
        #define _DARWIN_BOOTSTRAP_SYS_FILE_H
        #define F_OK 0
        #define X_OK 1
        #define W_OK 2
        #define R_OK 4
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/ioctl.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_IOCTL_H
        #define _DARWIN_BOOTSTRAP_SYS_IOCTL_H
        int ioctl(int, unsigned long, ...);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/mman.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_MMAN_H
        #define _DARWIN_BOOTSTRAP_SYS_MMAN_H
        #include <sys/types.h>
        #define PROT_NONE 0
        #define PROT_READ 1
        #define PROT_WRITE 2
        #define PROT_EXEC 4
        #define MAP_SHARED 1
        #define MAP_PRIVATE 2
        #define MAP_FIXED 0x10
        #define MAP_ANON 0x1000
        #define MAP_ANONYMOUS MAP_ANON
        #define MAP_FAILED ((void *)-1)
        void *mmap(void *, size_t, int, int, int, off_t);
        int munmap(void *, size_t);
        int mprotect(void *, size_t, int);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/param.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_PARAM_H
        #define _DARWIN_BOOTSTRAP_SYS_PARAM_H
        #define MAXPATHLEN 1024
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/resource.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_RESOURCE_H
        #define _DARWIN_BOOTSTRAP_SYS_RESOURCE_H
        #include <sys/time.h>
        #define RUSAGE_SELF 0
        #define RUSAGE_CHILDREN -1
        struct rusage { struct timeval ru_utime; struct timeval ru_stime; long ru_maxrss; long ru_ixrss; long ru_idrss; long ru_isrss; long ru_minflt; long ru_majflt; long ru_nswap; long ru_inblock; long ru_oublock; long ru_msgsnd; long ru_msgrcv; long ru_nsignals; long ru_nvcsw; long ru_nivcsw; long ru_reserved[16]; };
        struct rlimit { unsigned long rlim_cur; unsigned long rlim_max; };
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/select.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_SELECT_H
        #define _DARWIN_BOOTSTRAP_SYS_SELECT_H
        typedef long fd_set;
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/sysctl.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_SYSCTL_H
        #define _DARWIN_BOOTSTRAP_SYS_SYSCTL_H
        #include <sys/types.h>
        #define CTL_KERN 1
        #define KERN_OSRELEASE 2
        int sysctl(int *, unsigned int, void *, size_t *, void *, size_t);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stdint.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDINT_H
        #define _DARWIN_BOOTSTRAP_STDINT_H
        typedef signed char int8_t;
        typedef unsigned char uint8_t;
        typedef short int16_t;
        typedef unsigned short uint16_t;
        typedef int int32_t;
        typedef unsigned int uint32_t;
        typedef long int64_t;
        typedef unsigned long uint64_t;
        typedef int8_t int_least8_t;
        typedef uint8_t uint_least8_t;
        typedef int16_t int_least16_t;
        typedef uint16_t uint_least16_t;
        typedef int32_t int_least32_t;
        typedef uint32_t uint_least32_t;
        typedef int64_t int_least64_t;
        typedef uint64_t uint_least64_t;
        typedef int8_t int_fast8_t;
        typedef uint8_t uint_fast8_t;
        typedef int int_fast16_t;
        typedef unsigned int uint_fast16_t;
        typedef int32_t int_fast32_t;
        typedef uint32_t uint_fast32_t;
        typedef int64_t int_fast64_t;
        typedef uint64_t uint_fast64_t;
        typedef long intmax_t;
        typedef unsigned long uintmax_t;
        typedef long intptr_t;
        typedef unsigned long uintptr_t;
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stdbool.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDBOOL_H
        #define _DARWIN_BOOTSTRAP_STDBOOL_H
        #define bool int
        #define true 1
        #define false 0
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/inttypes.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_INTTYPES_H
        #define _DARWIN_BOOTSTRAP_INTTYPES_H
        #include <stdint.h>
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/locale.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_LOCALE_H
        #define _DARWIN_BOOTSTRAP_LOCALE_H
        #define LC_ALL 0
        #define LC_COLLATE 1
        #define LC_CTYPE 2
        #define LC_MONETARY 3
        #define LC_NUMERIC 4
        #define LC_TIME 5
        #ifndef CHAR_MAX
        #define CHAR_MAX 127
        #endif
        struct lconv { char *decimal_point; char *thousands_sep; char *grouping; char *int_curr_symbol; char *currency_symbol; char *mon_decimal_point; char *mon_thousands_sep; char *mon_grouping; char *positive_sign; char *negative_sign; char int_frac_digits; char frac_digits; char p_cs_precedes; char p_sep_by_space; char n_cs_precedes; char n_sep_by_space; char p_sign_posn; char n_sign_posn; };
        #ifdef __cplusplus
        extern "C" {
        #endif
        char *setlocale(int, const char *);
        struct lconv *localeconv(void);
        #ifdef __cplusplus
        }
        #endif
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/pwd.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_PWD_H
        #define _DARWIN_BOOTSTRAP_PWD_H
        struct passwd { char *pw_name; char *pw_passwd; unsigned int pw_uid; unsigned int pw_gid; char *pw_gecos; char *pw_dir; char *pw_shell; };
        struct passwd *getpwnam(const char *);
        struct passwd *getpwuid(unsigned int);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/grp.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_GRP_H
        #define _DARWIN_BOOTSTRAP_GRP_H
        struct group { char *gr_name; unsigned int gr_gid; char **gr_mem; };
        struct group *getgrnam(const char *);
        struct group *getgrgid(unsigned int);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stddef.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDDEF_H
        #define _DARWIN_BOOTSTRAP_STDDEF_H
        typedef unsigned long size_t;
        typedef long ptrdiff_t;
        typedef long ssize_t;
        typedef long intptr_t;
        typedef unsigned long uintptr_t;
        typedef int wchar_t;
        #ifndef NULL
        #ifdef __cplusplus
        #define NULL 0
        #else
        #define NULL ((void *)0)
        #endif
        #endif
        #define offsetof(type, field) ((size_t)&((type *)0)->field)
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stdarg.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDARG_H
        #define _DARWIN_BOOTSTRAP_STDARG_H
        typedef struct {
            unsigned int gp_offset;
            unsigned int fp_offset;
            union {
                unsigned int overflow_offset;
                char *overflow_arg_area;
            };
            char *reg_save_area;
        } __va_list_struct;
        #ifndef _DARWIN_BOOTSTRAP_VA_LIST_TYPE
        #define _DARWIN_BOOTSTRAP_VA_LIST_TYPE
        typedef __va_list_struct va_list[1];
        #endif
        void __va_start(__va_list_struct *, void *);
        void *__va_arg(__va_list_struct *, int, int, int);
        #define va_start(ap, last) __va_start(ap, __builtin_frame_address(0))
        #define va_arg(ap, type) (*(type *)(__va_arg(ap, __builtin_va_arg_types(type), sizeof(type), __alignof__(type))))
        #define va_end(ap) ((void)0)
        #define va_copy(dst, src) (*(dst) = *(src))
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/alloca.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_ALLOCA_H
        #define _DARWIN_BOOTSTRAP_ALLOCA_H
        void *malloc(unsigned long);
        #define alloca malloc
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/string.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STRING_H
        #define _DARWIN_BOOTSTRAP_STRING_H
        typedef unsigned long size_t;
        #ifdef __cplusplus
        extern "C" {
        #endif
        void *memchr(const void *, int, size_t);
        int memcmp(const void *, const void *, size_t);
        void *memcpy(void *, const void *, size_t);
        void *memmove(void *, const void *, size_t);
        void *memset(void *, int, size_t);
        char *strcat(char *, const char *);
        char *strncat(char *, const char *, size_t);
        char *strchr(const char *, int);
        char *index(const char *, int);
        int strcmp(const char *, const char *);
        int strcoll(const char *, const char *);
        char *strcpy(char *, const char *);
        unsigned long strlen(const char *);
        int strncmp(const char *, const char *, size_t);
        char *strncpy(char *, const char *, size_t);
        size_t strspn(const char *, const char *);
        size_t strcspn(const char *, const char *);
        char *strpbrk(const char *, const char *);
        char *strtok(char *, const char *);
        char *strrchr(const char *, int);
        char *rindex(const char *, int);
        char *strerror(int);
        char *strdup(const char *);
        char *strstr(const char *, const char *);
        size_t strxfrm(char *, const char *, size_t);
        #ifdef __cplusplus
        }
        #endif
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/strings.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STRINGS_H
        #define _DARWIN_BOOTSTRAP_STRINGS_H
        #include <string.h>
        int bcmp(const void *, const void *, unsigned long);
        void bcopy(const void *, void *, unsigned long);
        void bzero(void *, unsigned long);
        char *index(const char *, int);
        char *rindex(const char *, int);
        int strcasecmp(const char *, const char *);
        int strncasecmp(const char *, const char *, unsigned long);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/ctype.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_CTYPE_H
        #define _DARWIN_BOOTSTRAP_CTYPE_H
        #define DARWIN_BOOTSTRAP_CTYPE_BITS 1
        #define _CTYPE_A 0x00000100L
        #define _CTYPE_C 0x00000200L
        #define _CTYPE_D 0x00000400L
        #define _CTYPE_G 0x00000800L
        #define _CTYPE_L 0x00001000L
        #define _CTYPE_P 0x00002000L
        #define _CTYPE_S 0x00004000L
        #define _CTYPE_U 0x00008000L
        #define _CTYPE_X 0x00010000L
        #define _CTYPE_R 0x00040000L
        #define _A _CTYPE_A
        #define _C _CTYPE_C
        #define _D _CTYPE_D
        #define _G _CTYPE_G
        #define _L _CTYPE_L
        #define _P _CTYPE_P
        #define _S _CTYPE_S
        #define _U _CTYPE_U
        #define _X _CTYPE_X
        #define _R _CTYPE_R
        static inline unsigned long __darwin_bootstrap_ctype_mask(int c) {
          unsigned long m = 0;
          unsigned int u = (unsigned char)c;
          if (u < 32 || u == 127) m |= _CTYPE_C;
          if (u == ' ' || (u >= 9 && u <= 13)) m |= _CTYPE_S;
          if (u >= '0' && u <= '9') m |= _CTYPE_D | _CTYPE_X;
          if (u >= 'A' && u <= 'Z') m |= _CTYPE_U | _CTYPE_A;
          if (u >= 'a' && u <= 'z') m |= _CTYPE_L | _CTYPE_A;
          if ((u >= 'A' && u <= 'F') || (u >= 'a' && u <= 'f')) m |= _CTYPE_X;
          if (u >= 32 && u <= 126) m |= _CTYPE_R;
          if (u >= 33 && u <= 126) m |= _CTYPE_G;
          if ((m & (_CTYPE_A | _CTYPE_D | _CTYPE_S | _CTYPE_C)) == 0 && u >= 33 && u <= 126) m |= _CTYPE_P;
          return m;
        }
        static inline unsigned long __darwin_bootstrap_maskrune(int c, unsigned long f) { return __darwin_bootstrap_ctype_mask(c) & f; }
        #define __maskrune(c, f) __darwin_bootstrap_maskrune((c), (f))
        #define __istype(c, f) (__darwin_bootstrap_maskrune((c), (f)) != 0)
        #ifdef __cplusplus
        extern "C" {
        #endif
        int isalnum(int);
        int isalpha(int);
        int iscntrl(int);
        int isdigit(int);
        int isgraph(int);
        int islower(int);
        int isprint(int);
        int ispunct(int);
        int isspace(int);
        int isupper(int);
        int isxdigit(int);
        int isascii(int);
        int tolower(int);
        int toupper(int);
        #ifdef __cplusplus
        }
        #endif
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/errno.h <<'H'
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
        H

        cat > $out/include/tcc-darwin-bootstrap/fnmatch.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_FNMATCH_H
        #define _DARWIN_BOOTSTRAP_FNMATCH_H
        #define FNM_NOMATCH 1
        #define FNM_NOESCAPE 0x01
        #define FNM_PATHNAME 0x02
        #define FNM_FILE_NAME FNM_PATHNAME
        #define FNM_PERIOD 0x04
        #define FNM_LEADING_DIR 0x08
        #define FNM_CASEFOLD 0x10
        #define FNM_EXTMATCH 0x20
        int fnmatch(const char *, const char *, int);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/signal.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SIGNAL_H
        #define _DARWIN_BOOTSTRAP_SIGNAL_H
        typedef int sig_atomic_t;
        typedef long sigset_t;
        typedef void (*__sighandler_t)(int);
        struct sigaction { __sighandler_t sa_handler; sigset_t sa_mask; int sa_flags; };
        #define SIG_DFL ((__sighandler_t)0)
        #define SIG_IGN ((__sighandler_t)1)
        #define SIG_ERR ((__sighandler_t)-1)
        #define SIG_BLOCK 1
        #define SIG_UNBLOCK 2
        #define SIG_SETMASK 3
        #define SA_RESTART 0
        #define SIGHUP 1
        #define SIGINT 2
        #define SIGQUIT 3
        #define SIGILL 4
        #define SIGTRAP 5
        #define SIGABRT 6
        #define SIGIOT SIGABRT
        #define SIGEMT 7
        #define SIGFPE 8
        #define SIGKILL 9
        #define SIGBUS 10
        #define SIGSEGV 11
        #define SIGSYS 12
        #define SIGPIPE 13
        #define SIGALRM 14
        #define SIGTERM 15
        #define SIGURG 16
        #define SIGSTOP 17
        #define SIGTSTP 18
        #define SIGCONT 19
        #define SIGCHLD 20
        #define SIGTTIN 21
        #define SIGTTOU 22
        #define SIGIO 23
        #define SIGXCPU 24
        #define SIGXFSZ 25
        #define SIGVTALRM 26
        #define SIGPROF 27
        #define SIGWINCH 28
        #define SIGINFO 29
        #define SIGUSR1 30
        #define SIGUSR2 31
        #define NSIG 32
        __sighandler_t signal(int, __sighandler_t);
        int sigaction(int, const struct sigaction *, struct sigaction *);
        int raise(int);
        int kill(int, int);
        int sigemptyset(sigset_t *);
        int sigaddset(sigset_t *, int);
        int sigprocmask(int, const sigset_t *, sigset_t *);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/setjmp.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SETJMP_H
        #define _DARWIN_BOOTSTRAP_SETJMP_H
        typedef long jmp_buf[32];
        int setjmp(jmp_buf);
        void longjmp(jmp_buf, int);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stdlib.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDLIB_H
        #define _DARWIN_BOOTSTRAP_STDLIB_H
        typedef unsigned long size_t;
        #ifndef NULL
        #ifdef __cplusplus
        #define NULL 0
        #else
        #define NULL ((void *)0)
        #endif
        #endif
        typedef struct { int quot; int rem; } div_t;
        typedef struct { long quot; long rem; } ldiv_t;
        #ifdef __cplusplus
        extern "C" {
        #endif
        void abort(void);
        #define EXIT_SUCCESS 0
        #define EXIT_FAILURE 1
        #ifndef MB_CUR_MAX
        #define MB_CUR_MAX 1
        #endif
        #ifndef MB_CUR_MAX_L
        #define MB_CUR_MAX_L(x) (1)
        #endif
        int system(const char *);
        void exit(int);
        void _exit(int);
        int atexit(void (*)(void));
        void free(void *);
        char *getenv(const char *);
        void *malloc(size_t);
        void *calloc(size_t, size_t);
        void *realloc(void *, size_t);
        int abs(int);
        long labs(long);
        long long llabs(long long);
        div_t div(int, int);
        ldiv_t ldiv(long, long);
        int rand(void);
        void srand(unsigned int);
        long strtol(const char *, char **, int);
        unsigned long strtoul(const char *, char **, int);
        long long strtoll(const char *, char **, int);
        unsigned long long strtoull(const char *, char **, int);
        double strtod(const char *, char **);
        double atof(const char *);
        int atoi(const char *);
        long atol(const char *);
        long long atoll(const char *);
        int putenv(char *);
        char *mktemp(char *);
        void *bsearch(const void *, const void *, size_t, size_t, int (*)(const void *, const void *));
        void qsort(void *, size_t, size_t, int (*)(const void *, const void *));
        #ifdef __cplusplus
        }
        #endif
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/xlocale.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_XLOCALE_H
        #define _DARWIN_BOOTSTRAP_XLOCALE_H
        typedef void *locale_t;
        #define LC_GLOBAL_LOCALE ((locale_t)-1)
        #define LC_C_LOCALE ((locale_t)0)
        #ifndef MB_CUR_MAX_L
        #define MB_CUR_MAX_L(x) (1)
        #endif
        locale_t uselocale(locale_t);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stdio.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDIO_H
        #define _DARWIN_BOOTSTRAP_STDIO_H
        #define _STDIO_H 1
        #define EOF (-1)
        #define BUFSIZ 1024
        #define _IONBF 0
        #define _IOLBF 1
        #define _IOFBF 2
        #define SEEK_SET 0
        #define SEEK_CUR 1
        #define SEEK_END 2
        struct __sbuf { unsigned char *_base; int _size; };
        struct __sFILE { unsigned char *_p; int _r; int _w; short _flags; short _file; struct __sbuf _bf; int _lbfsize; void *_cookie; int (*_close)(void *); int (*_read)(void *, char *, int); long (*_seek)(void *, long, int); int (*_write)(void *, const char *, int); struct __sbuf _ub; void *_extra; int _ur; unsigned char _ubuf[3]; unsigned char _nbuf[1]; struct __sbuf _lb; int _blksize; long _offset; };
        typedef struct __sFILE FILE;
        #define __sferror(p) (((p)->_flags & 0x0040) != 0)
        typedef long fpos_t;
        typedef unsigned long size_t;
        #ifndef NULL
        #ifdef __cplusplus
        #define NULL 0
        #else
        #define NULL ((void *)0)
        #endif
        #endif
        #include <stdarg.h>
        #define stdin ((FILE *)0)
        #define stdout ((FILE *)1)
        #define stderr ((FILE *)2)
        #ifdef __cplusplus
        extern "C" {
        #endif
        int printf(const char *, ...);
        int fprintf(FILE *, const char *, ...);
        int vfprintf(FILE *, const char *, va_list);
        void perror(const char *);
        int fscanf(FILE *, const char *, ...);
        int scanf(const char *, ...);
        int sscanf(const char *, const char *, ...);
        int sprintf(char *, const char *, ...);
        int vprintf(const char *, va_list);
        int snprintf(char *, size_t, const char *, ...);
        int vsprintf(char *, const char *, va_list);
        int vsnprintf(char *, size_t, const char *, va_list);
        int vasprintf(char **, const char *, va_list);
        FILE *fopen(const char *, const char *);
        FILE *fopen_unlocked(const char *, const char *);
        FILE *freopen(const char *, const char *, FILE *);
        FILE *fdopen(int, const char *);
        int fclose(FILE *);
        int ferror(FILE *);
        int fputs(const char *, FILE *);
        int puts(const char *);
        int fputc(int, FILE *);
        int fgetc(FILE *);
        int putchar(int);
        int getchar(void);
        void setbuf(FILE *, char *);
        int getc(FILE *);
        char *fgets(char *, int, FILE *);
        char *gets(char *);
        int fgetpos(FILE *, fpos_t *);
        int fsetpos(FILE *, const fpos_t *);
        int ungetc(int, FILE *);
        int putc(int, FILE *);
        int fflush(FILE *);
        void clearerr(FILE *);
        void clearerr_unlocked(FILE *);
        int feof_unlocked(FILE *);
        int ferror_unlocked(FILE *);
        int fflush_unlocked(FILE *);
        int fgetc_unlocked(FILE *);
        char *fgets_unlocked(char *, int, FILE *);
        int fileno_unlocked(FILE *);
        int fputc_unlocked(int, FILE *);
        int fputs_unlocked(const char *, FILE *);
        size_t fread_unlocked(void *, size_t, size_t, FILE *);
        size_t fwrite_unlocked(const void *, size_t, size_t, FILE *);
        int getchar_unlocked(void);
        int getc_unlocked(FILE *);
        int putchar_unlocked(int);
        int putc_unlocked(int, FILE *);
        size_t fread(void *, size_t, size_t, FILE *);
        size_t fwrite(const void *, size_t, size_t, FILE *);
        int feof(FILE *);
        int fseek(FILE *, long, int);
        int fseeko(FILE *, long, int);
        long ftell(FILE *);
        void rewind(FILE *);
        int fileno(FILE *);
        int remove(const char *);
        int rename(const char *, const char *);
        int setvbuf(FILE *, char *, int, size_t);
        FILE *tmpfile(void);
        char *tmpnam(char *);
        FILE *popen(const char *, const char *);
        int pclose(FILE *);
        #ifdef __cplusplus
        }
        #endif
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/unistd.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_UNISTD_H
        #define _DARWIN_BOOTSTRAP_UNISTD_H
        typedef long ssize_t;
        typedef long off_t;
        typedef unsigned int uid_t;
        typedef unsigned int gid_t;
        #ifdef __cplusplus
        extern "C" {
        #endif
        int close(int);
        #define F_OK 0
        #define X_OK 1
        #define W_OK 2
        #define R_OK 4
        int access(const char *, int);
        int dup(int);
        int dup2(int, int);
        int execv(const char *, char *const *);
        int execl(const char *, const char *, ...);
        int execlp(const char *, const char *, ...);
        int execvp(const char *, char *const *);
        int fork(void);
        char *getcwd(char *, unsigned long);
        char *getlogin(void);
        int chdir(const char *);
        uid_t geteuid(void);
        uid_t getuid(void);
        gid_t getegid(void);
        gid_t getgid(void);
        int getpid(void);
        char *getwd(char *);
        int isatty(int);
        int fchdir(int);
        int fchown(int, unsigned int, unsigned int);
        int fsync(int);
        int fdatasync(int);
        int ftruncate(int, off_t);
        int lchown(const char *, unsigned int, unsigned int);
        int link(const char *, const char *);
        int pipe(int *);
        int sleep(unsigned int);
        void sync(void);
        unsigned int alarm(unsigned int);
        char *ttyname(int);
        int umask(int);
        ssize_t readlink(const char *, char *, unsigned long);
        ssize_t read(int, void *, unsigned long);
        ssize_t write(int, const void *, unsigned long);
        off_t lseek(int, off_t, int);
        int unlink(const char *);
        int rename(const char *, const char *);
        int rmdir(const char *);
        int symlink(const char *, const char *);
        #ifdef __cplusplus
        }
        #endif
        #endif
        H

        ${phase30-tinycc-self-link-candidate}/bin/tcc-self-candidate -c \
          ${root + "/bootstrap/tinycc-sysv-libc.c"} \
          -o tinycc-sysv-libc.o \
          > tinycc-sysv-libc.stdout \
          2> tinycc-sysv-libc.stderr
        ${python3}/bin/python3 ${root + "/tools/elf64-to-m1.py"} --prefix tinycc_sysv_libc_ \
          tinycc-sysv-libc.o \
          tinycc-sysv-libc.M1

        cat > crt1-tcc-sysv.M1 <<'M1'
        :_start
        !0x48 !0x83 !0xe4 !0xf0
        !0x48 !0x8d !0x05 %environ
        !0x48 !0x89 !0x10
        !0xe8 %main
        !0x48 !0x89 !0xc7
        !0x48 !0xc7 !0xc0 !0x01 !0x00 !0x00 !0x02
        !0x0f !0x05
        M1

        cp crt1-tcc-sysv.M1 tinycc-sysv-libc.M1 $out/share/darwin-bootstrap/

        cat > $out/bin/tcc-darwin-cc <<'SH'
        #!${stdenv.shell}
        set -euo pipefail

        out=a.out
        explicit_output=0
        compile_only=0
        preprocess_only=0
        args=()
        inputs=()
        prepared_inputs=()
        objects=()
        archives=()
        library_dirs=()
        libraries=()
        include_dirs=(@INCLUDE@)
        cleanup_files=()
        cleanup_dirs=()
        emit_deps=0
        dep_file=
        dep_target=
        dep_dummy_headers=0

        while (($#)); do
          case "$1" in
            --version|-version|-V|-qversion)
              echo "tcc-darwin-cc bootstrap wrapper"
              case "$1" in
                -V|-qversion) exit 1 ;;
                *) exit 0 ;;
              esac
              ;;
            -c)
              compile_only=1
              args+=("$1")
              shift
              ;;
            -E)
              preprocess_only=1
              args+=("$1")
              shift
              ;;
            -o)
              out="$2"
              explicit_output=1
              if ((compile_only)); then
                args+=("-o" "$2")
              fi
              shift 2
              ;;
            -o*)
              out="''${1#-o}"
              explicit_output=1
              if ((compile_only)); then
                args+=("$1")
              fi
              shift
              ;;
            -MD|-MMD)
              emit_deps=1
              shift
              ;;
            -MP)
              dep_dummy_headers=1
              shift
              ;;
            -MF)
              emit_deps=1
              dep_file="$2"
              shift 2
              ;;
            -MF*)
              emit_deps=1
              dep_file="''${1#-MF}"
              shift
              ;;
            -MT|-MQ)
              dep_target="$2"
              shift 2
              ;;
            -MT*|-MQ*)
              dep_target="''${1#-M?}"
              shift
              ;;
            -Wp,-MD,*)
              emit_deps=1
              dep_file="''${1#-Wp,-MD,}"
              shift
              ;;
            -Wp,-MMD,*)
              emit_deps=1
              dep_file="''${1#-Wp,-MMD,}"
              shift
              ;;
            -I)
              args+=("$1" "$2")
              include_dirs+=("$2")
              shift 2
              ;;
            -I*)
              args+=("$1")
              include_dirs+=("''${1#-I}")
              shift
              ;;
            *.c)
              inputs+=("$1")
              shift
              ;;
            *.o)
              objects+=("$1")
              shift
              ;;
            *.a)
              case "$1" in
                /*) archives+=("$1") ;;
                *) archives+=("$(pwd)/$1") ;;
              esac
              shift
              ;;
            -L)
              library_dirs+=("$2")
              shift 2
              ;;
            -L*)
              library_dirs+=("''${1#-L}")
              shift
              ;;
            -l*)
              libraries+=("''${1#-l}")
              shift
              ;;
            *)
              args+=("$1")
              shift
              ;;
          esac
        done

        materialize_one_quote_header_dir() {
          local dir="$1" abs_dir key stamp_dir rel rel_dir header
          test -d "$dir" || return 0
          abs_dir="$(cd "$dir" && pwd)" || return 0
          [ "$abs_dir" = "$PWD" ] && return 0

          mkdir -p .tcc-darwin-header-stamps
          key="$(printf '%s\n' "$abs_dir" | cksum | awk '{ print $1 "-" $2 }')"
          stamp_dir=".tcc-darwin-header-stamps/$key"
          if [ -f "$stamp_dir/.complete" ]; then
            return 0
          fi

          if mkdir "$stamp_dir.lock" 2>/dev/null; then
            mkdir -p "$stamp_dir"
            for header in "$dir"/*.h "$dir"/*/*.h; do
              test -f "$header" || continue
              rel="''${header#$dir/}"
              case "$rel" in
                */*)
                  rel_dir="''${rel%/*}"
                  mkdir -p "$rel_dir"
                  ;;
              esac
              test -e "$rel" || ln -s "$header" "$rel" 2>/dev/null || true
            done
            touch "$stamp_dir/.complete"
            rmdir "$stamp_dir.lock"
          else
            while [ ! -f "$stamp_dir/.complete" ]; do
              sleep 1
            done
          fi
        }

        materialize_quote_headers() {
          local dir
          for dir in "''${include_dirs[@]}"; do
            materialize_one_quote_header_dir "$dir"
          done
        }

        prepare_source_inputs() {
          local index=0 work_dir
          for input in "''${inputs[@]}"; do
            case "$input" in
              */*)
                work_dir="''${tmp:-}"
                if [ -z "$work_dir" ]; then
                  work_dir="$(mktemp -d .tcc-darwin-inputs.XXXXXX)"
                  cleanup_dirs+=("$work_dir")
                fi
                local copy="$work_dir/input-$index.c"
                cp "$input" "$copy"
                cleanup_files+=("$copy")
                prepared_inputs+=("$copy")
                local input_dir
                input_dir="$(dirname "$input")"
                include_dirs+=("$input_dir")
                args+=("-I$input_dir")
                ;;
              *)
                prepared_inputs+=("$input")
                ;;
            esac
            index=$((index + 1))
          done
        }

        resolve_libraries() {
          local lib dir path found
          for lib in "''${libraries[@]}"; do
            if [ "$lib" = m ]; then
              continue
            fi
            found=0
            for dir in "''${library_dirs[@]}" .; do
              path="$dir/lib$lib.a"
              if [ -f "$path" ]; then
                case "$path" in
                  /*) archives+=("$path") ;;
                  *) archives+=("$(cd "$(dirname "$path")" && pwd)/$(basename "$path")") ;;
                esac
                found=1
                break
              fi
            done
            if [ "$found" = 0 ]; then
              echo "tcc-darwin-cc: library not found: -l$lib" >&2
              return 1
            fi
          done
        }

        process_symbol_file() {
          local file="$1"
          local kind name
          while IFS=$'\t' read -r kind name; do
            [ -n "''${name:-}" ] || continue
            if [ "$kind" = D ]; then
              defined_symbols["$name"]=1
              unset 'unresolved_symbols[$name]'
            fi
          done < "$file"
          while IFS=$'\t' read -r kind name; do
            [ -n "''${name:-}" ] || continue
            if [ "$kind" = U ] && [ -z "''${defined_symbols[$name]+x}" ]; then
              unresolved_symbols["$name"]=1
            fi
          done < "$file"
        }

        add_object_symbols() {
          local object="$1"
          local index="$2"
          local symbols="$tmp/object-$index.symbols"
          @PYTHON@ @ELF_TO_M1@ --symbols "$object" > "$symbols"
          process_symbol_file "$symbols"
        }

        prepare_archive_cache() {
          local archive="$1"
          local cache_dir="$2"
          local checksum="$3"
          local prefix_key member member_index symbols

          if [ ! -f "$cache_dir/.prepared" ]; then
            if mkdir "$cache_dir.lock" 2>/dev/null; then
              rm -rf "$cache_dir"
              mkdir -p "$cache_dir/extract" "$cache_dir/code" "$cache_dir/data" "$cache_dir/symbols"
              (cd "$cache_dir/extract" && @AR@ -x "$archive")
              : > "$cache_dir/members.list"
              member_index=0
              for member in "$cache_dir/extract"/*.o; do
                test -f "$member" || continue
                symbols="$cache_dir/symbols/member-$member_index.tsv"
                @PYTHON@ @ELF_TO_M1@ --symbols "$member" > "$symbols"
                printf '%s\t%s\n' "$member_index" "$(basename "$member")" >> "$cache_dir/members.list"
                member_index=$((member_index + 1))
              done
              touch "$cache_dir/.prepared"
              rmdir "$cache_dir.lock"
            else
              while [ ! -f "$cache_dir/.prepared" ]; do
                sleep 1
              done
            fi
          fi
        }

        archive_member_needed() {
          local symbols="$1"
          local kind name
          while IFS=$'\t' read -r kind name; do
            [ -n "''${name:-}" ] || continue
            if [ "$kind" = D ] && [ -n "''${unresolved_symbols[$name]+x}" ]; then
              return 0
            fi
          done < "$symbols"
          return 1
        }

        add_selected_archive_member() {
          local cache_dir="$1"
          local prefix_key="$2"
          local member_index="$3"
          local member_name="$4"
          local member="$cache_dir/extract/$member_name"
          local m1="$cache_dir/member-$member_index.M1"
          local selected_key="$cache_dir:$member_index"

          [ -z "''${selected_archive_members[$selected_key]+x}" ] || return 0
          selected_archive_members["$selected_key"]=1
          archive_selection_changed=1

          if [ ! -f "$cache_dir/code/member-$member_index.M1" ] || [ ! -f "$cache_dir/data/member-$member_index.M1" ]; then
            if mkdir "$cache_dir/member-$member_index.lock" 2>/dev/null; then
              @PYTHON@ @ELF_TO_M1@ --prefix "archive_''${prefix_key}_''${member_index}_" "$member" "$m1"
              awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data != 1 { print }' "$m1" > "$cache_dir/code/member-$member_index.M1"
              awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data == 1 { print }' "$m1" > "$cache_dir/data/member-$member_index.M1"
              rm -f "$m1"
              rmdir "$cache_dir/member-$member_index.lock"
            else
              while [ ! -f "$cache_dir/code/member-$member_index.M1" ] || [ ! -f "$cache_dir/data/member-$member_index.M1" ]; do
                sleep 1
              done
            fi
          fi

          code_files+=("$cache_dir/code/member-$member_index.M1")
          data_files+=("$cache_dir/data/member-$member_index.M1")
          process_symbol_file "$cache_dir/symbols/member-$member_index.tsv"
        }

        add_archive_m1_files() {
          local archive="$1"
          local archive_index="$2"
          local cache_root cache_key cache_dir checksum prefix_key member_index member_name symbols
          cache_root="''${TCC_DARWIN_CACHE_DIR:-$PWD/.tcc-darwin-archive-cache}"
          mkdir -p "$cache_root"
          checksum="$(cksum "$archive" | awk '{ print $1 "-" $2 }')"
          cache_key="$(basename "$archive" | sed 's/[^A-Za-z0-9_.-]/_/g')-$checksum-resolve-v3"
          cache_dir="$cache_root/$cache_key"
          prefix_key="$(printf '%s' "$checksum" | tr -c 'A-Za-z0-9_' '_')"

          prepare_archive_cache "$archive" "$cache_dir" "$checksum"
          while IFS=$'\t' read -r member_index member_name; do
            [ -n "''${member_index:-}" ] || continue
            symbols="$cache_dir/symbols/member-$member_index.tsv"
            if archive_member_needed "$symbols"; then
              add_selected_archive_member "$cache_dir" "$prefix_key" "$member_index" "$member_name"
            fi
          done < "$cache_dir/members.list"
        }

        add_archives() {
          local archive archive_index
          archive_selection_changed=1
          while [ "$archive_selection_changed" = 1 ]; do
            archive_selection_changed=0
            archive_index=0
            for archive in "''${archives[@]}"; do
              add_archive_m1_files "$archive" "$archive_index"
              archive_index=$((archive_index + 1))
            done
          done
        }

        add_dependency() {
          local dep="$1"
          local existing
          for existing in "''${deps[@]}"; do
            [ "$existing" = "$dep" ] && return 0
          done
          deps+=("$dep")
        }

        collect_dependency_headers() {
          local input line header resolved dir input_dir
          deps=()
          for input in "''${inputs[@]}"; do
            test -f "$input" || continue
            add_dependency "$input"
            input_dir="$(dirname "$input")"
            while IFS= read -r line; do
              case "$line" in
                *'#include "'*'"'*)
                  header="''${line#*#include \"}"
                  header="''${header%%\"*}"
                  resolved=
                  if [ -f "$input_dir/$header" ]; then
                    resolved="$input_dir/$header"
                  else
                    for dir in "''${include_dirs[@]}"; do
                      if [ -f "$dir/$header" ]; then
                        resolved="$dir/$header"
                        break
                      fi
                    done
                  fi
                  [ -n "$resolved" ] && add_dependency "$resolved"
                  ;;
              esac
            done < "$input"
          done
        }

        write_dependency_file() {
          ((emit_deps)) || return 0
          [ -n "$dep_file" ] || return 0
          local target="$dep_target"
          local dep
          if [ -z "$target" ]; then
            if [ -n "$out" ] && ((compile_only)); then
              target="$out"
            elif [ "''${#inputs[@]}" -eq 1 ]; then
              target="$(basename "''${inputs[0]}")"
              target="''${target%.c}.o"
            else
              target="a.out"
            fi
          fi
          mkdir -p "$(dirname "$dep_file")"
          collect_dependency_headers
          {
            printf '%s:' "$target"
            for dep in "''${deps[@]}"; do
              printf ' %s' "$dep"
            done
            printf '\n'
            if ((dep_dummy_headers)); then
              for dep in "''${deps[@]}"; do
                [ "$dep" = "''${inputs[0]:-}" ] && continue
                printf '%s:\n' "$dep"
              done
            fi
          } > "$dep_file"
        }

        cleanup() {
          for file in "''${cleanup_files[@]}"; do
            rm -f "$file"
          done
          for dir in "''${cleanup_dirs[@]}"; do
            rm -rf "$dir"
          done
        }
        trap cleanup EXIT

        if ((compile_only || preprocess_only)); then
          prepare_source_inputs
          if ((compile_only && !preprocess_only && explicit_output == 0 && ''${#inputs[@]} == 1)); then
            source_base="$(basename "''${inputs[0]}")"
            args+=("-o" "''${source_base%.c}.o")
          fi
          materialize_quote_headers
          @TCC@ "''${args[@]}" -I@INCLUDE@ "''${prepared_inputs[@]}" "''${objects[@]}"
          write_dependency_file
          exit "$?"
        fi

        if [ "''${#inputs[@]}" -eq 0 ] && [ "''${#objects[@]}" -eq 0 ] && [ "''${#archives[@]}" -eq 0 ]; then
          echo "tcc-darwin-cc: no input files" >&2
          exit 1
        fi

        tmp="$(mktemp -d)"
        trap 'cleanup; rm -rf "$tmp"' EXIT

        prepare_source_inputs
        materialize_quote_headers
        object_index=0
        for input in "''${prepared_inputs[@]}"; do
          object="$tmp/source-$object_index.o"
          @TCC@ -c "''${args[@]}" -I@INCLUDE@ "$input" -o "$object"
          objects+=("$object")
          object_index=$((object_index + 1))
        done
        resolve_libraries

        code_files=()
        data_files=()
        declare -A defined_symbols=()
        declare -A unresolved_symbols=()
        declare -A selected_archive_members=()
        object_index=0
        for object in "''${objects[@]}"; do
          add_object_symbols "$object" "$object_index"
          object_index=$((object_index + 1))
        done
        add_archives
        object_index=0
        for object in "''${objects[@]}"; do
          m1="$tmp/object-$object_index.M1"
          @PYTHON@ @ELF_TO_M1@ --prefix "obj_$object_index"_ "$object" "$m1"
          awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data != 1 { print }' "$m1" > "$tmp/object-$object_index.code.M1"
          awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data == 1 { print }' "$m1" > "$tmp/object-$object_index.data.M1"
          code_files+=("$tmp/object-$object_index.code.M1")
          data_files+=("$tmp/object-$object_index.data.M1")
          object_index=$((object_index + 1))
        done

        {
          cat @CRT1@
          cat @SYSCALLS@
          for file in "''${code_files[@]}"; do cat "$file"; done
          awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data != 1 { print }' @LIBC_M1@
          echo ':ELF_data'
          echo ':HEX2_data'
          for file in "''${data_files[@]}"; do cat "$file"; done
          awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data == 1 { print }' @LIBC_M1@
        } > "$tmp/combined.M1"

        @PYTHON@ @M1_TO_HEX2@ --architecture amd64 --little-endian --base-address 0x600400 --align-label ELF_data=0x1700000 -f "$tmp/combined.M1" -o "$tmp/combined.hex2"
        @HEX2@ --architecture amd64 --little-endian --base-address 0x600000 \
          -f @MACHO@ -f "$tmp/combined.hex2" -o "$out"
        @PYTHON@ @MACHO_LARGE_SEGMENTS@ "$out"
        linkeditOffset="$((0x1100000 + 0x2000000))"
        dd if=/dev/zero of="$out" bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc 2>/dev/null
        chmod +x "$out"
        source @SIGNING@
        sign "$out"
        SH

        substituteInPlace $out/bin/tcc-darwin-cc \
          --replace-fail @TCC@ ${phase38-tinycc-boot3-link-candidate}/bin/tcc-boot3-candidate \
          --replace-fail @AR@ ${cctools}/bin/ar \
          --replace-fail @INCLUDE@ $out/include/tcc-darwin-bootstrap \
          --replace-fail @PYTHON@ ${python3}/bin/python3 \
          --replace-fail @ELF_TO_M1@ ${root + "/tools/elf64-to-m1.py"} \
          --replace-fail @M1_TO_HEX2@ ${root + "/tools/m1-to-hex2.py"} \
          --replace-fail @MACHO_LARGE_SEGMENTS@ ${root + "/tools/patch-macho-large-segments.py"} \
          --replace-fail @HEX2@ ${phase10-hex2}/bin/hex2 \
          --replace-fail @MACHO@ ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          --replace-fail @CRT1@ $out/share/darwin-bootstrap/crt1-tcc-sysv.M1 \
          --replace-fail @SYSCALLS@ ${root + "/bootstrap/tinycc-sysv-syscalls-amd64-darwin.M1"} \
          --replace-fail @LIBC_M1@ $out/share/darwin-bootstrap/tinycc-sysv-libc.M1 \
          --replace-fail @SIGNING@ ${darwin.signingUtils}
        chmod +x $out/bin/tcc-darwin-cc

        cat > hello.c <<'C'
        int main(void) { return 42; }
        C
        $out/bin/tcc-darwin-cc hello.c -o hello
        set +e
        ./hello
        status="$?"
        set -e
        test "$status" = 42

        cat > data-reloc.c <<'C'
        static long x;
        static long *p = &x;
        int main(void) { return p == &x && x == 0 ? 0 : 3; }
        C
        $out/bin/tcc-darwin-cc data-reloc.c -o data-reloc
        ./data-reloc

        cat > function-reloc.c <<'C'
        int f(int x) { return x + 1; }
        int (*fp)(int) = f;
        struct entry { const char *name; int (*fn)(int); };
        struct entry table[] = { { "f", f }, { 0, 0 } };
        int main(void) { if (fp(41) != 42) return 1; if (table[0].fn(41) != 42) return 2; return 0; }
        C
        $out/bin/tcc-darwin-cc function-reloc.c -o function-reloc
        ./function-reloc

        cat > string-reloc.c <<'C'
        #include <stdio.h>
        int main(void) { fputs("FIRST", stdout); fputs("SECOND", stdout); return 0; }
        C
        $out/bin/tcc-darwin-cc string-reloc.c -o string-reloc
        test "$(./string-reloc)" = FIRSTSECOND

        $out/bin/tcc-darwin-cc -c hello.c -o hello.o
        test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

        cp tinycc-sysv-libc.o tinycc-sysv-libc.stdout tinycc-sysv-libc.stderr \
          hello.c hello data-reloc.c data-reloc function-reloc.c function-reloc \
          string-reloc.c string-reloc hello.o \
          $out/share/darwin-bootstrap/
      ''
    else
      null

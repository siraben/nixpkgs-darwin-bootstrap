#ifndef _DARWIN_BOOTSTRAP_UNISTD_H
#define _DARWIN_BOOTSTRAP_UNISTD_H
typedef long ssize_t;
typedef long long off_t;
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
int execve(const char *, char *const *, char *const *);
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
int truncate(const char *, off_t);
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
#ifndef _PC_PATH_MAX
#define _PC_PATH_MAX 5
#endif
long pathconf(const char *, int);
char *realpath(const char *, char *);
int getpagesize(void);
int vfork(void);
#ifdef __cplusplus
}
#endif
#endif

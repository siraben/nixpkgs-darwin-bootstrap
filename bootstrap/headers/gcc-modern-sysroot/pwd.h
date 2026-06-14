#ifndef _DARWIN_BOOTSTRAP_PWD_H
#define _DARWIN_BOOTSTRAP_PWD_H
struct passwd { char *pw_name; char *pw_passwd; unsigned int pw_uid; unsigned int pw_gid; char *pw_gecos; char *pw_dir; char *pw_shell; };
struct passwd *getpwnam(const char *);
struct passwd *getpwuid(unsigned int);
#endif

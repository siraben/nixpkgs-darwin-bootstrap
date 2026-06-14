#ifndef _DARWIN_BOOTSTRAP_GRP_H
#define _DARWIN_BOOTSTRAP_GRP_H
struct group { char *gr_name; unsigned int gr_gid; char **gr_mem; };
struct group *getgrnam(const char *);
struct group *getgrgid(unsigned int);
#endif

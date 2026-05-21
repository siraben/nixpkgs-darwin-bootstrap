#ifndef _DARWIN_BOOTSTRAP_GETOPT_H
#define _DARWIN_BOOTSTRAP_GETOPT_H
#define no_argument 0
#define required_argument 1
#define optional_argument 2
struct option { const char *name; int has_arg; int *flag; int val; };
extern char *optarg;
extern int optind;
extern int opterr;
extern int optopt;
int getopt(int, char * const *, const char *);
int getopt_long(int, char * const *, const char *, const struct option *, int *);
#endif

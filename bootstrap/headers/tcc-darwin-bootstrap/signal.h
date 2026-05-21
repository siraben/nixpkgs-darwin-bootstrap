#ifndef _DARWIN_BOOTSTRAP_SIGNAL_H
#define _DARWIN_BOOTSTRAP_SIGNAL_H
typedef int sig_atomic_t;
typedef unsigned int sigset_t;
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

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

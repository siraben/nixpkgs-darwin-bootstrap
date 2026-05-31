#ifndef _DARWIN_BOOTSTRAP_DIRENT_H
#define _DARWIN_BOOTSTRAP_DIRENT_H
#ifdef __cplusplus
extern "C" {
#endif
typedef struct DIR DIR;
#define DT_UNKNOWN 0
#define DT_FIFO 1
#define DT_CHR 2
#define DT_DIR 4
#define DT_BLK 6
#define DT_REG 8
#define DT_LNK 10
#define DT_SOCK 12
struct dirent { unsigned long d_ino; unsigned long d_seekoff; unsigned short d_reclen; unsigned short d_namlen; unsigned char d_type; char d_name[1024]; };
DIR *opendir(const char *);
struct dirent *readdir(DIR *);
int closedir(DIR *);
#ifdef __cplusplus
}
#endif
#endif

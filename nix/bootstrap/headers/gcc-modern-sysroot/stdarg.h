#ifndef _DARWIN_BOOTSTRAP_STDARG_H
#define _DARWIN_BOOTSTRAP_STDARG_H
#ifdef __TINYC__
/* tinycc's variadic ABI: __va_arg runtime helper + __builtin_va_arg_types. */
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
#else
/* gcc (cc1plus) builds in the gcc-10 chain: use the standard builtins — gcc has
 * no __builtin_va_arg_types / __va_arg helper. */
#ifndef _DARWIN_BOOTSTRAP_VA_LIST_TYPE
#define _DARWIN_BOOTSTRAP_VA_LIST_TYPE
typedef __builtin_va_list va_list;
#endif
#define va_start(ap, last) __builtin_va_start(ap, last)
#define va_arg(ap, type)   __builtin_va_arg(ap, type)
#define va_end(ap)         __builtin_va_end(ap)
#define va_copy(dst, src)  __builtin_va_copy(dst, src)
#endif
#endif

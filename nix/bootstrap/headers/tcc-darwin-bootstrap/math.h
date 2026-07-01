#ifndef _DARWIN_BOOTSTRAP_MATH_H
#define _DARWIN_BOOTSTRAP_MATH_H
#define FP_NAN 0
#define FP_INFINITE 1
#define FP_NORMAL 2
#define FP_SUBNORMAL 3
#define FP_ZERO 4
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

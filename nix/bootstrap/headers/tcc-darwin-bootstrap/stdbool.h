#ifndef _DARWIN_BOOTSTRAP_STDBOOL_H
#define _DARWIN_BOOTSTRAP_STDBOOL_H
/* In C++, bool/true/false are keywords — defining them as macros corrupts the
 * bool type (e.g. numeric_limits<bool> would become numeric_limits<int>). */
#ifndef __cplusplus
#define bool int
#define true 1
#define false 0
#endif
#endif

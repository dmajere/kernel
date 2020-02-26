#include <kernel/compiler.h>

// Generic kernel size type
#ifndef __kernel_size_t
typedef unsigned int	__kernel_size_t;
typedef int	            __kernel_ssize_t;
#endif

#ifndef _SIZE_T
#define _SIZE_T
typedef __kernel_size_t		size_t;
#endif

#ifndef _SSIZE_T
#define _SSIZE_T
typedef __kernel_ssize_t	ssize_t;
#endif

#define NULL (void*)0
#define INT_MAX		((int)(~0U >> 1))

#define __cmp(x, y, op)	((x) op (y) ? (x) : (y))
/**
 * min - return minimum of two values of the same or compatible types
 * @x: first value
 * @y: second value
 */
#define min(x, y)	__cmp(x, y, <)
/**
 * max - return maximum of two values of the same or compatible types
 * @x: first value
 * @y: second value
 */
#define max(x, y)	__cmp(x, y, >)
/**
 * clamp - return a value clamped to a given range with strict typechecking
 * @val: current value
 * @lo: lowest allowable value
 * @hi: highest allowable value
 *
 * This macro does strict typechecking of @lo/@hi to make sure they are of the
 * same type as @val.  See the unnecessary pointer comparisons.
 */
#define clamp(val, lo, hi) min((typeof(val))max(val, lo), hi)

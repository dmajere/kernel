#include <stdarg.h>
#include <kernel/types.h>
#include <kernel/vsprintf.h>
#include <kernel/screen.h>
#include <kernel/stdio.h>

int kprintf(const char *format, ...)
{
    va_list args;
    char *buf;

    va_start(args, format);
    vsnprintf(buf, INT_MAX, format, args);
    va_end(args);

    return printk(buf);
}

int printk(const char *str)
{
    char *start = (char*) str;
    for (;*str; str++) {
        print_char(*str, -1, -1, WHITE_ON_BLACK);
    }
    return str-start;
}

int kprintat(const int row, const int col, const char *format, ...)
{

    va_list args;
    char *buf;

    if (row >= 0 && col >= 0)
        setcursor(get_offset(row, col));

    va_start(args, format);
    vsnprintf(buf, INT_MAX, format, args);
    va_end(args);

    return printk(buf);
}
